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
  String _fontSize = 'large';
  String _refreshInterval = '30';
  bool _autoCheckUpdate = true;
  bool _useGps = true;
  String _caiyunToken = '';
  String _caiyunMode = 'none';

  @override
  void initState() {
    super.initState();
    _source = widget.prefs.getString('source') ?? 'openmeteo';
    _fontSize = widget.prefs.getString('fontSize') ?? 'large';
    _refreshInterval = widget.prefs.getString('refreshInterval') ?? '30';
    _autoCheckUpdate = widget.prefs.getBool('autoCheckUpdate') ?? true;
    _useGps = widget.prefs.getBool('useGps') ?? true;
    _caiyunToken = widget.prefs.getString('caiyunToken') ?? '';
    _caiyunMode = widget.prefs.getString('caiyunMode') ?? 'none';
  }

  Future<void> _save(String key, dynamic value) async {
    if (value is String) await widget.prefs.setString(key, value);
    if (value is bool) await widget.prefs.setBool(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('天气数据源'),
        _radioTile('Open-Meteo', '免费开放源，无需密钥', _source == 'openmeteo',
            () => _save('source', 'openmeteo')),
        _radioTile('中国气象局', '中央气象台，免费无需密钥', _source == 'nmc',
            () => _save('source', 'nmc')),
        _radioTile('彩云天气', '实时精准，分钟级预报，需凭证', _source == 'caiyun',
            () => _save('source', 'caiyun')),
        if (_source == 'caiyun') ...[
          const SizedBox(height: 8),
          _sectionTitle('接入方式'),
          _radioTile('V1 Token', '免费版，3天预报', _caiyunMode == 'v1',
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
            Text('在 dashboard.caiyunapp.com 注册获取',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
          Text('凭证未填写完整时，自动使用中国气象局数据',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
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
        _radioTile('每 10 分钟', '', _refreshInterval == '10',
            () => _save('refreshInterval', '10')),
        _radioTile('每 30 分钟', '', _refreshInterval == '30',
            () => _save('refreshInterval', '30'),
            badge: '推荐'),
        _radioTile('每 60 分钟', '', _refreshInterval == '60',
            () => _save('refreshInterval', '60')),
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
              Text('晴暖天气 v1.0',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('为长辈设计的简洁大字天气应用',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              Text('数据来源：Open-Meteo / 中央气象台 / 彩云天气',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ])),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));

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
