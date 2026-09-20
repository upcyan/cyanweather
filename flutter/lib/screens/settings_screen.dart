import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsScreen({super.key, required this.prefs});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _source = 'openmeteo';
  List<String> _weatherSources = ['nmc', 'openmeteo'];
  String _fontSize = 'large';
  String _refreshInterval = '30';
  bool _autoCheckUpdate = true;
  bool _useGps = true;
  String _caiyunToken = '';
  String _caiyunMode = 'none';
  String _qweatherHost = '';
  String _qweatherKey = '';

  static const _allSources = [
    ('nmc', '中国气象局', '官方国内数据，支持县区级与昨日天气'),
    ('openmeteo', 'Open-Meteo', '免费无密钥，15天预报与全球覆盖'),
    ('caiyun', '彩云天气', '分钟级降水，需凭证'),
    ('qweather', '和风天气', '需 API Host 与 Key'),
  ];

  @override
  void initState() {
    super.initState();
    _source = widget.prefs.getString('source') ?? 'openmeteo';
    final rawSources = widget.prefs.getString('weatherSources');
    if (rawSources != null && rawSources.isNotEmpty) {
      try {
        final list = (jsonDecode(rawSources) as List)
            .map((e) => e.toString())
            .where((s) => _allSources.any((a) => a.$1 == s))
            .toList();
        _weatherSources = list;
      } catch (_) {}
    } else if (widget.prefs.getString('source') != null) {
      _weatherSources = [_source];
    }
    _fontSize = widget.prefs.getString('fontSize') ?? 'large';
    _refreshInterval = widget.prefs.getString('refreshInterval') ?? '30';
    _autoCheckUpdate = widget.prefs.getBool('autoCheckUpdate') ?? true;
    _useGps = widget.prefs.getBool('useGps') ?? true;
    _caiyunToken = widget.prefs.getString('caiyunToken') ?? '';
    _caiyunMode = widget.prefs.getString('caiyunMode') ?? 'none';
    _qweatherHost = widget.prefs.getString('qweatherHost') ?? '';
    _qweatherKey = widget.prefs.getString('qweatherKey') ?? '';
  }

  Future<void> _toggleSource(String id) async {
    setState(() {
      if (_weatherSources.contains(id)) {
        _weatherSources = _weatherSources.where((s) => s != id).toList();
      } else {
        _weatherSources = [..._weatherSources, id];
      }
    });
    await widget.prefs.setString(
        'weatherSources', jsonEncode(_weatherSources));
    // 兼容旧版本：把第一优先源同步进单选键
    if (_weatherSources.isNotEmpty) {
      await widget.prefs.setString('source', _weatherSources.first);
      _source = _weatherSources.first;
    }
  }

  Future<void> _save(String key, dynamic value) async {
    if (value is String) {
      await widget.prefs.setString(key, value);
      setState(() {
        switch (key) {
          case 'source': _source = value; break;
          case 'fontSize': _fontSize = value; break;
          case 'refreshInterval': _refreshInterval = value; break;
          case 'caiyunToken': _caiyunToken = value; break;
          case 'caiyunMode': _caiyunMode = value; break;
          case 'qweatherHost': _qweatherHost = value; break;
          case 'qweatherKey': _qweatherKey = value; break;
        }
      });
    } else if (value is bool) {
      await widget.prefs.setBool(key, value);
      setState(() {
        switch (key) {
          case 'autoCheckUpdate': _autoCheckUpdate = value; break;
          case 'useGps': _useGps = value; break;
        }
      });
    }
  }

  double get _fontScale =>
      {'standard': 1.0, 'large': 1.3, 'xlarge': 1.6}[_fontSize] ?? 1.3;

  @override
  Widget build(BuildContext context) {
    // 设置页自身也随字体大小挡位缩放（对齐 native）
    return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_fontScale)),
        child: Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('天气数据源（可多选，选多个即智能聚合）'),
        ..._allSources.map((s) => _checkboxTile(
            s.$2, s.$3, _weatherSources.contains(s.$1),
            () => _toggleSource(s.$1))),
        if (_weatherSources.contains('caiyun')) ...[
          const SizedBox(height: 8),
          _sectionTitle('彩云接入方式'),
          _radioTile('V1 Token', '免费版，3天预报，Token 在 URL 中', _caiyunMode == 'v1',
              () => _save('caiyunMode', 'v1')),
          if (_caiyunMode == 'v1') ...[
            const SizedBox(height: 8),
            TextField(
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                    hintText: '填写 V1 Token', border: OutlineInputBorder()),
                controller: TextEditingController(text: _caiyunToken),
                onChanged: (v) => _save('caiyunToken', v.trim())),
            const SizedBox(height: 8),
            Text('在 dashboard.caiyunapp.com 注册获取；免费版仅 3 天预报与 48 小时逐时。',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ],
        if (_weatherSources.contains('qweather')) ...[
          const SizedBox(height: 8),
          _sectionTitle('和风天气凭证'),
          TextField(
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                  hintText: 'API Host（如 devapi.qweather.com）',
                  border: OutlineInputBorder()),
              controller: TextEditingController(text: _qweatherHost),
              onChanged: (v) => _save('qweatherHost', v.trim())),
          const SizedBox(height: 8),
          TextField(
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                  hintText: 'API Key', border: OutlineInputBorder()),
              controller: TextEditingController(text: _qweatherKey),
              onChanged: (v) => _save('qweatherKey', v.trim())),
        ],
        Text('凭证未填写完整的源会自动跳过；多选时各字段按源权重智能聚合',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        _sectionTitle('字体大小'),
        _radioTile('标准', '', _fontSize == 'standard',
            () => _save('fontSize', 'standard')),
        _radioTile(
            '大', '', _fontSize == 'large', () => _save('fontSize', 'large'),
            badge: '推荐'),
        _radioTile(
            '特大', '', _fontSize == 'xlarge', () => _save('fontSize', 'xlarge')),
        const SizedBox(height: 16),
        _sectionTitle('自动刷新'),
        _radioTile('关闭', '', _refreshInterval == 'off',
            () => _save('refreshInterval', 'off')),
        _radioTile('每次进入App', '', _refreshInterval == 'on_resume',
            () => _save('refreshInterval', 'on_resume')),
        _radioTile('每 10 分钟', '', _refreshInterval == '10',
            () => _save('refreshInterval', '10')),
        _radioTile('每 30 分钟', '', _refreshInterval == '30',
            () => _save('refreshInterval', '30'),
            badge: '推荐'),
        _radioTile('每 60 分钟', '', _refreshInterval == '60',
            () => _save('refreshInterval', '60')),
        _radioTile('每 6 小时', '', _refreshInterval == '360',
            () => _save('refreshInterval', '360')),
        _radioTile('每 12 小时', '', _refreshInterval == '720',
            () => _save('refreshInterval', '720')),
        _radioTile('每 24 小时', '', _refreshInterval == '1440',
            () => _save('refreshInterval', '1440')),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('使用当前位置'),
          subtitle: const Text('开启后会请求定位权限并自动更新天气'),
          value: _useGps,
          onChanged: (v) => _save('useGps', v),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
            title: const Text('自动检查更新'),
            subtitle: const Text('进入App时检查GitHub新版本'),
            value: _autoCheckUpdate,
            onChanged: (v) => _save('autoCheckUpdate', v)),
        const SizedBox(height: 16),
        const Divider(),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text('晴暖天气 v1.2.2（实验版）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('晴暖天气：为长辈设计的简洁大字天气应用。',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              Text('数据来源：中央气象台 / 彩云天气 / 和风天气 / Open-Meteo',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ])),
      ]),
        ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));

  Widget _checkboxTile(
      String label, String subtitle, bool checked, VoidCallback onTap) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 18)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.grey))
          : null,
      value: checked,
      onChanged: (_) => onTap(),
      activeColor: const Color(0xFF0B6BCB),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _radioTile(
      String label, String subtitle, bool selected, VoidCallback onTap,
      {String? badge}) {
    return RadioListTile(
      title: Row(children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        if (badge != null) ...[
          SizedBox(width: 8),
          Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Color(0xFF0B6BCB),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(badge,
                  style: TextStyle(fontSize: 12, color: Colors.white))),
        ],
      ]),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.grey))
          : null,
      value: true,
      groupValue: selected,
      onChanged: (_) => onTap(),
      activeColor: const Color(0xFF0B6BCB),
    );
  }
}
