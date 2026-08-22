import { http } from '@kit.NetworkKit';
import { WeatherData, HourlyItem, DailyItem } from '../model/WeatherData';

// NMC API 基础 URL
const NMC_BASE: string = 'https://www.nmc.cn/rest';

// NMC 省份
interface NmcProvince {
  code: string;
  name: string;
}

// NMC 城市
interface NmcCity {
  stationId: string;
  cityName: string;
  lat: number;
  lon: number;
}

// NMC 天气响应
interface NmcWeatherResponse {
  predict: NmcPredict;
  publish: NmcPublish;
  alert: NmcAlert[];
}
interface NmcPredict {
  predictDetail: NmcPredictDetail[];
}
interface NmcPredictDetail {
  predictDate: string;
  weather: NmcWeatherInfo;
}
interface NmcWeatherInfo {
  info: string;
  temperature: string;
  maxTemperature: string;
  minTemperature: string;
  direct: string;
  power: string;
  night: NmcWeatherInfo;
}
interface NmcPublish {
  publishTime: string;
  obs: NmcObs;
  tips: string;
}
interface NmcObs {
  temperature: string;
  humidity: string;
  windDirect: string;
  windSpeed: string;
  weather: string;
  pressure: string;
  feelst: string;
}
interface NmcAlert {
  alert: string;
  title: string;
  description: string;
}

/**
 * NMC (中央气象台) 数据源
 * 注意: NMC 使用站点 ID 而非经纬度，需先查找最近站点
 */
