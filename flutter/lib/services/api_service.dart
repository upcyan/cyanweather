import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// 发布版可靠的日志通道（developer.log 不会被剥除）
void _log(String s) => dev.log(s, name: 'CW');
import '../models/weather_model.dart';

class ApiService {
  static const _openMeteoBase = 'https://api.open-meteo.com/v1';
  static const _reverseGeoBase =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';
  static const _nmcBase = 'https://www.nmc.cn/rest';
  static const _caiyunBase = 'https://api.caiyunapp.com/v2.6';

  // 传统字转简体（用于匹配 NMC 行政区名）
  static Map<String, String> get _tradToSimp => {
    '東': '东', '濟': '济', '廣': '广', '陽': '阳', '陰': '阴',
    '臺': '台', '灣': '湾', '龍': '龙', '雲': '云', '島': '岛',
    '縣': '县', '區': '区', '寧': '宁', '蘇': '苏', '澤': '泽',
    '漢': '汉', '濱': '滨', '豐': '丰', '麗': '丽', '門': '门',
    '華': '华', '廈': '厦', '閩': '闽', '贛': '赣', '晉': '晋',
    '陝': '陕', '貴': '贵', '瓊': '琼', '遼': '辽', '鄒': '邹',
    '臨': '临', '萊': '莱', '蕪': '芜', '長': '长', '慶': '庆',
    '榮': '荣', '單': '单', '費': '费', '濰': '潍', '諸': '诸',
    '兗': '兖', '嶧': '峄', '鄆': '郓', '棲': '栖', '遠': '远',
    '樂': '乐', '無': '无', '蓮': '莲', '齊': '齐', '蘭': '兰',
    '鄉': '乡', '膠': '胶', '黃': '黄', '饒': '饶', '興': '兴',
    '棗': '枣', '莊': '庄', '幹': '干', '烏': '乌', '雙': '双',
    '澳': '澳', '蒼': '苍', '潁': '颍', '滁': '滁', '亳': '亳',
    '懷': '怀', '滬': '沪', '渝': '渝', '豫': '豫', '冀': '冀',
    '蒙': '蒙', '吉': '吉', '黑': '黑', '浙': '浙', '皖': '皖',
    '魯': '鲁', '鄂': '鄂', '湘': '湘', '粵': '粤', '桂': '桂',
    '瓊': '琼', '川': '川', '黔': '黔', '滇': '滇', '藏': '藏',
    '甘': '甘', '青': '青', '新': '新', '寧': '宁',
  };

  static String _simp(String s) =>
      s.split('').map((c) => _tradToSimp[c] ?? c).join('');

  static String _stripAdmin(String s) =>
      s.trim().replaceAll(RegExp(r'(自治区|自治州|特别行政区|省|市|区|县|盟|州)$'), '');

  // 清洗 NMC 文本字段：过滤 9999、0、空
  static String cleanText(String? s) {
    final v = (s ?? '').trim();
    return (v.isEmpty || v == '9999' || v == '0') ? '' : v;
  }

  // 清洗温度：>=9998 视为无效
  static double? cleanTemp(String? s) {
    final v = double.tryParse(s ?? '');
    return (v == null || v >= 9998) ? null : v;
  }

