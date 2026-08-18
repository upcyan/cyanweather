import { WeatherData } from '../model/WeatherData';
import { fetchWeather } from './WeatherApi';
import { NmcApi } from './NmcApi';
import { CaiyunApi } from './CaiyunApi';
import { SettingsStore, DataSource } from './SettingsStore';

/**
 * 统一天气数据管理器
 * 根据用户设置选择数据源，失败时自动回退到 Open-Meteo
 */
export class WeatherManager {

  // 根据设置获取天气数据
  static async getWeather(lat: number, lon: number, cityName: string): Promise<WeatherData> {
    const source: DataSource = SettingsStore.getDataSource();

    try {
      switch (source) {
        case 'nmc':
          return await NmcApi.fetchWeather(lat, lon, cityName);
        case 'caiyun':
          return await CaiyunApi.fetchWeather(lat, lon, cityName);
        case 'openmeteo':
        default:
          return await fetchWeather(lat, lon, cityName);
      }
    } catch (e) {
      // 如果选定的数据源失败，回退到 Open-Meteo
      if (source !== 'openmeteo') {
        const errMsg: string = (e as Error).message || String(e);
        console.warn('数据源 ' + source + ' 失败，回退到 Open-Meteo: ' + errMsg);
        return await fetchWeather(lat, lon, cityName);
      }
      throw new Error((e as Error).message || '获取天气数据失败');
    }
  }
}
