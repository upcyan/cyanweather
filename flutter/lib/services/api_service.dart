import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class ApiService {
  static const _openMeteoBase = 'https://api.open-meteo.com/v1';
  static const _reverseGeoBase =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';
  static const _nmcBase = 'https://www.nmc.cn/rest';
  static const _caiyunBase = 'https://api.caiyunapp.com/v2.6';

  // Caiyun V1
  static Future<Map<String, dynamic>> fetchCaiyunV1(
      String token, double lat, double lng) async {
    final url = '$_caiyunBase/$token/$lng,$lat/weather.json';
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('彩云API请求失败: ${response.statusCode}');
    return jsonDecode(response.body);
  }

  // Open-Meteo
  static Future<WeatherData> fetchWeather(double lat, double lng) async {
    final url = '$_openMeteoBase/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m'
        '&hourly=temperature_2m,weather_code,precipitation_probability,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max'
        '&timezone=auto&forecast_days=15';
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('API请求失败: ${response.statusCode}');
    final json = jsonDecode(response.body);

    // Fetch AQI separately
    String aqiText = '';
    int? aqi;
    try {
      final airUrl =
          'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lng&current=us_aqi';
      final airResp = await http
          .get(Uri.parse(airUrl))
          .timeout(const Duration(seconds: 10));
      if (airResp.statusCode == 200) {
        final airJson = jsonDecode(airResp.body);
        aqi = airJson['current']?['us_aqi']?.round();
        aqiText = _aqiText(aqi);
      }
    } catch (_) {}

    return _parseOpenMeteo(json, aqi: aqi, aqiText: aqiText);
  }

  // NMC
  static Future<Map<String, dynamic>> fetchNmcWeather(String stationId) async {
    final url = '$_nmcBase/weather?stationid=$stationId';
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('气象局API请求失败');
    return jsonDecode(response.body);
  }

  static Future<List<Map<String, dynamic>>> fetchNmcProvinces() async {
    final response = await http
        .get(Uri.parse('$_nmcBase/province'))
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  static Future<List<Map<String, dynamic>>> fetchNmcCities(
      String provinceCode) async {
    final response = await http
        .get(Uri.parse('$_nmcBase/province/$provinceCode'))
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  // Reverse geocode
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final g = await http
          .get(Uri.parse(
            '$_reverseGeoBase?latitude=$lat&longitude=$lng&localityLanguage=zh',
          ))
          .timeout(const Duration(seconds: 10));
      if (g.statusCode != 200) return '';
      final gj = jsonDecode(g.body);
      for (final key in ['locality', 'city', 'principalSubdivision']) {
        final value = gj[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    return '';
  }

  // Parse Open-Meteo
  static WeatherData _parseOpenMeteo(Map<String, dynamic> json,
      {int? aqi, String aqiText = ''}) {
    final c = json['current'], h = json['hourly'], d = json['daily'];
    final hourly = <HourlyItem>[];
    final hTimes = h['time'] as List;
    final now = DateTime.now().toIso8601String().substring(0, 13);
    for (var i = 0; i < hTimes.length && hourly.length < 48; i++) {
      final t = hTimes[i].toString();
      if (t.compareTo(now) >= 0) {
        hourly.add(HourlyItem(
            time: t,
            temperature: (h['temperature_2m'][i] as num?)?.toDouble(),
            condition: _wmoToText(h['weather_code'][i] as int? ?? 0),
            rainProb: (h['precipitation_probability'][i] as num?)?.toDouble()));
      }
    }
    final daily = <DailyItem>[];
    final dTimes = d['time'] as List;
    for (var i = 0; i < dTimes.length; i++) {
      daily.add(DailyItem(
          date: dTimes[i].toString(),
          dayText: _wmoToText(d['weather_code'][i] as int? ?? 0),
          high: (d['temperature_2m_max'][i] as num?)?.toDouble(),
          low: (d['temperature_2m_min'][i] as num?)?.toDouble()));
    }
    final sunrises = d['sunrise'] as List? ?? [],
        sunsets = d['sunset'] as List? ?? [];
    final uvMax = (d['uv_index_max'] as List?)
        ?.firstWhere((_) => true, orElse: () => null);
    final uvText =
        uvMax != null ? _uvLevel((uvMax as num?)?.toDouble() ?? 0) : '';
    return WeatherData(
        cityName: '未识别位置',
        condition: _wmoToText(c['weather_code'] as int? ?? 0),
        temperature: (c['temperature_2m'] as num?)?.toDouble() ?? 0,
        feelsLike: (c['apparent_temperature'] as num?)?.toDouble(),
        todayHigh: daily.isNotEmpty ? daily[0].high : null,
        todayLow: daily.isNotEmpty ? daily[0].low : null,
        humidity: c['relative_humidity_2m'] as int?,
        windDirect:
            _windDir((c['wind_direction_10m'] as num?)?.toDouble() ?? 0),
        windPower: _beaufort((c['wind_speed_10m'] as num?)?.toDouble() ?? 0),
        aqi: aqi,
        aqiText: aqiText,
        sunrise:
            sunrises.isNotEmpty ? sunrises[0].toString().substring(11, 16) : '',
        sunset:
            sunsets.isNotEmpty ? sunsets[0].toString().substring(11, 16) : '',
        uvIndex: uvText,
        sourceTag: '数据来源：Open-Meteo',
        hourly: hourly,
        daily: daily);
  }

  static String _wmoToText(int c) =>
      {
        0: '晴',
        1: '大部晴朗',
        2: '多云',
        3: '阴',
        45: '雾',
        48: '雾',
        51: '毛毛雨',
        53: '毛毛雨',
        55: '毛毛雨',
        61: '雨',
        63: '雨',
        65: '雨',
        71: '雪',
        73: '雪',
        75: '雪',
        80: '阵雨',
        81: '阵雨',
        82: '阵雨',
        95: '雷阵雨'
      }[c] ??
      '未知';
  static String _windDir(double d) {
    const dirs = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    return dirs[((d + 22.5) / 45).floor() % 8];
  }

  static String _beaufort(double s) {
    final k = s * 3.6;
    if (k < 2) return '0级';
    if (k < 12) return '1级';
    if (k < 20) return '2级';
    if (k < 29) return '3级';
    if (k < 39) return '4级';
    if (k < 50) return '5级';
    if (k < 62) return '6级';
    return '7级';
  }

  static String _aqiText(int? aqi) {
    if (aqi == null) return '-';
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    return '重度污染';
  }

  static String _uvLevel(double uv) {
    if (uv <= 2) return '低';
    if (uv <= 5) return '中等';
    if (uv <= 7) return '高';
    if (uv <= 10) return '很高';
    return '极高';
  }
}