  // 完整反向地理编码：返回省/市/县
  static Future<Map<String, String>> reverseGeocodeFull(double lat, double lng) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final g = await http.get(Uri.parse(
            '$_reverseGeoBase?latitude=$lat&longitude=$lng&localityLanguage=zh'))
            .timeout(const Duration(seconds: 8));
        if (g.statusCode == 200) {
          final gj = jsonDecode(g.body);
          return {
            'prov': (gj['principalSubdivision'] ?? '').toString().trim(),
            'city': (gj['city'] ?? '').toString().trim(),
            'local': (gj['locality'] ?? '').toString().trim(),
          };
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
    }
    // 备用源：OSM Nominatim（不同域名，可绕过个别域名的 DNS 过滤）
    try {
      final n = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=jsonv2&accept-language=zh'),
          headers: {'User-Agent': 'cyanweather-app'})
          .timeout(const Duration(seconds: 8));
      if (n.statusCode == 200) {
        final nj = jsonDecode(n.body);
        final addr = nj['address'] as Map<String, dynamic>? ?? {};
        String pick(List<String> keys) {
          for (final k in keys) {
            final v = (addr[k] ?? '').toString().trim();
            if (v.isNotEmpty) return v;
          }
          return '';
        }
        final prov = pick(['state', 'province']);
        final city = pick(['city']);
        final local = pick(['county', 'suburb', 'town', 'village', 'district']);
        if (prov.isNotEmpty || city.isNotEmpty || local.isNotEmpty) {
          return {'prov': prov, 'city': city, 'local': local};
        }
      }
    } catch (_) {}
    return {};
  }

  // ... existing methods ...

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
  static Future<WeatherData> fetchWeather(double lat, double lng,
      {String? nmcStationId, Future<String?> Function()? resolveStation}) async {
    _log('fetchWeather ENTER lat=$lat lng=$lng nmcStationId=$nmcStationId');
    final url = '$_openMeteoBase/forecast?latitude=$lat&longitude=$lng'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m'
        '&hourly=temperature_2m,weather_code,precipitation_probability,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max'
        '&timezone=auto&forecast_days=15&past_days=1';
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('API请求失败: ${response.statusCode}');
    final json = jsonDecode(response.body);

    // Fetch AQI separately（该子域名在部分网络下会被间歇性过滤，加重试）
    String aqiText = '';
    int? aqi;
    _log('start lat=$lat lng=$lng nmcStationId=$nmcStationId');
    final airUrl =
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lng&current=us_aqi';
    for (var attempt = 0; attempt < 3 && aqi == null; attempt++) {
      try {
        final airResp = await http
            .get(Uri.parse(airUrl))
            .timeout(const Duration(seconds: 10));
        debugPrint('[CW] aqi try$attempt http ${airResp.statusCode}');
        _log('try$attempt http ${airResp.statusCode}');
        if (airResp.statusCode == 200) {
          final airJson = jsonDecode(airResp.body);
          aqi = airJson['current']?['us_aqi']?.round();
          _log('try$attempt us_aqi raw=${airJson['current']?['us_aqi']} -> aqi=$aqi');
          aqiText = _aqiText(aqi);
        }
      } catch (e) {
        debugPrint('[CW] aqi try$attempt ERR ${e.runtimeType}: $e');
      }
      if (aqi == null && attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    debugPrint('[CW] aqi openmeteo done aqi=$aqi');
    _log('openmeteo done aqi=$aqi');
    // Open-Meteo 空气质量兜底：air-quality 子域名被网络过滤时，用气象台站点数据补 AQI
    if (aqi == null) {
      var sid = nmcStationId ?? '';
      if (sid.isEmpty && resolveStation != null) {
        try { sid = await resolveStation() ?? ''; } catch (_) {}
      }
      debugPrint('[CW] aqi fallback sid=[$sid]');
      _log('fallback sid=[$sid]');
      if (sid.isEmpty) return _parseOpenMeteo(json, aqi: null, aqiText: '');
      try {
        final nresp = await http
            .get(Uri.parse('$_nmcBase/weather?stationid=$sid'))
            .timeout(const Duration(seconds: 10));
        if (nresp.statusCode == 200) {
          final nj = jsonDecode(nresp.body);
          final air = nj is Map && nj['data'] is Map ? nj['data']['air'] : null;
          debugPrint('[CW] aqi nmc air=$air');
          _log('nmc air=$air');
          if (air is Map) {
            final raw = air['aqi'];
            final av = raw is num ? raw.round() : int.tryParse('$raw');
            _log('nmc raw=$raw av=$av');
            if (av != null) {
              aqi = av;
              final t = '${air['text'] ?? ''}'.trim();
              aqiText = t.isNotEmpty ? t : _aqiText(av);
            }
          }
        }
      } catch (_) {}
    }
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
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final nowHour = DateTime.now().toIso8601String().substring(0, 13);
    // 全部小时序列（含 past_days 的昨日小时）
    final allHours = <HourlyItem>[];
    final hTimes = h['time'] as List;
    for (var i = 0; i < hTimes.length; i++) {
      final t = hTimes[i].toString();
      final isPast = t.substring(0, 10).compareTo(todayStr) < 0;
      allHours.add(HourlyItem(
          time: t,
          temperature: (h['temperature_2m'][i] as num?)?.toDouble(),
          condition: _wmoToText(h['weather_code'][i] as int? ?? 0),
          rainProb: (h['precipitation_probability'][i] as num?)?.toDouble(),
          isForecast: !isPast));
    }
    // 展示用：从当前小时起最多48条
    final hourly = <HourlyItem>[];
    for (var i = 0; i < allHours.length && hourly.length < 48; i++) {
      if (allHours[i].time.compareTo(nowHour) >= 0) hourly.add(allHours[i]);
    }
    final daily = <DailyItem>[];
    final dTimes = d['time'] as List;
    var todayIdx = -1;
    for (var i = 0; i < dTimes.length; i++) {
      if (todayIdx < 0 && dTimes[i].toString().compareTo(todayStr) >= 0) todayIdx = i;
    }
    for (var i = todayIdx < 0 ? 0 : todayIdx; i < dTimes.length; i++) {
      daily.add(DailyItem(
          date: dTimes[i].toString(),
          dayText: _wmoToText(d['weather_code'][i] as int? ?? 0),
          high: (d['temperature_2m_max'][i] as num?)?.toDouble(),
          low: (d['temperature_2m_min'][i] as num?)?.toDouble()));
    }
    // 昨日（past_days=1 时 daily[0]/hourly 前段为昨天）
    YesterdayData? yesterday;
    if (todayIdx > 0) {
      final yh = allHours
          .where((x) => x.time.substring(0, 10).compareTo(todayStr) < 0)
          .toList();
      final yHours = yh.length > 24
          ? yh.sublist(yh.length - 24)
          : yh;
      yesterday = YesterdayData(
          high: (d['temperature_2m_max'][todayIdx - 1] as num?)?.toDouble(),
          low: (d['temperature_2m_min'][todayIdx - 1] as num?)?.toDouble(),
          hourly: yHours);
    }
    final sunrises = d['sunrise'] as List? ?? [],
        sunsets = d['sunset'] as List? ?? [];
    String atIdx(List? l) {
      if (l == null || todayIdx < 0 || todayIdx >= l.length) return '';
      return l[todayIdx].toString();
    }
    final sunrise = atIdx(sunrises), sunset = atIdx(sunsets);
    final uvStr = atIdx(d['uv_index_max'] as List?);
    final uvText = uvStr.isNotEmpty
        ? _uvLevel(double.tryParse(uvStr) ?? 0)
        : '';
    return WeatherData(
        cityName: '未识别位置',
        condition: _wmoToText(c['weather_code'] as int? ?? 0),
        temperature: (c['temperature_2m'] as num?)?.toDouble() ?? 0,
        feelsLike: (c['apparent_temperature'] as num?)?.toDouble(),
        todayHigh: daily.isNotEmpty ? daily[0].high : null,
        todayLow: daily.isNotEmpty ? daily[0].low : null,
        yesterday: yesterday,
        humidity: c['relative_humidity_2m'] as int?,
        windDirect:
            _windDir((c['wind_direction_10m'] as num?)?.toDouble() ?? 0),
        windPower: _beaufort((c['wind_speed_10m'] as num?)?.toDouble() ?? 0),
        aqi: aqi,
        aqiText: aqiText,
        sunrise:
            sunrise.length >= 16 ? sunrise.substring(11, 16) : '',
        sunset:
            sunset.length >= 16 ? sunset.substring(11, 16) : '',
        uvIndex: uvText,
        sourceTag: '数据来源：Open-Meteo',
        updatedAt: _nowStamp(),
        hourlyLabel: '未来48小时逐时预报',
        hourly: hourly,
        daily: daily);
  }

  static String _nowStamp() {
    final n = DateTime.now();
    return '${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
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
