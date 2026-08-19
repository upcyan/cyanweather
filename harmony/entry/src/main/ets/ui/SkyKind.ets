/**
 * 天气类型枚举与条件映射
 * 移植自 Android WeatherMapper.kt
 */

export enum SkyKind {
  SUN,
  MOON,
  CLOUD,
  PARTLY,
  RAIN,
  SNOW,
  THUNDER,
  FOG,
  HAZE,
  WIND,
  SLEET,
  UNKNOWN
}

/**
 * 将中文天气条件映射为 SkyKind
 * 优先匹配彩云天气 skycon，否则按关键词匹配 NMC 文本
 */
export function condToKind(condition: string, sourceTag: string): SkyKind {
  if (sourceTag.includes('彩云')) {
    return caiyunSkyconKind(toSkycon(condition));
  }
  return nmcSkyconKind(condition);
}

function toSkycon(text: string): string {
  const map: Record<string, string> = {
    '晴': 'CLEAR_DAY',
    '多云': 'PARTLY_CLOUDY_DAY',
    '阴': 'CLOUDY',
    '小雨': 'LIGHT_RAIN',
    '中雨': 'MODERATE_RAIN',
    '大雨': 'HEAVY_RAIN',
    '暴雨': 'STORM_RAIN',
    '小雪': 'LIGHT_SNOW',
    '中雪': 'MODERATE_SNOW',
    '大雪': 'HEAVY_SNOW',
    '暴雪': 'STORM_SNOW',
    '雨夹雪': 'SLEET',
    '雾': 'FOG',
    '霾': 'HAZE'
  };
  return map[text] ?? 'CLEAR_DAY';
}

function caiyunSkyconKind(code: string): SkyKind {
  switch (code) {
    case 'CLEAR_DAY': return SkyKind.SUN;
    case 'CLEAR_NIGHT': return SkyKind.MOON;
    case 'PARTLY_CLOUDY_DAY':
    case 'PARTLY_CLOUDY_NIGHT': return SkyKind.PARTLY;
    case 'CLOUDY': return SkyKind.CLOUD;
    case 'LIGHT_HAZE':
    case 'MODERATE_HAZE':
    case 'HEAVY_HAZE':
    case 'DUST':
    case 'SAND': return SkyKind.HAZE;
    case 'LIGHT_RAIN':
    case 'MODERATE_RAIN':
    case 'HEAVY_RAIN':
    case 'STORM_RAIN': return SkyKind.RAIN;
    case 'FOG': return SkyKind.FOG;
    case 'LIGHT_SNOW':
    case 'MODERATE_SNOW':
    case 'HEAVY_SNOW':
    case 'STORM_SNOW': return SkyKind.SNOW;
    case 'HAIL': return SkyKind.THUNDER;
    case 'SLEET': return SkyKind.SLEET;
    case 'WIND': return SkyKind.WIND;
    default: return SkyKind.UNKNOWN;
  }
}

function nmcSkyconKind(text: string): SkyKind {
  if (text.includes('雷')) return SkyKind.THUNDER;
  if (text.includes('雪')) return SkyKind.SNOW;
  if (text.includes('雨夹雪')) return SkyKind.SLEET;
  if (text.includes('雨')) return SkyKind.RAIN;
  if (text.includes('晴')) return SkyKind.SUN;
  if (text.includes('云')) return SkyKind.PARTLY;
  if (text.includes('阴')) return SkyKind.CLOUD;
  if (text.includes('雾')) return SkyKind.FOG;
  if (text.includes('霾') || text.includes('尘') || text.includes('沙')) return SkyKind.HAZE;
  if (text.includes('风')) return SkyKind.WIND;
  return SkyKind.UNKNOWN;
}
