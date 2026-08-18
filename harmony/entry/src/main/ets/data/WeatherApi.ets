import { http } from '@kit.NetworkKit';
import { WeatherData, HourlyItem, DailyItem } from '../model/WeatherData';

const OPEN_METEO_BASE: string = 'https://api.open-meteo.com/v1';
const OPEN_METEO_AIR: string = 'https://air-quality-api.open-meteo.com/v1';

interface OpenMeteoCurrent {
  time: string;
  temperature_2m: number;
  relative_humidity_2m: number;
  apparent_temperature: number;
  weather_code: number;
  wind_speed_10m: number;
  wind_direction_10m: number;
}

interface OpenMeteoDaily {
  time: string[];
  weather_code: number[];
  temperature_2m_max: number[];
  temperature_2m_min: number[];
  sunrise: string[];
  sunset: string[];
}

interface OpenMeteoHourly {
  time: string[];
  temperature_2m: number[];
  weather_code: number[];
  precipitation_probability: number[];
}

interface OpenMeteoWeatherResp {
  current: OpenMeteoCurrent;
  daily: OpenMeteoDaily;
  hourly: OpenMeteoHourly;
}

interface OpenMeteoAirCurrent {
  us_aqi: number;
}

interface OpenMeteoAirResp {
  current: OpenMeteoAirCurrent;
}

interface ReverseGeoItem {
  city: string;
  province: string;
}

interface ReverseGeoResp {
  results: ReverseGeoItem[];
}

async function fetchJson(url: string): Promise<string> {
  const httpRequest = http.createHttp();
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: 15000,
      readTimeout: 15000
    });
    if (response.responseCode === 200) {
      return response.result as string;
    }
    throw new Error('HTTP ' + response.responseCode);
  } finally {
    httpRequest.destroy();
  }
}

function wmoToText(code: number): string {
  if (code === 0 || code === 1) return '晴';
  if (code === 2) return '多云';
  if (code === 3) return '阴';
  if (code === 45 || code === 48) return '雾';
  if (code >= 51 && code <= 55) return '小雨';
  if (code === 56 || code === 57) return '雨夹雪';
  if (code === 61) return '小雨';
  if (code === 63) return '中雨';
  if (code === 65) return '大雨';
  if (code === 66 || code === 67) return '雨夹雪';
  if (code === 71) return '小雪';
  if (code === 73) return '中雪';
  if (code === 75) return '大雪';
  if (code === 80) return '小雨';
  if (code === 81) return '中雨';
  if (code === 82) return '大雨';
  if (code === 95) return '雷阵雨';
  if (code === 96 || code === 99) return '雷阵雨';
  return '-';
}

function windDirection(degree: number): string {
  const dirs: string[] = ['北风', '东北风', '东风', '东南风', '南风', '西南风', '西风', '西北风'];
  const idx: number = Math.floor(((degree + 22.5) / 45.0)) % 8;
  return dirs[idx];
}

function beaufort(speedMps: number): string {
  let bft: number = 0;
  if (speedMps >= 0.3) bft = 1;
  if (speedMps >= 1.6) bft = 2;
  if (speedMps >= 3.4) bft = 3;
  if (speedMps >= 5.5) bft = 4;
  if (speedMps >= 8.0) bft = 5;
  if (speedMps >= 10.8) bft = 6;
  if (speedMps >= 13.9) bft = 7;
  if (speedMps >= 17.2) bft = 8;
  if (speedMps >= 20.8) bft = 9;
  return bft + '级';
}

function aqiText(aqi: number): string {
  if (aqi <= 50) return '优';
  if (aqi <= 100) return '良';
  if (aqi <= 150) return '轻度污染';
  if (aqi <= 200) return '中度污染';
  if (aqi <= 300) return '重度污染';
  return '严重污染';
}

function safeNum(val: number | undefined | null): number | null {
  if (val === undefined || val === null || isNaN(val)) return null;
  return val;
}

