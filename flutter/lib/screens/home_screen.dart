import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/weather_model.dart';
import '../services/api_service.dart';
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
  String _source = 'nmc';
  String _cityName = '';
  String _cityCode = '';
  double _lat = 39.9042, _lng = 116.4074;
  String _caiyunToken = '';
  String _fontSize = 'large';
  bool _useGps = true;
  String? _locationNotice;
  bool _locationServiceDisabled = false;
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
    // 先用已保存的坐标/城市立即出天气；随后定位精化再刷新一次
    await _loadWeather();
    unawaited(_checkUpdate());
    await _refreshLocation(requestPermission: true);
    if (!mounted) return;
    await _loadWeather();
  }

  void _loadPrefs() {
    _source = widget.prefs.getString('source') ?? 'nmc';
    _cityName = widget.prefs.getString('cityName') ?? '';
    _cityCode = widget.prefs.getString('cityCode') ?? '';
    _lat = widget.prefs.getDouble('lat') ?? 39.9042;
    _lng = widget.prefs.getDouble('lng') ?? 116.4074;
    _fontSize = widget.prefs.getString('fontSize') ?? 'large';
    _caiyunToken = widget.prefs.getString('caiyunToken') ?? '';
    _useGps = widget.prefs.getBool('useGps') ?? true;
  }

  Future<void> _refreshLocation({required bool requestPermission}) async {
    if (!_useGps) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted)
        setState(() {
          _locationNotice = '定位服务未开启，当前显示默认城市北京';
          _locationServiceDisabled = true;
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
        });
      return;
    }
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      if (mounted)
        setState(() {
          _locationNotice = '定位失败，请检查网络/GPS后重试；当前显示默认城市北京';
          _locationServiceDisabled = false;
        });
      return;
    }
    final pos = position!;
    await widget.prefs.setDouble('lat', pos.latitude);
    await widget.prefs.setDouble('lng', pos.longitude);
    await widget.prefs.setString('cityName', '');
    await widget.prefs.setString('cityCode', '');
    if (mounted)
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _cityName = '';
        _cityCode = '';
        _locationNotice = null;
        _locationServiceDisabled = false;
      });
    // NMC 源且使用 GPS：自动解析城市代码
    if (_source == 'nmc' && _useGps) {
      await _resolveNmcCity(pos.latitude, pos.longitude);
    }
  }

  Future<void> _reloadLocation({bool requestPermission = true}) async {
    await _refreshLocation(requestPermission: requestPermission);
    if (mounted) await _loadWeather();
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
      if (_source == 'caiyun' && _caiyunToken.isNotEmpty) {
        final data = await ApiService.fetchCaiyunV1(_caiyunToken, _lat, _lng);
        w = _parseCaiyun(data, _cityName);
      } else if (_source == 'nmc') {
        // 无站点编码时先按定位解析最近气象站（对齐 native 行为）
        if (_cityCode.isEmpty) {
          try {
            await _resolveNmcCity(_lat, _lng);
          } catch (_) {}
        }
        if (_cityCode.isNotEmpty) {
          final data = await ApiService.fetchNmcWeather(_cityCode);
          w = _parseNmc(data, _cityName);
        } else {
          // 站点解析失败时回退 Open-Meteo，保证应用可用
          w = await ApiService.fetchWeather(_lat, _lng);
        }
      } else {
        w = await ApiService.fetchWeather(_lat, _lng);
        try {
          final g = await ApiService.reverseGeocode(_lat, _lng);
          if (g.isNotEmpty)
            w = WeatherData(
                cityName: _simp(g),
                condition: w.condition,
                temperature: w.temperature,
                feelsLike: w.feelsLike,
                todayHigh: w.todayHigh,
                todayLow: w.todayLow,
                humidity: w.humidity,
                windDirect: w.windDirect,
                windPower: w.windPower,
                sunrise: w.sunrise,
                sunset: w.sunset,
                uvIndex: w.uvIndex,
                minutelyText: w.minutelyText,
                sourceTag: w.sourceTag,
                warning: w.warning,
                updatedAt: w.updatedAt,
                hourlyLabel: w.hourlyLabel,
                yesterday: w.yesterday,
                hourly: w.hourly,
                daily: w.daily);
        } catch (_) {}
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
    if (predict.isNotEmpty) {
      final first = predict[0];
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

    // 多日预报
    final daily = <DailyItem>[];
    for (final d in predict) {
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
        if (latest.isNotEmpty && _isNewerVersion(latest, '1.1.0') && mounted) {
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
      await widget.prefs.setString('cityName', r['name'] ?? '');
      await widget.prefs.setString('cityCode', r['code'] ?? '');
      await widget.prefs.setDouble('lat', r['lat'] ?? 39.9042);
      await widget.prefs.setDouble('lng', r['lng'] ?? 116.4074);
      await widget.prefs.setBool('useGps', false);
      _loadPrefs();
      _loadWeather();
    }
  }

  @override
  Widget build(BuildContext context) {
    final city =
        _weather?.cityName ?? (_cityName.isNotEmpty ? _cityName : '晴暖天气');
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Column(children: [
            // 顶栏：设置 | 城市名 + 更新时间（点击换城市） | 刷新
            Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 4 * _fs, vertical: 4 * _fs),
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
                                padding: EdgeInsets.all(16 * _fs),
                                child: _weather == null
                                    ? const SizedBox.shrink()
                                    : _buildWeather(_weather!)))),
          ]),
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

    // 降雨提醒（可点击进入降雨趋势页；气象局数据源不支持）
    final tip = _rainReminder(w);
    if (tip != null && !w.sourceTag.contains('中央气象台'))
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
                        Text('🌂 $tip',
                            style: TextStyle(fontSize: 18 * _fs)),
                        SizedBox(height: 6 * _fs),
                        Text('查看降雨趋势 ›',
                            style: TextStyle(
                                fontSize: 15 * _fs,
                                color: const Color(0xFF0B6BCB))),
                      ])))));

    // 主天气：图标+天气现象在左，大温度在右（同 native）
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
                Text('${w.temperature.round()}°',
                    style: TextStyle(
                        fontSize: 52 * _fs,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111111))),
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

    // 湿度 / 风力 / 空气质量 / 紫外线强度
    children.add(_infoCard('湿度', '${w.humidity ?? '-'}%'));
    children.add(_infoCard('风力', '${w.windDirect} ${w.windPower}'.trim()));
    children.add(_infoCard(
        '空气质量', w.aqi != null ? '${w.aqiText} ${w.aqi}' : '-'));
    if (w.uvIndex.isNotEmpty) children.add(_infoCard('紫外线强度', w.uvIndex));

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
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: w.hourly.length,
              separatorBuilder: (_, __) => SizedBox(width: 8 * _fs),
              itemBuilder: (_, i) => _hourCard(w.hourly[i]))));
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
                  SizedBox(
                      height: 120 * _fs,
                      child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: y.hourly.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: 8 * _fs),
                          itemBuilder: (_, i) => _hourCard(y.hourly[i]))),
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
                      TextStyle(fontSize: 16 * _fs, color: Colors.grey)))));
    }

    // 数据来源（居中）
    children.add(Padding(
        padding: EdgeInsets.only(top: 16 * _fs),
        child: Text(w.sourceTag,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13 * _fs, color: Colors.grey))));

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
                            TextStyle(fontSize: 17 * _fs, color: Colors.grey)),
                    SizedBox(height: 4 * _fs),
                    Text(value,
                        style: TextStyle(
                            fontSize: 24 * _fs, fontWeight: FontWeight.w500)),
                  ]))));

  Widget _statCol(String l, String v, Color c) => Column(children: [
        Text(l, style: TextStyle(fontSize: 15 * _fs, color: Colors.grey)),
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
    return SizedBox(
        width: 76 * _fs,
        child: Card(
          child: Padding(
            padding:
                EdgeInsets.symmetric(vertical: 8 * _fs, horizontal: 6 * _fs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${h.time.substring(11, 13)}时',
                    style: TextStyle(fontSize: 13 * _fs, color: Colors.grey)),
                SizedBox(height: 4 * _fs),
                WeatherIcon(condition: h.condition, size: 26 * _fs),
                SizedBox(height: 4 * _fs),
                Text('${h.temperature?.round() ?? '-'}°',
                    style: TextStyle(
                        fontSize: 14 * _fs, fontWeight: FontWeight.bold)),
                Text(h.condition,
                    style: TextStyle(fontSize: 11 * _fs),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ));
  }

  Widget _dailyRow(DailyItem d) => Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * _fs),
      child: Row(children: [
        SizedBox(
            width: 80 * _fs,
            child: Text(d.date.substring(5),
                style: TextStyle(fontSize: 15 * _fs))),
        WeatherIcon(condition: d.dayText, size: 24 * _fs),
        SizedBox(width: 8 * _fs),
        Expanded(
            child: Text(d.dayText,
                style: TextStyle(fontSize: 15 * _fs),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
        Text('${d.high?.round() ?? '-'}°/',
            style: TextStyle(
                fontSize: 16 * _fs,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFC62828))),
        Text('${d.low?.round() ?? '-'}°',
            style: TextStyle(
                fontSize: 16 * _fs,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1565C0))),
      ]));
}
