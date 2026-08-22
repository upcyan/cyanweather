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

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const HomeScreen({super.key, required this.prefs});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  WeatherData? _weather;
  bool _loading = true;
  String? _error;
  String _source = 'openmeteo';
  String _cityName = '';
  String _cityCode = '';
  double _lat = 39.9042, _lng = 116.4074;
  String _caiyunToken = '';
  String _fontSize = 'xlarge';
  bool _useGps = true;
  String? _locationNotice;
  bool _locationServiceDisabled = false;
  double get _fs =>
      {'standard': 1.0, 'large': 1.3, 'xlarge': 1.6}[_fontSize] ?? 1.3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _useGps) {
      unawaited(_reloadLocation(requestPermission: false));
    }
  }

  Future<void> _initialize() async {
    await _refreshLocation(requestPermission: true);
    if (!mounted) return;
    await _loadWeather();
    unawaited(_checkUpdate());
  }

  void _loadPrefs() {
    _source = widget.prefs.getString('source') ?? 'openmeteo';
    _cityName = widget.prefs.getString('cityName') ?? '';
    _cityCode = widget.prefs.getString('cityCode') ?? '';
    _lat = widget.prefs.getDouble('lat') ?? 39.9042;
    _lng = widget.prefs.getDouble('lng') ?? 116.4074;
    _fontSize = widget.prefs.getString('fontSize') ?? 'xlarge';
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
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await widget.prefs.setDouble('lat', position.latitude);
      await widget.prefs.setDouble('lng', position.longitude);
      await widget.prefs.setString('cityName', '');
      await widget.prefs.setString('cityCode', '');
      if (mounted)
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _cityName = '';
          _cityCode = '';
          _locationNotice = null;
          _locationServiceDisabled = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _locationNotice = '定位失败，请检查网络/GPS后重试；当前显示默认城市北京';
          _locationServiceDisabled = false;
        });
    }
  }

  Future<void> _reloadLocation({bool requestPermission = true}) async {
    await _refreshLocation(requestPermission: requestPermission);
    if (mounted) await _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      WeatherData w;
      if (_source == 'caiyun' && _caiyunToken.isNotEmpty) {
        final data = await ApiService.fetchCaiyunV1(_caiyunToken, _lat, _lng);
        w = _parseCaiyun(data, _cityName);
      } else if (_source == 'nmc' && _cityCode.isNotEmpty) {
        final data = await ApiService.fetchNmcWeather(_cityCode);
        w = _parseNmc(data, _cityName);
      } else {
        w = await ApiService.fetchWeather(_lat, _lng);
        try {
          final g = await ApiService.reverseGeocode(_lat, _lng);
          if (g.isNotEmpty)
            w = WeatherData(
                cityName: g,
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
                hourly: w.hourly,
                daily: w.daily);
        } catch (_) {}
      }
      setState(() {
        _weather = w;
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup')
          ? '无法连接网络，请检查Wi-Fi或移动数据是否开启'
          : e.toString().contains('timeout')
              ? '网络请求超时，请稍后重试'
              : e.toString();
      setState(() {
        _error = msg;
        _loading = false;
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
    );
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
    final predict = d['data']?['predict']?['detail'] as List? ?? [];
    double? high, low;
    String condition = '';
    if (predict.isNotEmpty) {
      final first = predict[0];
      high = double.tryParse(
          first['day']?['weather']?['temperature']?.toString() ?? '');
      low = double.tryParse(
          first['night']?['weather']?['temperature']?.toString() ?? '');
      condition = first['day']?['weather']?['info']?.toString() ?? '';
    }
    return WeatherData(
      cityName: cityName,
      condition: condition,
      temperature: double.tryParse(w?['temperature']?.toString() ?? '') ?? 0,
      todayHigh: high,
      todayLow: low,
      humidity: real?['weather']?['humidity']?.toInt(),
      windDirect: _windDir(wind?['direction'] ?? 0),
      windPower: _beaufort(wind?['speed'] ?? 0),
      sunrise: d['data']?['real']?['weather']?['sunrise'] ?? '',
      sunset: d['data']?['real']?['weather']?['sunset'] ?? '',
      sourceTag: '数据来源：中央气象台',
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
        if (latest.isNotEmpty && _isNewerVersion(latest, '1.0.0') && mounted) {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: _openSettings, icon: const Icon(Icons.settings)),
        title: Text(
            _weather?.cityName ?? (_cityName.isNotEmpty ? _cityName : '晴暖天气')),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: _openCityPicker,
              icon: const Icon(Icons.location_city)),
          IconButton(onPressed: _loadWeather, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16 * _fs),
                      Text(_error!,
                          style: TextStyle(
                              fontSize: 16 * _fs, color: Colors.grey)),
                      SizedBox(height: 16 * _fs),
                      ElevatedButton.icon(
                          onPressed: _loadWeather,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'))
                    ]))
              : _buildWeather(),
    );
  }

  Widget _buildWeather() {
    final w = _weather!;
    return RefreshIndicator(
        onRefresh: _loadWeather,
        child: SingleChildScrollView(
            padding: EdgeInsets.all(16 * _fs),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_locationNotice != null)
                    Card(
                        color: const Color(0xFFFFF3E0),
                        margin: EdgeInsets.only(bottom: 12 * _fs),
                        child: Padding(
                          padding: EdgeInsets.all(12 * _fs),
                          child: Row(children: [
                            Expanded(
                                child: Text(_locationNotice!,
                                    style: TextStyle(fontSize: 15 * _fs))),
                            TextButton(
                              onPressed: _locationServiceDisabled
                                  ? () async {
                                      await Geolocator.openLocationSettings();
                                    }
                                  : () =>
                                      _reloadLocation(requestPermission: true),
                              child: Text(
                                  _locationServiceDisabled ? '去开启定位' : '重新授权'),
                            ),
                          ]),
                        )),
                  if (w.hourly
                      .any((h) => h.rainProb != null && h.rainProb! > 50))
                    Card(
                        color: const Color(0xFFE3F2FD),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                            padding: EdgeInsets.all(12 * _fs),
                            child: Row(children: [
                              Text('🌂', style: TextStyle(fontSize: 20 * _fs)),
                              SizedBox(width: 8 * _fs),
                              Expanded(
                                  child: Text('近期可能有雨，请留意天气变化',
                                      style: TextStyle(fontSize: 17 * _fs)))
                            ]))),
                  WeatherIcon(condition: w.condition, size: 80 * _fs),
                  SizedBox(height: 8 * _fs),
                  Text('${w.temperature.round()}°',
                      style: TextStyle(
                          fontSize: 60 * _fs, fontWeight: FontWeight.bold)),
                  Text(w.condition, style: TextStyle(fontSize: 24 * _fs)),
                  SizedBox(height: 14 * _fs),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCol('最高', '${w.todayHigh?.round() ?? '-'}°',
                            const Color(0xFFC62828)),
                        _statCol('最低', '${w.todayLow?.round() ?? '-'}°',
                            const Color(0xFF1565C0))
                      ]),
                  if (w.feelsLike != null)
                    Padding(
                        padding: EdgeInsets.only(top: 8 * _fs),
                        child: Text('体感温度 ${w.feelsLike!.round()}°',
                            style: TextStyle(
                                fontSize: 18 * _fs, color: Colors.grey))),
                  SizedBox(height: 14 * _fs),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCol('日出', w.sunrise, Colors.orange),
                        _statCol('日落', w.sunset, Colors.indigo)
                      ]),
                  SizedBox(height: 8 * _fs),
                  // InfoCards: 湿度/风力/AQI/紫外线
                  _infoCard('湿度', '${w.humidity ?? '-'}%'),
                  _infoCard('风力', '${w.windDirect} ${w.windPower}'.trim()),
                  _infoCard(
                      '空气质量', w.aqi != null ? '${w.aqiText} ${w.aqi}' : '-'),
                  if (w.uvIndex.isNotEmpty) _infoCard('紫外线强度', w.uvIndex),
                  // 分钟级降水提示
                  if (w.minutelyText.isNotEmpty)
                    Card(
                        color: const Color(0xFFE3F2FD),
                        margin: EdgeInsets.only(top: 8 * _fs),
                        child: Padding(
                            padding: EdgeInsets.all(12 * _fs),
                            child: Text(w.minutelyText,
                                style: TextStyle(fontSize: 17 * _fs)))),
                  if (w.hourly.isNotEmpty) ...[
                    _sectionTitle('逐时预报'),
                    SizedBox(
                        height: 140 * _fs,
                        child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: w.hourly.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(width: 8 * _fs),
                            itemBuilder: (_, i) => _hourCard(w.hourly[i])))
                  ],
                  if (w.daily.isNotEmpty) ...[
                    _sectionTitle('多日预报（${w.daily.length}天）'),
                    ...w.daily.map((d) => _dailyRow(d))
                  ],
                  Padding(
                      padding: EdgeInsets.only(top: 16 * _fs),
                      child: Text(w.sourceTag,
                          style: TextStyle(
                              fontSize: 14 * _fs, color: Colors.grey))),
                ])));
  }

  Widget _infoCard(String title, String value) => Card(
      margin: EdgeInsets.symmetric(vertical: 4 * _fs),
      child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 20 * _fs, vertical: 12 * _fs),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 17 * _fs, color: Colors.grey)),
            SizedBox(height: 4 * _fs),
            Text(value,
                style:
                    TextStyle(fontSize: 24 * _fs, fontWeight: FontWeight.w500)),
          ])));

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
