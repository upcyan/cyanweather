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

  WeatherData copyWith({
    String? cityName,
    String? condition,
    double? temperature,
    double? feelsLike,
    double? todayHigh,
    double? todayLow,
    int? humidity,
    String? windDirect,
    String? windPower,
    int? aqi,
    String? aqiText,
    String? sunrise,
    String? sunset,
    String? uvIndex,
    String? minutelyText,
    String? sourceTag,
    YesterdayData? yesterday,
    List<HourlyItem>? hourly,
    List<DailyItem>? daily,
  }) {
    return WeatherData(
      cityName: cityName ?? this.cityName,
      condition: condition ?? this.condition,
      temperature: temperature ?? this.temperature,
      feelsLike: feelsLike ?? this.feelsLike,
      todayHigh: todayHigh ?? this.todayHigh,
      todayLow: todayLow ?? this.todayLow,
      humidity: humidity ?? this.humidity,
      windDirect: windDirect ?? this.windDirect,
      windPower: windPower ?? this.windPower,
      aqi: aqi ?? this.aqi,
      aqiText: aqiText ?? this.aqiText,
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      uvIndex: uvIndex ?? this.uvIndex,
      minutelyText: minutelyText ?? this.minutelyText,
      sourceTag: sourceTag ?? this.sourceTag,
      yesterday: yesterday ?? this.yesterday,
      hourly: hourly ?? this.hourly,
      daily: daily ?? this.daily,
    );
  }
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
