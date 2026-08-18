export interface WeatherData {
  cityName: string;
  updatedAt: string;
  temperature: number | null;
  condition: string;
  feelsLike: number | null;
  humidity: number | null;
  windDirect: string;
  windPower: string;
  todayHigh: number | null;
  todayLow: number | null;
  aqi: number | null;
  aqiText: string;
  warning: string | null;
  sunrise: string | null;
  sunset: string | null;
  minutelyText: string | null;
  uvIndex: string;
  sourceTag: string;
  hourly: HourlyItem[];
  daily: DailyItem[];
}

export interface HourlyItem {
  time: string;
  temperature: number | null;
  condition: string;
  isForecast: boolean;
  rainProb: number | null;
}

export interface DailyItem {
  date: string;
  dayText: string;
  nightText: string;
  high: number | null;
  low: number | null;
}
