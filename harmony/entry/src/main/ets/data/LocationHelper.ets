import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 定位结果
export interface LocationResult {
  lat: number;
  lon: number;
  cityName: string;
}

// 坐标
interface LocationCoords {
  lat: number;
  lon: number;
}

// 逆地理编码响应（Open-Meteo）
interface ReverseGeoResponse {
  results: ReverseGeoResult[];
}
interface ReverseGeoResult {
  name: string;
  latitude: number;
  longitude: number;
  country: string;
  admin1: string;
}

export class LocationHelper {
  // 请求定位权限
  static async requestPermissions(context: common.UIAbilityContext): Promise<boolean> {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    try {
      const result =
        await atManager.requestPermissionsFromUser(context,
          ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']);
      // 检查是否所有权限都授予
      for (let i: number = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== 0) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // 获取当前位置
  static async getCurrentLocation(): Promise<LocationCoords | null> {
    try {
      const request: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_ACCURACY,
        locatingTimeoutMs: 10000
      };
      const location: geoLocationManager.Location =
        await geoLocationManager.getCurrentLocation(request);
      const coords: LocationCoords = { lat: location.latitude, lon: location.longitude };
      return coords;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error('getCurrentLocation failed: ' + err.code + ' ' + err.message);
      return null;
    }
  }

  // 逆地理编码：根据经纬度获取城市名称
  static async reverseGeocode(lat: number, lon: number): Promise<string> {
    try {
      const url: string =
        `https://geocoding-api.open-meteo.com/v1/search?latitude=${lat}&longitude=${lon}&count=1&language=zh&format=json`;
      const req: http.HttpRequest = http.createHttp();
      const resp: http.HttpResponse = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      let cityName: string = '当前位置';
      if (resp.responseCode === 200) {
        const body: string = resp.result as string;
        const data: ReverseGeoResponse = JSON.parse(body) as ReverseGeoResponse;
        if (data.results && data.results.length > 0) {
          cityName = data.results[0].name;
        }
      }
      req.destroy();
      return cityName;
    } catch (e) {
      return '当前位置';
    }
  }

  // 一键定位：获取位置 + 城市名
  static async locate(context: common.UIAbilityContext): Promise<LocationResult | null> {
    // 1. 请求权限
    const granted: boolean = await LocationHelper.requestPermissions(context);
    if (!granted) {
      return null;
    }
    // 2. 获取位置
    const pos: LocationCoords | null = await LocationHelper.getCurrentLocation();
    if (pos === null) {
      return null;
    }
    // 3. 逆地理编码
    const cityName: string = await LocationHelper.reverseGeocode(pos.lat, pos.lon);
    const result: LocationResult = { lat: pos.lat, lon: pos.lon, cityName: cityName };
    return result;
  }
}
