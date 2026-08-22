class WeatherData {
  final String cityName;
  final String condition;
  final double temperature;
  final double? feelsLike;
  final double? todayHigh;
  final double? todayLow;
  final int? humidity;
  final String windDirect;
  final String windPower;
  final int? aqi;
  final String aqiText;
  final String sunrise;
  final String sunset;
  final String uvIndex;
  final String minutelyText;
  final String sourceTag;
  final YesterdayData? yesterday;
  final List<HourlyItem> hourly;
  final List<DailyItem> daily;

  WeatherData({
    required this.cityName,
    required this.condition,
    required this.temperature,
    this.feelsLike,
    this.todayHigh,
    this.todayLow,
    this.humidity,
    this.windDirect = '',
    this.windPower = '',
    this.aqi,
    this.aqiText = '',
    this.sunrise = '',
    this.sunset = '',
    this.uvIndex = '',
    this.minutelyText = '',
    this.sourceTag = '',
    this.yesterday,
    this.hourly = const [],
    this.daily = const [],
  });
}

class HourlyItem {
  final String time;
  final double? temperature;
  final String condition;
  final bool isForecast;
  final double? rainProb;

  HourlyItem({
    required this.time,
    this.temperature,
    this.condition = '',
    this.isForecast = true,
    this.rainProb,
  });
}

class DailyItem {
  final String date;
  final String dayText;
  final String nightText;
  final double? high;
  final double? low;

  DailyItem({
    required this.date,
    this.dayText = '',
    this.nightText = '',
    this.high,
    this.low,
  });
}

class YesterdayData {
  final double? high;
  final double? low;
  YesterdayData({this.high, this.low});
}