export class NmcApi {
  // 获取省份列表
  static async getProvinces(): Promise<NmcProvince[]> {
    try {
      const req: http.HttpRequest = http.createHttp();
      const resp: http.HttpResponse = await req.request(`${NMC_BASE}/province`, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://www.nmc.cn/' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      let provinces: NmcProvince[] = [];
      if (resp.responseCode === 200) {
        const body: string = resp.result as string;
        provinces = JSON.parse(body) as NmcProvince[];
      }
      req.destroy();
      return provinces;
    } catch (e) {
      return [];
    }
  }

  // 获取省份下城市列表
  static async getCities(provinceCode: string): Promise<NmcCity[]> {
    try {
      const req: http.HttpRequest = http.createHttp();
      const resp: http.HttpResponse = await req.request(`${NMC_BASE}/city/${provinceCode}`, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://www.nmc.cn/' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      let cities: NmcCity[] = [];
      if (resp.responseCode === 200) {
        const body: string = resp.result as string;
        cities = JSON.parse(body) as NmcCity[];
      }
      req.destroy();
      return cities;
    } catch (e) {
      return [];
    }
  }

  // 根据经纬度查找最近的 NMC 站点
  static async findNearestStation(lat: number, lon: number): Promise<NmcCity | null> {
    // 预置主要城市站点映射（避免遍历所有省份）
    const stationMap: NmcCity[] = [
      { stationId: '54511', cityName: '北京', lat: 39.9042, lon: 116.4074 },
      { stationId: '58367', cityName: '上海', lat: 31.2304, lon: 121.4737 },
      { stationId: '59287', cityName: '广州', lat: 23.1291, lon: 113.2644 },
      { stationId: '59493', cityName: '深圳', lat: 22.5431, lon: 114.0579 },
      { stationId: '58457', cityName: '杭州', lat: 30.2741, lon: 120.1551 },
      { stationId: '58238', cityName: '南京', lat: 32.0603, lon: 118.7969 },
      { stationId: '57494', cityName: '武汉', lat: 30.5928, lon: 114.3055 },
      { stationId: '56294', cityName: '成都', lat: 30.5728, lon: 104.0668 },
      { stationId: '57516', cityName: '重庆', lat: 29.5630, lon: 106.5516 },
      { stationId: '57036', cityName: '西安', lat: 34.3416, lon: 108.9398 },
      { stationId: '54527', cityName: '天津', lat: 39.3434, lon: 117.3616 },
      { stationId: '58349', cityName: '苏州', lat: 31.2989, lon: 120.5853 },
      { stationId: '57679', cityName: '长沙', lat: 28.2282, lon: 112.9388 },
      { stationId: '54857', cityName: '青岛', lat: 36.0671, lon: 120.3826 },
      { stationId: '54497', cityName: '沈阳', lat: 41.8057, lon: 123.4315 },
      { stationId: '50953', cityName: '哈尔滨', lat: 45.8038, lon: 126.5350 },
      { stationId: '56778', cityName: '昆明', lat: 25.0389, lon: 102.7183 },
      { stationId: '59134', cityName: '厦门', lat: 24.4798, lon: 118.0894 },
      { stationId: '53614', cityName: '太原', lat: 37.8706, lon: 112.5489 },
      { stationId: '53853', cityName: '石家庄', lat: 38.0428, lon: 114.5149 },
      { stationId: '57083', cityName: '郑州', lat: 34.7466, lon: 113.6253 },
      { stationId: '57457', cityName: '南昌', lat: 28.6820, lon: 115.8578 },
      { stationId: '54830', cityName: '济南', lat: 36.6512, lon: 117.1201 },
      { stationId: '58501', cityName: '合肥', lat: 31.8206, lon: 117.2272 },
      { stationId: '57091', cityName: '兰州', lat: 36.0611, lon: 103.8343 },
      { stationId: '52889', cityName: '西宁', lat: 36.6171, lon: 101.7782 },
      { stationId: '57178', cityName: '银川', lat: 38.4872, lon: 106.2309 },
      { stationId: '51463', cityName: '乌鲁木齐', lat: 43.8256, lon: 87.3370 },
      { stationId: '59948', cityName: '三亚', lat: 18.2528, lon: 109.5120 },
      { stationId: '54094', cityName: '大连', lat: 38.9140, lon: 121.6147 },
      { stationId: '60583', cityName: '香港', lat: 22.3193, lon: 114.1694 },
    ];

    let nearest: NmcCity | null = null;
    let minDist: number = Number.MAX_VALUE;
    for (let i: number = 0; i < stationMap.length; i++) {
      const city: NmcCity = stationMap[i];
      const dist: number = (city.lat - lat) * (city.lat - lat) + (city.lon - lon) * (city.lon - lon);
      if (dist < minDist) {
        minDist = dist;
        nearest = city;
      }
    }
    return nearest;
  }

  // 获取天气数据
  static async fetchWeather(lat: number, lon: number, cityName: string): Promise<WeatherData> {
    // 1. 查找最近站点
    const station: NmcCity | null = await NmcApi.findNearestStation(lat, lon);
    if (station === null) {
      throw new Error('未找到附近的气象站点');
    }

    // 2. 获取天气数据
    const req: http.HttpRequest = http.createHttp();
    const resp: http.HttpResponse = await req.request(`${NMC_BASE}/weather?stationid=${station.stationId}`, {
      method: http.RequestMethod.GET,
      header: { 'Referer': 'https://www.nmc.cn/' },
      connectTimeout: 10000,
      readTimeout: 10000,
    });

    if (resp.responseCode !== 200) {
      req.destroy();
      throw new Error('NMC 接口返回错误: ' + resp.responseCode);
    }

    const body: string = resp.result as string;
    const data: NmcWeatherResponse = JSON.parse(body) as NmcWeatherResponse;
    req.destroy();

    // 3. 解析数据
    return NmcApi.parseWeather(data, station.cityName);
  }

  // 解析 NMC 数据为统一 WeatherData
  static parseWeather(data: NmcWeatherResponse, cityName: string): WeatherData {
    const obs: NmcObs = data.publish?.obs;
    const predictDetails: NmcPredictDetail[] = data.predict?.predictDetail || [];

    // 当前天气
    const temperature: number | null = obs?.temperature ? parseFloat(obs.temperature) : null;
    const humidity: number | null = obs?.humidity ? parseFloat(obs.humidity) : null;
    const feelsLike: number | null = obs?.feelst ? parseFloat(obs.feelst) : null;
    const condition: string = obs?.weather || '未知';
    const windDirect: string = obs?.windDirect || '--';
    const windPower: string = obs?.windSpeed || '--';

    // 预警
    let warning: string | null = null;
    if (data.alert && data.alert.length > 0) {
      warning = data.alert[0].title + ': ' + data.alert[0].description;
    }

    // 逐日预报
    const daily: DailyItem[] = [];
    let todayHigh: number | null = null;
    let todayLow: number | null = null;
    for (let i: number = 0; i < predictDetails.length && i < 7; i++) {
      const detail: NmcPredictDetail = predictDetails[i];
      const w: NmcWeatherInfo = detail.weather;
      const high: number | null = w?.maxTemperature ? parseFloat(w.maxTemperature) : null;
      const low: number | null = w?.minTemperature ? parseFloat(w.minTemperature) : null;
      const dayText: string = w?.info || '';
      const nightText: string = w?.night?.info || dayText;

      daily.push({
        date: detail.predictDate,
        dayText: dayText,
        nightText: nightText,
        high: high,
        low: low
      });

      if (i === 0) {
        todayHigh = high;
        todayLow = low;
      }
    }

    // 逐时预报（NMC 不提供逐时，用逐日简化）
    const hourly: HourlyItem[] = [];

    return {
      cityName: cityName,
      updatedAt: data.publish?.publishTime || new Date().toISOString(),
      temperature: temperature,
      condition: condition,
      feelsLike: feelsLike,
      humidity: humidity,
      windDirect: windDirect,
      windPower: windPower,
      todayHigh: todayHigh,
      todayLow: todayLow,
      aqi: null,
      aqiText: '',
      warning: warning,
      sunrise: null,
      sunset: null,
      minutelyText: null,
      uvIndex: '',
      sourceTag: 'NMC 中央气象台',
      hourlyLabel: 'hourly forecast',
      hourly: hourly,
      daily: daily,
      yesterday: null,
      savedAt: Date.now()
    };
  }
}
