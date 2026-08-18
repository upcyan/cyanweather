import { http } from '@kit.NetworkKit';
import { WeatherData, HourlyItem, DailyItem } from '../model/WeatherData';

// 彩云天气 API
// 注意: 需要替换为有效的 API Token
const CAIYUN_TOKEN: string = 'YOUR_CAIYUN_TOKEN';
const CAIYUN_BASE: string = `https://api.caiyunapp.com/v2.6/${CAIYUN_TOKEN}`;

// 彩云天气响应
interface CaiyunResponse {
  status: string;
  result: CaiyunResult;
}
interface CaiyunResult {
  alert: CaiyunAlert;
  realtime: CaiyunRealtime;
  minutely: CaiyunMinutely;
  hourly: CaiyunHourly;
  daily: CaiyunDaily;
}
interface CaiyunAlert {
  content: CaiyunAlertContent[];
}
interface CaiyunAlertContent {
  title: string;
  description: string;
}
interface CaiyunRealtime {
  temperature: number;
  humidity: number;
  apparent_temperature: number;
  skycon: string;
  wind: CaiyunWind;
  life_index: CaiyunLifeIndex;
  air_quality: CaiyunAirQuality;
}
interface CaiyunWind {
  speed: number;
  direction: number;
}
interface CaiyunLifeIndex {
  ultraviolet: CaiyunIndexDesc;
}
interface CaiyunIndexDesc {
  desc: string;
  index: number;
}
interface CaiyunAirQuality {
  pm25: number;
  pm10: number;
  aqi: number;
  description: CaiyunAqiDesc;
}
interface CaiyunAqiDesc {
  chn: string;
  usa: string;
}
interface CaiyunMinutely {
  description: string;
  probability: number[];
  precipitation: number[];
}
interface CaiyunHourly {
  temperature: CaiyunHourlyValue[];
  skycon: CaiyunHourlySkycon[];
  precipitation: CaiyunHourlyPrecip[];
  wind: CaiyunHourlyWind[];
}
interface CaiyunHourlyValue {
  datetime: string;
  value: number;
}
interface CaiyunHourlySkycon {
  datetime: string;
  value: string;
}
interface CaiyunHourlyPrecip {
  datetime: string;
  value: number;
  probability: number;
}
interface CaiyunHourlyWind {
  datetime: string;
  speed: number;
  direction: number;
}
interface CaiyunDaily {
  temperature: CaiyunDailyTemp[];
  skycon: CaiyunDailySkycon[];
  astro: CaiyunDailyAstro[];
  life_index: CaiyunDailyLifeIndex;
}
interface CaiyunDailyTemp {
  date: string;
  max: number;
  min: number;
  avg: number;
}
interface CaiyunDailySkycon {
  date: string;
  value: string;
}
interface CaiyunDailyAstro {
  date: string;
  sunrise: CaiyunTime;
  sunset: CaiyunTime;
}
interface CaiyunTime {
  time: string;
}
interface CaiyunDailyLifeIndex {
  ultraviolet: CaiyunDailyIndex[];
}
interface CaiyunDailyIndex {
  date: string;
  index: number;
  desc: string;
}

// 彩云天气代码映射
function skyconToText(skycon: string): string {
  const map: Record<string, string> = {
    'CLEAR_DAY': '晴',
    'CLEAR_NIGHT': '晴',
    'PARTLY_CLOUDY_DAY': '多云',
    'PARTLY_CLOUDY_NIGHT': '多云',
    'CLOUDY': '阴',
    'LIGHT_HAZE': '轻度雾霾',
    'MODERATE_HAZE': '中度雾霾',
    'HEAVY_HAZE': '重度雾霾',
    'LIGHT_RAIN': '小雨',
    'MODERATE_RAIN': '中雨',
    'HEAVY_RAIN': '大雨',
    'STORM_RAIN': '暴雨',
    'FOG': '雾',
    'LIGHT_SNOW': '小雪',
    'MODERATE_SNOW': '中雪',
    'HEAVY_SNOW': '大雪',
    'STORM_SNOW': '暴雪',
    'DUST': '浮尘',
    'SAND': '沙尘',
    'WIND': '大风'
  };
  return map[skycon] || '未知';
}

// 风向角度转中文
function windDirToText(deg: number): string {
  const dirs: string[] = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
  const idx: number = Math.round(deg / 45) % 8;
  return dirs[idx] + '风';
}

// 风速转风级
function windSpeedToPower(speed: number): string {
  if (speed < 1) return '0级';
  if (speed < 6) return '1-2级';
  if (speed < 12) return '3-4级';
  if (speed < 20) return '5-6级';
  if (speed < 29) return '7-8级';
  return '9级以上';
}

