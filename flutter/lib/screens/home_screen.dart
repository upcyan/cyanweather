import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/weather_model.dart';
import '../services/api_service.dart';
import '../services/weather_aggregator.dart';
import '../widgets/weather_icon.dart';
import 'settings_screen.dart';
import 'city_picker_screen.dart';
import 'rain_forecast_screen.dart';

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HomeScreen({super.key, required this.prefs});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  WeatherData? _weather;
  bool _loading = true;
  bool _refreshing = false;
  bool _fetching = false;
  Timer? _autoTimer;
  DateTime? _pausedAt;
  String? _error;
  String _source = 'openmeteo';
  List<String> _weatherSources = ['nmc', 'openmeteo'];
  String _cityName = '';
  String _cityCode = '';
  double _lat = 39.9042, _lng = 116.4074;
  String _caiyunToken = '';
  String _qweatherHost = '';
  String _qweatherKey = '';
  String _fontSize = 'large';
  bool _useGps = true;
  String? _locationNotice;
  bool _locationServiceDisabled = false;
  bool _permissionDenied = false;
  double get _fs =>
      {'standard': 1.0, 'large': 1.3, 'xlarge': 1.6}[_fontSize] ?? 1.3;

  // 繁体转简体映射
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _hydrateLastWeather();
    _armAutoRefresh();
    unawaited(_initialize());
  }

  /// 启动即渲染上次成功获取的天气（离线/弱网也有内容）
  void _hydrateLastWeather() {
    try {
      final raw = widget.prefs.getString('lastWeather');
      if (raw != null && raw.isNotEmpty) {
        final w = WeatherCodec.decode(jsonDecode(raw) as Map<String, dynamic>);
        if (w.condition.isNotEmpty || w.hourly.isNotEmpty) {
          _weather = w;
          _loading = false;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final interval = widget.prefs.getString('refreshInterval') ?? '30';
      // native 行为：on_resume 档，离开超过30秒后回到前台即刷新
      if (interval == 'on_resume') {
        final elapsed = _pausedAt == null
            ? const Duration(days: 1)
            : DateTime.now().difference(_pausedAt!);
        if (elapsed > const Duration(seconds: 30)) {
          unawaited(_loadWeather());
        }
      }
      if (_useGps) unawaited(_reloadLocation(requestPermission: false));
    } else if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    }
  }

  /// 按 refreshInterval 设置武装周期刷新定时器（对齐 native 挡位）
  void _armAutoRefresh() {
    _autoTimer?.cancel();
    final minutes =
        int.tryParse(widget.prefs.getString('refreshInterval') ?? '30');
    if (minutes == null || minutes <= 0) return;
    _autoTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      unawaited(_loadWeather());
    });
  }

  Future<void> _initialize() async {
    // 启动先用缓存的天气立即渲染（_hydrateLastWeather），定位完成后只刷新一次
    unawaited(_checkUpdate());
    await _refreshLocation(requestPermission: true);
    if (!mounted) return;
    await _loadWeather();
  }

  void _loadPrefs() {
    _source = widget.prefs.getString('source') ?? 'openmeteo';
    // 多源列表（对齐 native weatherSources）：迁移旧单选；全新安装默认气象局+Open-Meteo 混合
    final rawSources = widget.prefs.getString('weatherSources');
    if (rawSources != null && rawSources.isNotEmpty) {
      try {
        final list = (jsonDecode(rawSources) as List)
            .map((e) => e.toString())
            .where((s) => ['nmc', 'openmeteo', 'caiyun', 'qweather'].contains(s))
            .toList();
        _weatherSources = list;
      } catch (_) {}
    } else if (widget.prefs.getString('source') != null) {
      _weatherSources = [_source];
    }
    if (_weatherSources.isEmpty) _weatherSources = ['nmc', 'openmeteo'];
    _cityName = widget.prefs.getString('cityName') ?? '';
    _cityCode = widget.prefs.getString('cityCode') ?? '';
    _lat = widget.prefs.getDouble('lat') ?? 39.9042;
    _lng = widget.prefs.getDouble('lng') ?? 116.4074;
    _fontSize = widget.prefs.getString('fontSize') ?? 'large';
    _caiyunToken = widget.prefs.getString('caiyunToken') ?? '';
    _qweatherHost = widget.prefs.getString('qweatherHost') ?? '';
    _qweatherKey = widget.prefs.getString('qweatherKey') ?? '';
    _useGps = widget.prefs.getBool('useGps') ?? true;
  }

  Future<void> _refreshLocation({required bool requestPermission}) async {
    if (!_useGps) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted)
        setState(() {
          _locationNotice = '定位服务未开启，当前显示默认城市北京';
          _locationServiceDisabled = true;
          _permissionDenied = false;
        });
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted)
        setState(() {
          _locationNotice = '未获取定位权限，请手动选择城市；当前默认显示北京天气';
          _locationServiceDisabled = false;
          _permissionDenied = true;
        });
      return;
    }
    double? nLat;
    double? nLng;
    // 首选原生通道（对齐 webf 端：系统 LocationManager 网络优先，规避 geolocator 在 MIUI 上的超时问题）
    try {
      final fix =
          await const MethodChannel('cyanweather/location').invokeMethod<String>('fix');
      if (fix != null) {
        final j = jsonDecode(fix);
        nLat = (j['latitude'] as num?)?.toDouble();
        nLng = (j['longitude'] as num?)?.toDouble();
      }
    } catch (_) {}
    if (nLat == null || nLng == null) {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // 室内 GPS 冷启动常超时；回退低精度网络定位（对齐 native NETWORK_PROVIDER 快速出坐标）
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }
      }
      nLat = position?.latitude;
      nLng = position?.longitude;
    }
    if (nLat == null || nLng == null) {
      if (mounted)
        setState(() {
          _locationNotice = '定位失败，请检查网络/GPS后重试；当前显示默认城市北京';
          _locationServiceDisabled = false;
        });
      return;
    }
    await widget.prefs.setDouble('lat', nLat);
    await widget.prefs.setDouble('lng', nLng);
    await widget.prefs.setString('cityName', '');
    await widget.prefs.setString('cityCode', '');
    if (mounted)
      setState(() {
        _lat = nLat!;
        _lng = nLng!;
        _cityName = '';
        _cityCode = '';
        _locationNotice = null;
        _locationServiceDisabled = false;
        _permissionDenied = false;
      });
    // GPS：自动解析气象站代码（open-meteo 空气质量兜底也需要）
    if (_useGps) {
      await _resolveNmcCity(nLat, nLng);
    }
  }

  Future<void> _reloadLocation({bool requestPermission = true}) async {
    await _refreshLocation(requestPermission: requestPermission);
    if (mounted) await _loadWeather();
  }

  /// 供 Open-Meteo AQI 兜底使用：确保有气象站编码，返回编码（失败返回 null）
  Future<String?> _stationResolver() async {
    if (_cityCode.isNotEmpty) return _cityCode;
    await _resolveNmcCity(_lat, _lng);
    return _cityCode.isEmpty ? null : _cityCode;
  }

  Future<void> _resolveNmcCity(double lat, double lng) async {
    try {
      var geo = await ApiService.reverseGeocodeFull(lat, lng);
      if ((geo['prov'] ?? '').isEmpty &&
          (geo['city'] ?? '').isEmpty &&
          (geo['local'] ?? '').isEmpty) {
        // 网络反地理编码失败时，回退上次成功缓存
        geo = {
          'prov': widget.prefs.getString('geoProv') ?? '',
          'city': widget.prefs.getString('geoCity') ?? '',
          'local': widget.prefs.getString('geoLocal') ?? '',
        };
      }
      final provName = _simp(geo['prov'] ?? '');
      final cityName = _simp(geo['city'] ?? '');
      final locName = _simp(geo['local'] ?? '');
      if (provName.isEmpty && cityName.isEmpty && locName.isEmpty) return;
      final provinces = await ApiService.fetchNmcProvinces();
      Map<String, dynamic>? prov;
      for (final p in provinces) {
        final n = _stripAdmin(_simp(p['name']?.toString() ?? ''));
        if (n.isNotEmpty && provName.contains(n)) { prov = p; break; }
      }
      prov ??= provinces.first;
      final cities = await ApiService.fetchNmcCities(prov['code'].toString());
      bool match(Map<String, dynamic> c, String g) {
        final full = (c['city']?.toString() ?? '').trim();
        if (full.isEmpty || g.isEmpty) return false;
        final stripped = _stripAdmin(full);
        return g.contains(full) || (stripped.length >= 2 && g.contains(stripped));
      }
      Map<String, dynamic>? picked;
      for (final g in [locName, cityName]) {
        if (g.isEmpty) continue;
        for (final c in cities) { if (match(c, g)) { picked = c; break; } }
        if (picked != null) break;
      }
      picked ??= cities.first;
      // 缓存成功解析的地理信息，供网络异常时离线复用
      unawaited(widget.prefs.setString('geoProv', geo['prov'] ?? ''));
      unawaited(widget.prefs.setString('geoCity', geo['city'] ?? ''));
      unawaited(widget.prefs.setString('geoLocal', geo['local'] ?? ''));
      final display = locName.isNotEmpty ? locName : (cityName.isNotEmpty ? cityName : _simp(picked['city']?.toString() ?? ''));
      await widget.prefs.setString('cityName', display);
      await widget.prefs.setString('cityCode', picked!['code'].toString());
      if (mounted) setState(() { _cityName = display; _cityCode = picked!['code'].toString(); });
    } catch (_) {}
  }

  // 清洗 NMC 文本：过滤 9999/0/空
  static String _cleanNmcText(String? s) {
    final v = (s ?? '').trim();
    return (v.isEmpty || v == '9999' || v == '0') ? '' : v;
  }

  // 清洗温度：>=9998 视为无效
  static double? _cleanNmcTemp(String? s) {
    final v = double.tryParse(s ?? '');
    return (v == null || v >= 9998) ? null : v;
  }

  // 合并白天/夜间天气文本
  static String _combineDayNight(String day, String night) {
    if (day.isNotEmpty && night.isNotEmpty && day != night) return '$day转$night';
    if (day.isNotEmpty) return day;
    if (night.isNotEmpty) return night;
    return '-';
  }

  Future<void> _loadWeather() async {
    // 防重入：避免并发请求互相覆盖结果（_fetching 仅表示网络请求进行中）
    if (_fetching) return;
    final isRefresh = _weather != null;
    _fetching = true;
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      WeatherData w;
      // 多源混合（对齐 native）：并行拉取所有启用源，成功多个则加权聚合
      final bySource = <String, WeatherData>{};
      final failures = <String>[];
      await Future.wait(_weatherSources.map((s) async {
        try {
          bySource[s] = await _fetchSource(s);
        } catch (e) {
          failures.add('${WeatherAggregator.sourceName(s)}：${_shortErr(e)}');
        }
      }));
      if (bySource.isEmpty) {
        throw Exception(failures.isEmpty ? '没有启用可用的天气源' : failures.join('；'));
      }
      // primary 与 native 一致：按启用顺序取第一个成功源
      final ordered = _weatherSources.where((s) => bySource.containsKey(s)).toList();
      if (ordered.length == 1) {
        w = bySource[ordered.first]!
            .copyWith(sourceTag: '数据来源：${WeatherAggregator.sourceName(ordered.first)}');
      } else {
        w = WeatherAggregator.aggregate(
            ordered.map((s) => MapEntry(s, bySource[s]!)).toList());
      }
      _fetching = false;
      setState(() {
        _weather = w;
        _loading = false;
        _refreshing = false;
      });
      // 持久化最后好数据，供下次启动离线渲染
      try {
        final encoded = jsonEncode(WeatherCodec.encode(w));
        await widget.prefs.setString('lastWeather', encoded);
      } catch (_) {}
    } catch (e) {
      _fetching = false;
      final msg = e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup')
          ? '无法连接网络，请检查Wi-Fi或移动数据是否开启'
          : e.toString().contains('timeout')
              ? '网络请求超时，请稍后重试'
              : e.toString();
      setState(() {
        _error = msg;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<WeatherData> _fetchSource(String id) async {
    switch (id) {
      case 'caiyun':
        if (_caiyunToken.isEmpty) throw Exception('凭证未填写完整');
        return _parseCaiyun(
            await ApiService.fetchCaiyunV1(_caiyunToken, _lat, _lng), _cityName);
      case 'nmc':
        // 无站点编码时先按定位解析最近气象站（对齐 native 行为）
        if (_cityCode.isEmpty) {
          try {
            await _resolveNmcCity(_lat, _lng);
          } catch (_) {}
        }
        if (_cityCode.isEmpty) throw Exception('站点未解析');
        return _parseNmc(
            await ApiService.fetchNmcWeather(_cityCode), _cityName);
      case 'qweather':
        final w = await ApiService.fetchQWeather(
            _qweatherHost, _qweatherKey, _lat, _lng, _cityName);
        return _cityName.isEmpty ? w.copyWith(cityName: '当前位置') : w;
      default: // openmeteo
        final w = await ApiService.fetchWeather(_lat, _lng,
            nmcStationId: _cityCode, resolveStation: _stationResolver);
        try {
          if (_cityName.isEmpty) {
            final g = await ApiService.reverseGeocode(_lat, _lng);
            if (g.isNotEmpty) {
              // 只改城市名；此前手工重建 WeatherData 曾漏掉 aqi/aqiText 导致界面显示「-」
              return w.copyWith(cityName: _simp(g));
            }
          }
        } catch (_) {}
        return w;
    }
  }

  String _shortErr(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return '网络不可用';
    }
    if (s.contains('TimeoutException') || s.contains('timeout')) return '超时';
    return s.length > 60 ? s.substring(0, 60) : s;
  }

  WeatherData _parseCaiyun(Map<String, dynamic> d, String cityName) {
    final r = d['result'];
    final rt = r?['realtime'];
    if (rt == null)
      return WeatherData(
          cityName: cityName,
          condition: '未知',
          temperature: 0,
          sourceTag: '数据来源：彩云天气');
    final windDir = rt['wind']?['direction'] ?? 0;
    final windSpd = rt['wind']?['speed'] ?? 0;
    final skycon = rt['skycon']?.toString() ?? '';
    final condition = _caiyunSkyconText(skycon);
    final minutely = r?['minutely']?['description']?.toString() ?? '';
    final daily = d['result']?['daily'];
    final temps = daily?['temperature'] as List? ?? [];
    final skys = daily?['skycon'] as List? ?? [];
    double? high, low;
    String yesterdayDate = '';
    if (temps.isNotEmpty) {
      high = (temps[0]['max'] as num?)?.toDouble();
      low = (temps[0]['min'] as num?)?.toDouble();
      yesterdayDate = temps[0]['date']?.toString() ?? '';
    }
    return WeatherData(
      cityName: cityName,
      condition: condition,
      temperature: (rt['temperature'] as num?)?.toDouble() ?? 0,
      feelsLike: (rt['apparentTemperature'] as num?)?.toDouble(),
      todayHigh: high,
      todayLow: low,
      humidity: ((rt['humidity'] ?? 0) as num).toDouble().round(),
      windDirect: _windDir(windDir.toDouble()),
      windPower: _beaufort(windSpd.toDouble()),
      sunrise: (daily?['astro'] as List?)?.isNotEmpty == true
          ? ((daily!['astro'] as List)[0]['sunrise']?['time']?.toString() ?? '')
          : '',
      sunset: (daily?['astro'] as List?)?.isNotEmpty == true
          ? ((daily!['astro'] as List)[0]['sunset']?['time']?.toString() ?? '')
          : '',
      minutelyText: minutely,
      sourceTag: '数据来源：彩云天气',
      warning: _caiyunAlert(r),
      updatedAt: _nowStamp(),
    );
  }

  String _caiyunAlert(Map<String, dynamic>? r) {
    try {
      final a = r?['alert'];
        final content = a?['content']?.toString() ?? '';
      if (content.isNotEmpty && content != '9999') return content;
    } catch (_) {}
    return '';
  }

  String _nowStamp() {
    final n = DateTime.now();
    return '${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  String _caiyunSkyconText(String s) =>
      {
        'CLEAR_DAY': '晴',
        'CLEAR_NIGHT': '晴',
        'PARTLY_CLOUDY_DAY': '多云',
        'PARTLY_CLOUDY_NIGHT': '多云',
        'CLOUDY': '阴',
        'RAINY': '雨',
        'SNOW': '雪',
        'THUNDER': '雷阵雨',
        'FOG': '雾',
        'WIND': '大风',
        'HAZE': '霾',
      }[s] ??
      '未知';

  WeatherData _parseNmc(Map<String, dynamic> d, String cityName) {
    final real = d['data']?['real'];
    final w = real?['weather'];
    final wind = real?['wind'];
    final warn = real?['warn'];
    final sunriseSunset = real?['sunriseSunset'];
    final predict = d['data']?['predict']?['detail'] as List? ?? [];
    final passed = d['data']?['passedchart'] as List? ?? [];
    final air = d['data']?['air'];

    double? todayHigh, todayLow;
    String condition = '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (predict.isNotEmpty) {
      // 夜间时段 NMC 首个条目是昨晚发布的（白天最高温缺失），跳过日期已过期的条目
      final valid = predict.where((e) =>
          (e['date']?.toString().replaceAll('/', '-') ?? '').compareTo(today) >= 0).toList();
      final first = valid.isNotEmpty ? valid.first : predict.first;
      todayHigh = _cleanNmcTemp(first['day']?['weather']?['temperature']?.toString());
      todayLow = _cleanNmcTemp(first['night']?['weather']?['temperature']?.toString());
      condition = _cleanNmcText(first['day']?['weather']?['info']?.toString());
    }
    // 今日最高温回退到实时温度
    todayHigh ??= _cleanNmcTemp(w?['temperature']?.toString());
    todayLow ??= _cleanNmcTemp(w?['temperature']?.toString());

    // 实时天气
    final realtimeCond = _cleanNmcText(w?['info']);
    if (condition.isEmpty) condition = realtimeCond;

    // 逐时（过去 24h 实况，按时间排序）
    final hourly = <HourlyItem>[];
    for (final p in passed) {
      final temp = _cleanNmcTemp(p['temperature']?.toString());
      if (temp != null) {
        hourly.add(HourlyItem(
          time: p['time']?.toString() ?? '',
          temperature: temp,
          condition: '',
          isForecast: false,
        ));
      }
    }
    hourly.sort((a, b) => a.time.compareTo(b.time));

    // 多日预报（跳过日期已过期的条目）
    final daily = <DailyItem>[];
    for (final d in predict) {
      final rowDate = d['date']?.toString().replaceAll('/', '-') ?? '';
      if (rowDate.isNotEmpty && rowDate.compareTo(today) < 0) continue;
      final dayText = _cleanNmcText(d['day']?['weather']?['info']?.toString());
      final nightText = _cleanNmcText(d['night']?['weather']?['info']?.toString());
      final high = _cleanNmcTemp(d['day']?['weather']?['temperature']?.toString());
      final low = _cleanNmcTemp(d['night']?['weather']?['temperature']?.toString());
      daily.add(DailyItem(
        date: d['date']?.toString().replaceAll('/', '-') ?? '',
        dayText: dayText,
        nightText: nightText,
        high: high,
        low: low,
      ));
    }

    // 昨日
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final yItems = hourly.where((h) => !h.time.startsWith(todayStr)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    YesterdayData? yesterday;
    if (yItems.isNotEmpty) {
      final temps = yItems.where((h) => h.temperature != null).map((h) => h.temperature!).toList();
      yesterday = YesterdayData(
        high: temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null,
        low: temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null,
        hourly: yItems,
      );
    }

    // 预警：alert 为空或 9999 视为无预警
    final alertRaw = warn?['alert']?.toString() ?? '';
    final warning = (alertRaw.isNotEmpty && alertRaw != '9999') ? alertRaw : '';

    return WeatherData(
      cityName: cityName,
      updatedAt: real?['publishTime']?.toString() ?? '',
      condition: condition,
      temperature: _cleanNmcTemp(w?['temperature']?.toString()) ?? 0,
      feelsLike: _cleanNmcTemp(w?['feelst']?.toString()),
      todayHigh: todayHigh,
      todayLow: todayLow,
      humidity: real?['weather']?['humidity']?.toInt(),
      windDirect: _cleanNmcText(wind?['direct']?.toString()),
      windPower: _cleanNmcText(wind?['power']?.toString()),
      aqi: air?['aqi']?.toInt(),
      aqiText: _cleanNmcText(air?['text']?.toString()),
      sunrise: (sunriseSunset?['sunrise']?.toString().length ?? 0) >= 16
          ? sunriseSunset!['sunrise'].toString().substring(11, 16)
          : '',
      sunset: (sunriseSunset?['sunset']?.toString().length ?? 0) >= 16
          ? sunriseSunset!['sunset'].toString().substring(11, 16)
          : '',
      sourceTag: '数据来源：中央气象台',
      warning: warning,
      hourlyLabel: '过去24小时逐时实况',
      hourly: hourly,
      daily: daily,
      yesterday: yesterday,
    );
  }

  String _windDir(double d) {
    const dirs = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    return dirs[((d + 22.5) / 45).floor() % 8];
  }

  String _beaufort(double s) {
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

  Future<void> _checkUpdate() async {
    try {
      final resp = await http
          .get(Uri.parse(
              'https://api.github.com/repos/upcyan/cyanweather/releases/latest'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final latest =
            (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
        if (latest.isNotEmpty && _isNewerVersion(latest, '1.2.2') && mounted) {
          _showUpdateDialog(json['tag_name'] ?? latest, json['body'] ?? '',
              json['html_url'] ?? '');
        }
      }
    } catch (_) {}
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> parse(String version) => version
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final l = parse(latest), c = parse(current);
    for (var i = 0; i < 3; i++) {
      final diff = (i < l.length ? l[i] : 0).compareTo(i < c.length ? c[i] : 0);
      if (diff != 0) return diff > 0;
    }
    return false;
  }

  void _showUpdateDialog(String version, String notes, String url) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('发现新版本 $version'),
              content: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('更新日志：',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16 * _fs)),
                    SizedBox(height: 8 * _fs),
                    Text(notes.isEmpty ? '暂无更新说明' : notes,
                        style: TextStyle(fontSize: 14 * _fs)),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('稍后')),
                TextButton(
                    onPressed: () {
                      _launchUrl(url);
                      Navigator.pop(context);
                    },
                    child: const Text('立即更新')),
              ],
            ));
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    // ignore: deprecated_member_use
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openSettings() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SettingsScreen(prefs: widget.prefs)));
    _loadPrefs();
    _armAutoRefresh();
    await _reloadLocation(requestPermission: true);
  }

  void _openCityPicker() async {
    final r = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CityPickerScreen()));
    if (r != null && r is Map) {
      if (r['useLocation'] == true) {
        // 对齐 native useCurrentLocation：恢复 GPS 自动定位
        await widget.prefs.setBool('useGps', true);
        await widget.prefs.setString('cityName', '');
        await widget.prefs.setString('cityCode', '');
        _loadPrefs();
        await _refreshLocation(requestPermission: true);
      } else {
        await widget.prefs.setString('cityName', r['name'] ?? '');
        await widget.prefs.setString('cityCode', r['code'] ?? '');
        await widget.prefs.setBool('useGps', false);
      }
      _loadPrefs();
      _loadWeather();
    }
  }

  @override
  Widget build(BuildContext context) {
    final city =
        _weather?.cityName ?? (_cityName.isNotEmpty ? _cityName : '晴暖天气');
    // 宽屏（平板/桌面窗口）内容限宽居中，对齐 native 的 560dp 规则
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 600;
    final contentW = isWide ? 560.0 : double.infinity;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(
            alignment: Alignment.topCenter,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _weatherGradient(_weather?.condition))),
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentW),
                child: Column(children: [
            // 顶栏：设置 | 城市名 + 更新时间（点击换城市） | 刷新
            // 真·沉浸：不用 SafeArea 包整个页面，顶栏自行避让状态栏，
            // 滚动内容底部内置小白条避让，可从透明条下方穿过
            Padding(
                padding: EdgeInsets.fromLTRB(4 * _fs,
                    MediaQuery.of(context).padding.top + 4 * _fs,
                    4 * _fs, 4 * _fs),
                child: Row(children: [
                  IconButton(
                      onPressed: _openSettings,
                      icon: Icon(Icons.settings,
                          size: 30 * _fs, color: const Color(0xFF333333))),
                  Expanded(
                      child: GestureDetector(
                          onTap: _openCityPicker,
                          behavior: HitTestBehavior.opaque,
                          child: Column(children: [
                            Text(city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 24 * _fs,
                                    fontWeight: FontWeight.bold)),
                            Text(_refreshing ? '更新中...' : (_weather?.updatedAt ?? ''),
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 12 * _fs,
                                    color: const Color(0xFF666666))),
                          ]))),
                  IconButton(
                      onPressed: _loadWeather,
                      icon: Icon(Icons.refresh,
                          size: 30 * _fs, color: const Color(0xFF333333))),
                ])),
            Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const SizedBox(
                                width: 56,
                                height: 56,
                                child:
                                    CircularProgressIndicator(strokeWidth: 5)),
                            SizedBox(height: 16 * _fs),
                            Text('正在获取天气...',
                                style: TextStyle(fontSize: 19 * _fs)),
                          ]))
                    : (_error != null && _weather == null)
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 24 * _fs),
                                    child: Text(_error!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 17 * _fs,
                                            color: Colors.red))),
                                SizedBox(height: 20 * _fs),
                                ElevatedButton(
                                    onPressed: _loadWeather,
                                    child: Text('重新获取',
                                        style:
                                            TextStyle(fontSize: 18 * _fs)))
                              ]))
                        : RefreshIndicator(
                            onRefresh: _loadWeather,
                            child: SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                // 底部小白条避让内置在滚动内容中：滚到底时末尾内容抬出小白条
                                padding: EdgeInsets.fromLTRB(
                                    16 * _fs,
                                    16 * _fs,
                                    16 * _fs,
                                    MediaQuery.of(context).padding.bottom +
                                        16 * _fs),
                                child: _weather == null
                                    ? const SizedBox.shrink()
                                    : _buildWeather(_weather!)))),
          ]),
        ),
        ),
        // 全屏刷新遮罩
        if (_refreshing && !_loading)
          Positioned.fill(
              child: Container(
                  color: const Color(0x99FFFFFF),
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                    const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(strokeWidth: 5)),
                    SizedBox(height: 14 * _fs),
                    Text('正在刷新天气...',
                        style: TextStyle(
                            fontSize: 17 * _fs,
                            color: const Color(0xFF333333))),
                  ])))),
      ]),
    );
  }

  Widget _buildWeather(WeatherData w) {
    final children = <Widget>[];

    // 定位提示卡
    if (_locationNotice != null)
      children.add(Card(
          color: const Color(0xFFFFF3CD),
          margin: EdgeInsets.only(bottom: 12 * _fs),
          child: Padding(
            padding: EdgeInsets.all(14 * _fs),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠ $_locationNotice',
                      style: TextStyle(
                          fontSize: 15 * _fs,
                          color: const Color(0xFF7A5600))),
                  if (_locationServiceDisabled)
                    Padding(
                        padding: EdgeInsets.only(top: 6 * _fs),
                        child: GestureDetector(
                            onTap: () async {
                              await Geolocator.openLocationSettings();
                            },
                            child: Text('去开启定位 ›',
                                style: TextStyle(
                                    fontSize: 15 * _fs,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0B6BCB))))),
                  if (_permissionDenied)
                    Padding(
                        padding: EdgeInsets.only(top: 6 * _fs),
                        child: GestureDetector(
                            onTap: () async {
                              await Geolocator.openAppSettings();
                            },
                            child: Text('去授权定位 ›',
                                style: TextStyle(
                                    fontSize: 15 * _fs,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0B6BCB))))),
                ]),
          )));

    // 预警横幅
    if (w.warning.isNotEmpty)
      children.add(Card(
          color: const Color(0xFFFFEBEE),
          margin: EdgeInsets.symmetric(vertical: 8 * _fs),
          child: Padding(
              padding: EdgeInsets.all(16 * _fs),
              child: Text('⚠ ${w.warning}',
                  style: TextStyle(
                      fontSize: 16 * _fs,
                      color: const Color(0xFFB71C1C),
                      fontWeight: FontWeight.w500)))));

    // 降雨提醒（可点击进入降雨趋势页；所有源可用，与 native 对齐）
    final tip = _rainReminder(w);
    if (tip != null)
      children.add(GestureDetector(
          onTap: _openRainForecast,
          child: Card(
              color: const Color(0xFFE3F2FD),
              margin: EdgeInsets.symmetric(vertical: 8 * _fs),
              child: Padding(
                  padding: EdgeInsets.all(16 * _fs),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 30 * _fs,
                              height: 30 * _fs,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF0B6BCB),
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('雨',
                                  style: TextStyle(
                                      fontSize: 15 * _fs,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white))),
                          SizedBox(width: 8 * _fs),
                          Expanded(
                              child: Text(tip,
                                  style: TextStyle(fontSize: 18 * _fs))),
                        ]),
                        SizedBox(height: 6 * _fs),
                        Text('查看降雨趋势 ›',
                            style: TextStyle(
                                fontSize: 15 * _fs,
                                color: const Color(0xFF0B6BCB))),
                      ])))));

    // 主天气：图标+天气现象在左，大温度在右（同 native，温度变化带淡入动画）
    children.add(Padding(
        padding: EdgeInsets.only(top: 14 * _fs, bottom: 10 * _fs),
        child: Column(children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(children: [
                  WeatherIcon(condition: w.condition, size: 72 * _fs),
                  SizedBox(height: 6 * _fs),
                  Text(w.condition,
                      style: TextStyle(
                          fontSize: 22 * _fs, fontWeight: FontWeight.w500)),
                ]),
                SizedBox(width: 20 * _fs),
                AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text('${w.temperature.round()}°',
                        key: ValueKey(w.temperature),
                        style: TextStyle(
                            fontSize: 52 * _fs,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111111)))),
              ]),
          SizedBox(height: 12 * _fs),
          Row(children: [
            Expanded(
                child: _statCol('最高', '${w.todayHigh?.round() ?? '-'}°',
                    const Color(0xFFC62828))),
            Expanded(
                child: _statCol('最低', '${w.todayLow?.round() ?? '-'}°',
                    const Color(0xFF1565C0))),
            if (w.feelsLike != null)
              Expanded(
                  child: _statCol('体感', '${w.feelsLike!.round()}°',
                      const Color(0xFF00897B))),
          ]),
        ])));

    // 日出日落
    if (w.sunrise.isNotEmpty || w.sunset.isNotEmpty)
      children.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * _fs),
          child: Row(children: [
            Expanded(child: _sunCol('日出', w.sunrise)),
            Expanded(child: _sunCol('日落', w.sunset)),
          ])));

    // 湿度 / 风力 / 空气质量 / 紫外线强度（对齐 native：空气质量含 PM 明细，风力含 m/s）
    children.add(_infoCard('湿度', '${w.humidity ?? '-'}%'));
    // 风向与风力分两行展示（_infoCard 文本 maxLines=3）
    final windText = StringBuffer(w.windDirect);
    if (w.windPower.isNotEmpty) windText.write('\n${w.windPower}');
    if (w.windSpeed != null)
      windText.write('（${w.windSpeed!.toStringAsFixed(1)}m/s）');
    children.add(_infoCard('风力', windText.toString()));
    final aqiLabel = StringBuffer();
    if (w.aqi != null) {
      aqiLabel.write('${w.aqiText.isEmpty ? _aqiText(w.aqi) : w.aqiText} ${w.aqi}');
    } else if (w.aqiText.isNotEmpty) {
      aqiLabel.write(w.aqiText);
    }
    children.add(_infoCardW(
        '空气质量',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (aqiLabel.isNotEmpty)
            _pill(aqiLabel.toString(), _aqiColor(w.aqi))
          else
            Text('-',
                style: TextStyle(
                    fontSize: 26 * _fs, fontWeight: FontWeight.w500)),
          if (w.pm25 != null)
            Padding(
                padding: EdgeInsets.only(top: 4 * _fs),
                child: Text('PM2.5: ${w.pm25!.round()}μg/m³',
                    style: TextStyle(
                        fontSize: 15 * _fs, color: const Color(0xFF666666)))),
          if (w.pm10 != null)
            Padding(
                padding: EdgeInsets.only(top: 2 * _fs),
                child: Text('PM10: ${w.pm10!.round()}μg/m³',
                    style: TextStyle(
                        fontSize: 15 * _fs, color: const Color(0xFF666666)))),
        ])));
    if (w.uvIndex.isNotEmpty) {
      children.add(_infoCardW(
          '紫外线强度', _pill(w.uvIndex, _uvColor(w.uvIndex))));
    }

    // 生活指数四宫格（对齐 native）
    double? nextRainProb;
    for (final h in w.hourly.where((h) => h.isForecast).take(12)) {
      if (h.rainProb != null && (nextRainProb == null || h.rainProb! > nextRainProb)) {
        nextRainProb = h.rainProb;
      }
    }
    children.add(_sectionTitle('生活指数'));
    children.add(Card(
        margin: EdgeInsets.only(bottom: 4 * _fs),
        child: Padding(
            padding: EdgeInsets.all(12 * _fs),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: _lifeTile('👔', '穿衣',
                        _clothingIndex(w.temperature, w.condition),
                        const Color(0xFF7E57C2))),
                SizedBox(width: 10 * _fs),
                Expanded(
                    child: _lifeTile('🏃', '运动',
                        _exerciseIndex(w.temperature, w.condition, w.aqi),
                        const Color(0xFF42A5F5))),
              ]),
              SizedBox(height: 10 * _fs),
              Row(children: [
                Expanded(
                    child: _lifeTile('🚗', '洗车',
                        _carwashIndex(w.condition, nextRainProb),
                        const Color(0xFF26A69A))),
                SizedBox(width: 10 * _fs),
                Expanded(
                    child: _lifeTile(
                        '🤧', '感冒', _coldIndex(w.todayHigh, w.todayLow),
                        const Color(0xFFEF5350))),
              ]),
            ]))));

    // 彩云分钟级降水
    if (w.minutelyText.isNotEmpty)
      children.add(Card(
          color: const Color(0xFFE3F2FD),
          margin: EdgeInsets.symmetric(vertical: 8 * _fs),
          child: Padding(
              padding: EdgeInsets.all(16 * _fs),
              child: Text(w.minutelyText,
                  style: TextStyle(fontSize: 17 * _fs)))));

    // 逐小时预报（native 规则：仅标签含"预报"时显示；气象局实况并入昨日卡片）
    if (w.hourlyLabel.contains('预报') && w.hourly.isNotEmpty) {
      children.add(_sectionTitle(w.hourlyLabel));
      children.add(SizedBox(
          height: 140 * _fs,
          child: _HourlyRow(
              items: w.hourly, fs: () => _fs, builder: (h) => _hourCard(h))));
    }

    // 多日预报
    if (w.daily.isNotEmpty) {
      children.add(_sectionTitle('未来多日预报（${w.daily.length}天）'));
      children.addAll(w.daily.map((d) => _dailyRow(d)));
    }

    // 昨日天气
    final y = w.yesterday;
    if (y != null) {
      children.add(_sectionTitle('昨日天气'));
      children.add(Card(
          margin: EdgeInsets.only(bottom: 8 * _fs),
          child: Padding(
              padding: EdgeInsets.all(14 * _fs),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text('昨日最高',
                          style: TextStyle(fontSize: 18 * _fs))),
                  Text('${y.high?.round() ?? '-'}°',
                      style: TextStyle(
                          fontSize: 22 * _fs,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC62828))),
                ]),
                SizedBox(height: 6 * _fs),
                Row(children: [
                  Expanded(
                      child: Text('昨日最低',
                          style: TextStyle(fontSize: 18 * _fs))),
                  Text('${y.low?.round() ?? '-'}°',
                      style: TextStyle(
                          fontSize: 22 * _fs,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0))),
                ]),
                if (y.hourly.isNotEmpty) ...[
                  SizedBox(height: 10 * _fs),
                  // 与逐时预报同高，卡片样式完全统一
                  SizedBox(
                      height: 140 * _fs,
                      child: _HourlyRow(
                          items: y.hourly,
                          fs: () => _fs,
                          builder: (h) => _hourCard(h))),
                ],
              ]))));
    } else if (w.sourceTag.contains('彩云')) {
      children.add(_sectionTitle('昨日天气'));
      children.add(Card(
          color: const Color(0xFFEEEEEE),
          child: Padding(
              padding: EdgeInsets.all(16 * _fs),
              child: Text('彩云天气暂不提供昨日天气数据',
                  style:
                      TextStyle(fontSize: 16 * _fs, color: const Color(0xFF666666))))));
    }

    // 数据来源（居中）+ 置信度（多源聚合时显示，对齐 native）
    children.add(Padding(
        padding: EdgeInsets.only(top: 16 * _fs),
        child: Text(w.sourceTag,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13 * _fs, color: const Color(0xFF666666)))));
    if (w.confidence > 0) {
      children.add(Padding(
          padding: EdgeInsets.only(top: 4 * _fs),
          child: Text('置信度：${(w.confidence * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13 * _fs,
                  color: w.confidence >= 0.8
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE65100)))));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  // 降雨提醒文案（对齐 native buildRainReminder）
  String? _rainReminder(WeatherData w) {
    final upcoming =
        w.hourly.where((h) => h.isForecast).take(12).toList();
    if (upcoming.isNotEmpty) {
      final idx = upcoming.indexWhere((h) =>
          h.condition.contains('雨') || h.condition.contains('雷'));
      if (idx >= 0) {
        return idx <= 1
            ? '现在或很快有降雨，出门请带伞'
            : '预计约 $idx 小时后可能有降雨，出门请带伞';
      }
      // 概率档：现象未报雨但概率显著时兜底
      final maxProb = upcoming
          .map((h) => h.rainProb ?? 0)
          .reduce((a, b) => a > b ? a : b);
      if (maxProb >= 60) {
        return '未来12小时降水概率最高达 $maxProb%，出门建议带伞';
      }
    }
    final soon = w.daily.take(3).any((d) {
      final t = d.dayText + d.nightText;
      return t.contains('雨') || t.contains('雷');
    });
    return soon ? '近期可能有雨，请留意天气变化' : null;
  }

  void _openRainForecast() {
    if (_weather == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RainForecastScreen(weather: _weather)));
  }

  Widget _sunCol(String label, String value) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 14 * _fs, color: const Color(0xFF666666))),
        SizedBox(height: 4 * _fs),
        Text(value.isEmpty ? '-' : value,
            style: TextStyle(
                fontSize: 20 * _fs, fontWeight: FontWeight.w600)),
      ]);

  Widget _infoCard(String title, String value) => Card(
      margin: EdgeInsets.symmetric(vertical: 4 * _fs),
      child: SizedBox(
          width: double.infinity,
          child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20 * _fs, vertical: 12 * _fs),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            TextStyle(fontSize: 17 * _fs, color: const Color(0xFF666666))),
                    SizedBox(height: 4 * _fs),
                    Text(value,
                        style: TextStyle(
                            fontSize: 24 * _fs, fontWeight: FontWeight.w500)),
                  ]))));

  Widget _statCol(String l, String v, Color c) => Column(children: [
        Text(l, style: TextStyle(fontSize: 15 * _fs, color: const Color(0xFF666666))),
        Text(v,
            style: TextStyle(
                fontSize: 26 * _fs, fontWeight: FontWeight.bold, color: c))
      ]);
  Widget _sectionTitle(String t) => Padding(
      padding: EdgeInsets.only(top: 20 * _fs, bottom: 8 * _fs),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(t,
              style:
                  TextStyle(fontSize: 20 * _fs, fontWeight: FontWeight.bold))));

  Widget _hourCard(HourlyItem h) {
    // 对齐 native HourCard：日期 + 时辰 + 图标 + 文本 + 温度 + 降水概率
    final datePart = h.time.length >= 10
        ? h.time.substring(5, 10).replaceAll('-', '/')
        : '';
    final hourPart = h.time.length >= 13
        ? '${int.tryParse(h.time.substring(11, 13)) ?? '?'}时'
        : h.time;
    return SizedBox(
        width: 92 * _fs,
        child: Card(
          child: Padding(
            padding:
                EdgeInsets.symmetric(vertical: 10 * _fs, horizontal: 6 * _fs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(datePart,
                    style: TextStyle(
                        fontSize: 12 * _fs,
                        color: const Color(0xFF666666))),
                Text(hourPart,
                    style: TextStyle(
                        fontSize: 13 * _fs,
                        color: const Color(0xFF666666))),
                SizedBox(height: 6 * _fs),
                WeatherIcon(condition: h.condition, size: 28 * _fs),
                if (h.condition.isNotEmpty) ...[
                  SizedBox(height: 4 * _fs),
                  Text(h.condition, style: TextStyle(fontSize: 13 * _fs)),
                ],
                SizedBox(height: 4 * _fs),
                Text('${h.temperature?.round() ?? '-'}°',
                    style: TextStyle(
                        fontSize: 16 * _fs,
                        fontWeight: FontWeight.bold)),
                if (h.rainProb != null && h.rainProb! > 0) ...[
                  SizedBox(height: 2 * _fs),
                  Text('💧${h.rainProb!.round()}%',
                      style: TextStyle(
                          fontSize: 11 * _fs,
                          color: const Color(0xFF1976D2))),
                ],
              ],
            ),
          ),
        ));
  }

  Widget _dailyRow(DailyItem d) {
    // 对齐 native DailyRow：今天/明天/后天 + 星期 + 白天转夜间
    return Card(
        margin: EdgeInsets.symmetric(vertical: 4 * _fs),
        child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 16 * _fs, vertical: 10 * _fs),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dayLabel(d.date),
                      style: TextStyle(
                          fontSize: 17 * _fs,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 4 * _fs),
                  Row(children: [
                    WeatherIcon(condition: d.dayText, size: 30 * _fs),
                    SizedBox(width: 10 * _fs),
                    Expanded(
                        child: Text(_combineDayNight(d.dayText, d.nightText),
                            style: TextStyle(fontSize: 17 * _fs))),
                    Text('${d.high?.round() ?? '-'}°',
                        style: TextStyle(
                            fontSize: 19 * _fs,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC62828))),
                    Text('/',
                        style: TextStyle(
                            fontSize: 19 * _fs,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF666666))),
                    Text('${d.low?.round() ?? '-'}°',
                        style: TextStyle(
                            fontSize: 19 * _fs,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0))),
                  ]),
                ])));
  }

  static String _aqiText(int? aqi) {
    if (aqi == null) return '-';
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    if (aqi <= 300) return '重度污染';
    return '严重污染';
  }

  static String _dayLabel(String date) {
    try {
      final clean = date.contains('T') ? date.substring(0, 10) : date;
      final d = DateTime.parse(clean.replaceAll('/', '-'));
      final today = DateTime.now();
      final t0 = DateTime(today.year, today.month, today.day);
      final diff = d.difference(t0).inDays;
      const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final md = '${d.month}月${d.day}日 ${wd[d.weekday - 1]}';
      if (diff == 0) return '今天 $md';
      if (diff == 1) return '明天 $md';
      if (diff == 2) return '后天 $md';
      return md;
    } catch (_) {
      return date;
    }
  }

  // ---- 生活指数（对齐 native WeatherIndex.kt）----
  static String _clothingIndex(double? temp, String condition) {
    final t = temp;
    if (t == null) return '-';
    if (t >= 35) return '酷热\n穿透气薄衣';
    if (t >= 30) return '炎热\n短袖短裤';
    if (t >= 25) return '温暖\n轻薄长袖';
    if (t >= 20) return '舒适\n长袖薄外套';
    if (t >= 15) return '微凉\n夹克毛衣';
    if (t >= 10) return '凉爽\n厚外套';
    if (t >= 5) return '寒冷\n棉衣羽绒';
    if (t >= 0) return '很冷\n厚羽绒保暖';
    return '极寒\n防寒服加厚';
  }

  static String _exerciseIndex(double? temp, String condition, int? aqi) {
    final t = temp;
    if (t == null) return '-';
    final badWeather = condition.contains('雨') ||
        condition.contains('雪') ||
        condition.contains('雾') ||
        condition.contains('霾');
    if (badWeather) return '不宜\n天气不佳';
    if (aqi != null && aqi > 150) return '不宜\n空气质量差';
    if (t >= 35) return '不宜\n高温炎热';
    if (t >= 30) return '较不宜\n偏热';
    if (t >= 15 && t <= 28) return '适宜\n温度舒适';
    if (t >= 10) return '较适宜\n注意保暖';
    return '较不宜\n温度偏低';
  }

  static String _carwashIndex(String condition, double? rainProb) {
    final hasRain = condition.contains('雨') ||
        condition.contains('雪') ||
        (rainProb != null && rainProb > 50);
    return hasRain ? '不宜\n有降水' : '适宜\n近期无雨';
  }

  static String _coldIndex(double? high, double? low) {
    if (high == null || low == null) return '-';
    final diff = high - low;
    if (diff >= 12) return '易发\n温差大，注意增减衣物';
    if (diff >= 8) return '较易发\n温差较大';
    if (diff >= 5) return '少发\n温差适中';
    return '不易发\n温差小';
  }

  Widget _lifeTile(String icon, String title, String text, Color color) {
    final parts = text.split('\n');
    return Container(
        padding:
            EdgeInsets.symmetric(horizontal: 12 * _fs, vertical: 10 * _fs),
        decoration: BoxDecoration(
            color: const Color(0xFFE3EDF9),
            borderRadius: BorderRadius.circular(12 * _fs)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 26 * _fs,
                    height: 26 * _fs,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(title.substring(0, 1),
                        style: TextStyle(
                            fontSize: 13 * _fs,
                            fontWeight: FontWeight.bold,
                            color: Colors.white))),
                SizedBox(width: 6 * _fs),
                Text(title,
                    style: TextStyle(
                        fontSize: 15 * _fs,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF555555))),
              ]),
              SizedBox(height: 5 * _fs),
              Text(parts.first,
                  style: TextStyle(
                      fontSize: 17 * _fs, fontWeight: FontWeight.w500)),
              if (parts.length > 1)
                Text(parts[1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13 * _fs,
                        color: const Color(0xFF666666))),
            ]));
  }
}

