class WeatherData {
  final String cityName;
  final String updatedAt;
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
  final String warning;
  final String hourlyLabel;
  final YesterdayData? yesterday;
  final List<HourlyItem> hourly;
  final List<DailyItem> daily;

  WeatherData({
    required this.cityName,
    this.updatedAt = '',
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
    this.warning = '',
    this.hourlyLabel = '未来48小时逐时预报',
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
  final List<HourlyItem> hourly;
  YesterdayData({this.high, this.low, this.hourly = const []});
}

// ---- JSON 持久化（用于"最后好数据"离线缓存）----
class WeatherCodec {
  static Map<String, dynamic> encode(WeatherData w) => {
        'cityName': w.cityName,
        'updatedAt': w.updatedAt,
        'condition': w.condition,
        'temperature': w.temperature,
        'feelsLike': w.feelsLike,
        'todayHigh': w.todayHigh,
        'todayLow': w.todayLow,
        'humidity': w.humidity,
        'windDirect': w.windDirect,
        'windPower': w.windPower,
        'aqi': w.aqi,
        'aqiText': w.aqiText,
        'sunrise': w.sunrise,
        'sunset': w.sunset,
        'uvIndex': w.uvIndex,
        'minutelyText': w.minutelyText,
        'sourceTag': w.sourceTag,
        'warning': w.warning,
        'hourlyLabel': w.hourlyLabel,
        'yesterday': w.yesterday == null
            ? null
            : {
                'high': w.yesterday!.high,
                'low': w.yesterday!.low,
                'hourly': w.yesterday!.hourly.map(hToJson).toList(),
              },
        'hourly': w.hourly.map(hToJson).toList(),
        'daily': w.daily
            .map((d) => {
                  'date': d.date,
                  'dayText': d.dayText,
                  'nightText': d.nightText,
                  'high': d.high,
                  'low': d.low,
                })
            .toList(),
      };

  static WeatherData decode(Map<String, dynamic> j) {
    final y = j['yesterday'] as Map<String, dynamic>?;
    return WeatherData(
      cityName: (j['cityName'] ?? '').toString(),
      updatedAt: (j['updatedAt'] ?? '').toString(),
      condition: (j['condition'] ?? '').toString(),
      temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
      feelsLike: (j['feelsLike'] as num?)?.toDouble(),
      todayHigh: (j['todayHigh'] as num?)?.toDouble(),
      todayLow: (j['todayLow'] as num?)?.toDouble(),
      humidity: j['humidity'] as int?,
      windDirect: (j['windDirect'] ?? '').toString(),
      windPower: (j['windPower'] ?? '').toString(),
      aqi: j['aqi'] as int?,
      aqiText: (j['aqiText'] ?? '').toString(),
      sunrise: (j['sunrise'] ?? '').toString(),
      sunset: (j['sunset'] ?? '').toString(),
      uvIndex: (j['uvIndex'] ?? '').toString(),
      minutelyText: (j['minutelyText'] ?? '').toString(),
      sourceTag: (j['sourceTag'] ?? '').toString(),
      warning: (j['warning'] ?? '').toString(),
      hourlyLabel: (j['hourlyLabel'] ?? '').toString(),
      yesterday: y == null
          ? null
          : YesterdayData(
              high: (y['high'] as num?)?.toDouble(),
              low: (y['low'] as num?)?.toDouble(),
              hourly:
                  ((y['hourly'] as List?) ?? const []).map(hFromJson).toList()),
      hourly: ((j['hourly'] as List?) ?? const []).map(hFromJson).toList(),
      daily: ((j['daily'] as List?) ?? const [])
          .map((d) => DailyItem(
                date: (d['date'] ?? '').toString(),
                dayText: (d['dayText'] ?? '').toString(),
                nightText: (d['nightText'] ?? '').toString(),
                high: (d['high'] as num?)?.toDouble(),
                low: (d['low'] as num?)?.toDouble(),
              ))
          .toList(),
    );
  }

  static Map<String, dynamic> hToJson(HourlyItem h) => {
        'time': h.time,
        'temperature': h.temperature,
        'condition': h.condition,
        'isForecast': h.isForecast,
        'rainProb': h.rainProb,
      };

  static HourlyItem hFromJson(dynamic j0) {
    final j = j0 as Map<String, dynamic>;
    return HourlyItem(
      time: (j['time'] ?? '').toString(),
      temperature: (j['temperature'] as num?)?.toDouble(),
      condition: (j['condition'] ?? '').toString(),
      isForecast: (j['isForecast'] as bool?) ?? true,
      rainProb: (j['rainProb'] as num?)?.toDouble(),
    );
  }
}

