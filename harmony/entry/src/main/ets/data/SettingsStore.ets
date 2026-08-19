import { preferences } from '@kit.ArkData';

/**
 * 应用设置持久化存储
 * 使用 Preferences API 实现轻量级 Key-Value 存储
 */
const PREF_NAME: string = 'cyanweather_settings';

// 数据源类型
export type DataSource = 'openmeteo' | 'nmc' | 'caiyun';

// 设置项 Key 常量
const KEY_DATA_SOURCE: string = 'data_source';
const KEY_TEMP_UNIT: string = 'temp_unit';       // 'c' | 'f'
const KEY_FONT_SCALE: string = 'font_scale';       // 0.8 ~ 1.4
const KEY_THEME_MODE: string = 'theme_mode';       // 'light' | 'dark' | 'auto'
const KEY_CITY_NAME: string = 'city_name';
const KEY_CITY_LAT: string = 'city_lat';
const KEY_CITY_LON: string = 'city_lon';
const KEY_USE_GPS: string = 'use_gps';             // boolean
const KEY_REFRESH_INTERVAL: string = 'refresh_interval'; // 'off' | 'on_resume' | '10' | '30' | '60' | '360' | '720' | '1440'
const KEY_AUTO_UPDATE: string = 'auto_update';       // boolean

export class SettingsStore {
  private static pref: preferences.Preferences | null = null;
  private static context: Context | null = null;

  // 初始化（在 EntryAbility 中调用）
  static init(context: Context): void {
    try {
      SettingsStore.context = context;
      const options: preferences.Options = { name: PREF_NAME };
      SettingsStore.pref = preferences.getPreferencesSync(context, options);
    } catch (e) {
      console.error('SettingsStore init failed: ' + (e as Error).message);
    }
  }

  private static ensurePref(): preferences.Preferences {
    if (SettingsStore.pref === null && SettingsStore.context !== null) {
      const options: preferences.Options = { name: PREF_NAME };
      SettingsStore.pref = preferences.getPreferencesSync(SettingsStore.context, options);
    }
    return SettingsStore.pref as preferences.Preferences;
  }

  // ===== 数据源 =====
  static getDataSource(): DataSource {
    try {
      const val: string = SettingsStore.ensurePref().getSync(KEY_DATA_SOURCE, 'openmeteo') as string;
      return val as DataSource;
    } catch (_) {
      return 'openmeteo';
    }
  }

  static setDataSource(source: DataSource): void {
    SettingsStore.ensurePref().putSync(KEY_DATA_SOURCE, source);
    SettingsStore.ensurePref().flush();
  }

  // ===== 温度单位 =====
  static getTempUnit(): string {
    try {
      return SettingsStore.ensurePref().getSync(KEY_TEMP_UNIT, 'c') as string;
    } catch (_) {
      return 'c';
    }
  }

  static setTempUnit(unit: string): void {
    SettingsStore.ensurePref().putSync(KEY_TEMP_UNIT, unit);
    SettingsStore.ensurePref().flush();
  }

  // ===== 字体缩放 =====
  static getFontScale(): number {
    try {
      return SettingsStore.ensurePref().getSync(KEY_FONT_SCALE, 1.0) as number;
    } catch (_) {
      return 1.0;
    }
  }

  static setFontScale(scale: number): void {
    SettingsStore.ensurePref().putSync(KEY_FONT_SCALE, scale);
    SettingsStore.ensurePref().flush();
  }

  // ===== 主题模式 =====
  static getThemeMode(): string {
    try {
      return SettingsStore.ensurePref().getSync(KEY_THEME_MODE, 'auto') as string;
    } catch (_) {
      return 'auto';
    }
  }

  static setThemeMode(mode: string): void {
    SettingsStore.ensurePref().putSync(KEY_THEME_MODE, mode);
    SettingsStore.ensurePref().flush();
  }

  // ===== 当前城市 =====
  static getCityName(): string {
    try {
      return SettingsStore.ensurePref().getSync(KEY_CITY_NAME, '北京') as string;
    } catch (_) {
      return '北京';
    }
  }

  static getCityLat(): number {
    try {
      return SettingsStore.ensurePref().getSync(KEY_CITY_LAT, 39.9042) as number;
    } catch (_) {
      return 39.9042;
    }
  }

  static getCityLon(): number {
    try {
      return SettingsStore.ensurePref().getSync(KEY_CITY_LON, 116.4074) as number;
    } catch (_) {
      return 116.4074;
    }
  }

  static setCity(name: string, lat: number, lon: number): void {
    const pref: preferences.Preferences = SettingsStore.ensurePref();
    pref.putSync(KEY_CITY_NAME, name);
    pref.putSync(KEY_CITY_LAT, lat);
    pref.putSync(KEY_CITY_LON, lon);
    pref.flush();
  }

  // ===== 自动定位 =====
  static getUseGps(): boolean {
    try {
      return SettingsStore.ensurePref().getSync(KEY_USE_GPS, false) as boolean;
    } catch (_) {
      return false;
    }
  }

  static setUseGps(enabled: boolean): void {
    SettingsStore.ensurePref().putSync(KEY_USE_GPS, enabled);
    SettingsStore.ensurePref().flush();
  }

  // ===== 自动刷新间隔 =====
  static getRefreshInterval(): string {
    try {
      return SettingsStore.ensurePref().getSync(KEY_REFRESH_INTERVAL, 'off') as string;
    } catch (_) {
      return 'off';
    }
  }

  static setRefreshInterval(interval: string): void {
    SettingsStore.ensurePref().putSync(KEY_REFRESH_INTERVAL, interval);
    SettingsStore.ensurePref().flush();
  }

  // ===== 自动检查更新 =====
  static getAutoUpdate(): boolean {
    try {
      return SettingsStore.ensurePref().getSync(KEY_AUTO_UPDATE, true) as boolean;
    } catch (_) {
      return true;
    }
  }

  static setAutoUpdate(enabled: boolean): void {
    SettingsStore.ensurePref().putSync(KEY_AUTO_UPDATE, enabled);
    SettingsStore.ensurePref().flush();
  }
}