export async function fetchWeather(lat: number, lon: number, cityName: string): Promise<WeatherData> {
  const weatherUrl: string = OPEN_METEO_BASE + '/forecast?latitude=' + lat + '&longitude=' + lon +
    '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m' +
    '&hourly=temperature_2m,weather_code,precipitation_probability' +
    '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset' +
    '&timezone=auto&forecast_days=15';

  const airUrl: string = OPEN_METEO_AIR + '/air-quality?latitude=' + lat + '&longitude=' + lon + '&current=us_aqi';

  const weatherText: string = await fetchJson(weatherUrl);
  const airText: string = await fetchJson(airUrl);

  const w: OpenMeteoWeatherResp = JSON.parse(weatherText) as OpenMeteoWeatherResp;
  const airResp: OpenMeteoAirResp = JSON.parse(airText) as OpenMeteoAirResp;

  const current: OpenMeteoCurrent = w.current;
  const daily: OpenMeteoDaily = w.daily;
  const hourly: OpenMeteoHourly = w.hourly;

  const now: Date = new Date();
  const year: number = now.getFullYear();
  const month: number = now.getMonth() + 1;
  const day: number = now.getDate();
  const today: string = year + '-' + (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day);

  let todayIdx: number = -1;
  for (let i = 0; i < daily.time.length; i++) {
    if (daily.time[i] === today) {
      todayIdx = i;
      break;
    }
  }

  const dailyList: DailyItem[] = [];
  if (todayIdx >= 0) {
    for (let i = todayIdx; i < daily.time.length; i++) {
      const high: number | null = safeNum(daily.temperature_2m_max[i]);
      const low: number | null = safeNum(daily.temperature_2m_min[i]);
      if (high !== null || low !== null) {
        const item: DailyItem = {
          date: daily.time[i],
          dayText: wmoToText(daily.weather_code[i]),
          nightText: '',
          high: high,
          low: low
        };
        dailyList.push(item);
      }
    }
  }

  const hourlyList: HourlyItem[] = [];
  for (let i = 0; i < hourly.time.length && hourlyList.length < 48; i++) {
    if (hourly.time[i] >= current.time) {
      const item: HourlyItem = {
        time: hourly.time[i],
        temperature: safeNum(hourly.temperature_2m[i]),
        condition: wmoToText(hourly.weather_code[i]),
        isForecast: true,
        rainProb: safeNum(hourly.precipitation_probability[i])
      };
      hourlyList.push(item);
    }
  }

  const aqi: number | null = (airResp.current !== undefined && airResp.current !== null)
    ? safeNum(airResp.current.us_aqi) : null;

  let sunriseVal: string | null = null;
  let sunsetVal: string | null = null;
  if (todayIdx >= 0 && todayIdx < daily.sunrise.length) {
    const sr: string = daily.sunrise[todayIdx];
    if (sr.length >= 16) sunriseVal = sr.substring(11, 16);
  }
  if (todayIdx >= 0 && todayIdx < daily.sunset.length) {
    const ss: string = daily.sunset[todayIdx];
    if (ss.length >= 16) sunsetVal = ss.substring(11, 16);
  }

  let highToday: number | null = null;
  let lowToday: number | null = null;
  if (todayIdx >= 0) {
    highToday = safeNum(daily.temperature_2m_max[todayIdx]);
    lowToday = safeNum(daily.temperature_2m_min[todayIdx]);
  }

  const result: WeatherData = {
    cityName: cityName.length > 0 ? cityName : '当前位置',
    updatedAt: current.time.substring(0, 16).replace('T', ' '),
    temperature: safeNum(current.temperature_2m),
    condition: wmoToText(current.weather_code),
    feelsLike: safeNum(current.apparent_temperature),
    humidity: current.relative_humidity_2m,
    windDirect: current.wind_direction_10m !== null ? windDirection(current.wind_direction_10m) : '',
    windPower: current.wind_speed_10m !== null ? beaufort(current.wind_speed_10m / 3.6) : '',
    todayHigh: highToday,
    todayLow: lowToday,
    aqi: aqi,
    aqiText: aqi !== null ? aqiText(aqi) : '',
    warning: null,
    sunrise: sunriseVal,
    sunset: sunsetVal,
    minutelyText: null,
    uvIndex: '',
    sourceTag: '数据来源：Open-Meteo',
    hourly: hourlyList,
    daily: dailyList
  };
  return result;
}