/**
 * 彩云天气数据源
 * 提供分钟级降水、逐时和逐日预报
 */
export class CaiyunApi {
  static async fetchWeather(lat: number, lon: number, cityName: string): Promise<WeatherData> {
    const url: string = `${CAIYUN_BASE}/${lat.toFixed(4)},${lon.toFixed(4)}/weather.json?alert=true&minutely=50&hourly=24&daily=7`;
    const req: http.HttpRequest = http.createHttp();
    const resp: http.HttpResponse = await req.request(url, {
      method: http.RequestMethod.GET,
      header: { 'Content-Type': 'application/json' },
      connectTimeout: 10000,
      readTimeout: 10000,
    });

    if (resp.responseCode !== 200) {
      req.destroy();
      throw new Error('彩云天气接口返回错误: ' + resp.responseCode);
    }

    const body: string = resp.result as string;
    const data: CaiyunResponse = JSON.parse(body) as CaiyunResponse;
    req.destroy();

    if (data.status !== 'ok') {
      throw new Error('彩云天气接口状态异常: ' + data.status);
    }

    return CaiyunApi.parseWeather(data, cityName);
  }

  static parseWeather(data: CaiyunResponse, cityName: string): WeatherData {
    const r: CaiyunResult = data.result;
    const rt: CaiyunRealtime = r.realtime;

    // 当前天气
    const temperature: number = rt.temperature;
    const humidity: number = rt.humidity * 100;
    const feelsLike: number = rt.apparent_temperature;
    const condition: string = skyconToText(rt.skycon);
    const windDirect: string = windDirToText(rt.wind.direction);
    const windPower: string = windSpeedToPower(rt.wind.speed);

    // AQI
    const aqi: number | null = rt.air_quality?.aqi ?? null;
    const aqiText: string = rt.air_quality?.description?.chn ?? '';

    // UV 指数
    const uvIndex: string = rt.life_index?.ultraviolet?.desc ?? '';

    // 预警
    let warning: string | null = null;
    if (r.alert?.content && r.alert.content.length > 0) {
      warning = r.alert.content[0].title + ': ' + r.alert.content[0].description;
    }

    // 分钟级降水
    const minutelyText: string | null = r.minutely?.description ?? null;

    // 逐时预报
    const hourly: HourlyItem[] = [];
    if (r.hourly?.temperature && r.hourly?.skycon) {
      const temps: CaiyunHourlyValue[] = r.hourly.temperature;
      const skycons: CaiyunHourlySkycon[] = r.hourly.skycon;
      const precip: CaiyunHourlyPrecip[] = r.hourly.precipitation || [];
      const count: number = Math.min(temps.length, skycons.length, 24);
      for (let i: number = 0; i < count; i++) {
        const rainProb: number | null = i < precip.length ? precip[i].probability * 100 : null;
        hourly.push({
          time: temps[i].datetime,
          temperature: temps[i].value,
          condition: skyconToText(skycons[i].value),
          isForecast: true,
          rainProb: rainProb
        });
      }
    }

    // 逐日预报
    const daily: DailyItem[] = [];
    let todayHigh: number | null = null;
    let todayLow: number | null = null;
    let sunrise: string | null = null;
    let sunset: string | null = null;
    if (r.daily?.temperature && r.daily?.skycon) {
      const temps: CaiyunDailyTemp[] = r.daily.temperature;
      const skycons: CaiyunDailySkycon[] = r.daily.skycon;
      const astros: CaiyunDailyAstro[] = r.daily.astro || [];
      const count: number = Math.min(temps.length, skycons.length, 7);
      for (let i: number = 0; i < count; i++) {
        daily.push({
          date: temps[i].date,
          dayText: skyconToText(skycons[i].value),
          nightText: skyconToText(skycons[i].value),
          high: temps[i].max,
          low: temps[i].min
        });
        if (i === 0) {
          todayHigh = temps[i].max;
          todayLow = temps[i].min;
          if (astros.length > 0) {
            sunrise = astros[0].sunrise?.time ?? null;
            sunset = astros[0].sunset?.time ?? null;
          }
        }
      }
    }

    return {
      cityName: cityName,
      updatedAt: new Date().toISOString(),
      temperature: temperature,
      condition: condition,
      feelsLike: feelsLike,
      humidity: humidity,
      windDirect: windDirect,
      windPower: windPower,
      todayHigh: todayHigh,
      todayLow: todayLow,
      aqi: aqi,
      aqiText: aqiText,
      warning: warning,
      sunrise: sunrise,
      sunset: sunset,
      minutelyText: minutelyText,
      uvIndex: uvIndex,
      sourceTag: '彩云天气',
      hourly: hourly,
      daily: daily
    };
  }
}