/// 逐时列表 + 左右滚动圆形箭头（对齐 native HourlyRow：无渐变遮罩）
class _HourlyRow extends StatefulWidget {
  final List<HourlyItem> items;
  final double Function() fs;
  final Widget Function(HourlyItem item) builder;
  const _HourlyRow(
      {required this.items, required this.fs, required this.builder});
  @override
  State<_HourlyRow> createState() => _HourlyRowState();
}

class _HourlyRowState extends State<_HourlyRow> {
  final ScrollController _ctrl = ScrollController();
  bool _canPrev = false;
  bool _canNext = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(covariant _HourlyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_updateArrows);
    _ctrl.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_ctrl.hasClients) return;
    final canPrev = _ctrl.offset > 2;
    final canNext = _ctrl.offset < _ctrl.position.maxScrollExtent - 2;
    if (canPrev != _canPrev || canNext != _canNext) {
      setState(() {
        _canPrev = canPrev;
        _canNext = canNext;
      });
    }
  }

  void _scroll(bool forward) {
    if (!_ctrl.hasClients) return;
    final target = _ctrl.offset + (forward ? 240.0 : -240.0);
    _ctrl.animateTo(
        target.clamp(0.0, _ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  Widget _arrowBtn(IconData icon, bool forward) => Positioned(
      left: forward ? null : 0,
      right: forward ? 0 : null,
      top: 0,
      bottom: 0,
      child: Center(
          child: GestureDetector(
              onTap: () => _scroll(forward),
              child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.95),
                      shape: BoxShape.circle),
                  child: Icon(icon,
                      size: 26, color: const Color(0xFF0B6BCB))))));

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ListView.separated(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          itemCount: widget.items.length,
          separatorBuilder: (_, __) => SizedBox(width: 8 * widget.fs()),
          itemBuilder: (_, i) => widget.builder(widget.items[i])),
      if (_canPrev) _arrowBtn(Icons.keyboard_arrow_left, false),
      if (_canNext) _arrowBtn(Icons.keyboard_arrow_right, true),
    ]);
  }
}

/// 页面背景渐变：按天气与昼夜取柔和浅色（对齐 native weatherBgBrush）
List<Color> _weatherGradient(String? condition) {
  final c = condition ?? '';
  final hour = DateTime.now().hour;
  final isDay = hour >= 6 && hour <= 18;
  if (c.contains('雨') || c.contains('雷')) {
    return const [Color(0xFFE9EFF7), Color(0xFFD8E4F1)];
  }
  if (c.contains('雪')) return const [Color(0xFFF2F7FC), Color(0xFFE4EDF6)];
  if (c.contains('雾') || c.contains('霾')) {
    return const [Color(0xFFF0F2F5), Color(0xFFE3E8EE)];
  }
  if (!isDay) return const [Color(0xFFEEF1F7), Color(0xFFE1E7F1)];
  if (c.contains('晴')) return const [Color(0xFFFFF6DF), Color(0xFFE2EFFB)];
  if (c.contains('多云') || c.contains('阴')) {
    return const [Color(0xFFF7FAFF), Color(0xFFE4EEF9)];
  }
  return const [Color(0xFFF5F9FF), Color(0xFFE4EEF9)];
}

Color _aqiColor(int? aqi) {
  if (aqi == null) return const Color(0xFF827717);
  if (aqi <= 50) return const Color(0xFF2E7D32);
  if (aqi <= 100) return const Color(0xFF827717);
  if (aqi <= 150) return const Color(0xFFE65100);
  if (aqi <= 200) return const Color(0xFFBF360C);
  if (aqi <= 300) return const Color(0xFFC62828);
  return const Color(0xFFB71C1C);
}

Color _uvColor(String uvText) {
  final v = int.tryParse(RegExp(r'\d+').firstMatch(uvText)?.group(0) ?? '');
  if (v == null) {
    return uvText.contains('弱')
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);
  }
  if (v <= 2) return const Color(0xFF2E7D32);
  if (v <= 5) return const Color(0xFF827717);
  if (v <= 7) return const Color(0xFFE65100);
  if (v <= 10) return const Color(0xFFBF360C);
  return const Color(0xFFB71C1C);
}

Widget _pill(String text, Color color) => Container(
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(50)),
    child: Text(text,
        style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w500, color: color)));

Widget _infoCardW(String title, Widget value) => SizedBox(
    width: double.infinity,
    child: Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 17, color: const Color(0xFF666666))),
                  SizedBox(height: 4),
                  value,
                ]))));
