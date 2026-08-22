import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});
  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  String _search = '';
  bool _loading = false;
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  String? _selectedProvince;
  String? _selectedProvName;

  final _preset = [
    {'name': '北京', 'lat': 39.9042, 'lng': 116.4074},
    {'name': '上海', 'lat': 31.2304, 'lng': 121.4737},
    {'name': '广州', 'lat': 23.1291, 'lng': 113.2644},
    {'name': '深圳', 'lat': 22.5431, 'lng': 114.0579},
    {'name': '杭州', 'lat': 30.2741, 'lng': 120.1551},
    {'name': '南京', 'lat': 32.0603, 'lng': 118.7969},
    {'name': '武汉', 'lat': 30.5928, 'lng': 114.3055},
    {'name': '成都', 'lat': 30.5728, 'lng': 104.0668},
    {'name': '重庆', 'lat': 29.4316, 'lng': 106.9123},
    {'name': '西安', 'lat': 34.3416, 'lng': 108.9398},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedProvince != null ? '选择城市/区县' : '选择城市'),
        leading: _selectedProvince != null
            ? IconButton(onPressed: () => setState(() { _selectedProvince = null; _selectedProvName = null; _cities = []; }), icon: const Icon(Icons.arrow_back))
            : null,
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          decoration: const InputDecoration(hintText: '搜索城市/区县', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _search = v),
        )),
        const Divider(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    if (_selectedProvince == null) {
      // Province list or preset
      if (_search.isEmpty) {
        return ListView(children: [
          ListTile(leading: const Icon(Icons.my_location, color: Color(0xFF0B6BCB)),
            title: const Text('使用当前位置', style: TextStyle(fontSize: 18)),
            onTap: () => Navigator.pop(context, {'name': '当前位置', 'lat': 39.9042, 'lng': 116.4074, 'code': ''})),
          const Divider(),
          ..._preset.where((c) => _search.isEmpty || c['name'].toString().contains(_search))
              .map((c) => ListTile(title: Text(c['name'].toString(), style: const TextStyle(fontSize: 18)), onTap: () => Navigator.pop(context, c))),
        ]);
      }
      // Search preset
      final filtered = _preset.where((c) => c['name'].toString().contains(_search)).toList();
      return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) =>
        ListTile(title: Text(filtered[i]['name'].toString(), style: const TextStyle(fontSize: 18)),
          onTap: () => Navigator.pop(context, filtered[i])));
    }
    // City list for selected province
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_cities.isEmpty) return const Center(child: Text('暂无数据'));
    final filtered = _search.isEmpty ? _cities : _cities.where((c) => (c['city'] ?? '').toString().contains(_search)).toList();
    return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
      final c = filtered[i];
      final name = c['city'] ?? '';
      final code = c['code'] ?? '';
      return ListTile(title: Text(name, style: const TextStyle(fontSize: 18)),
        onTap: () => Navigator.pop(context, {'name': name, 'code': code, 'lat': 39.9042, 'lng': 116.4074}));
    });
  }

  void _loadProvinces() async {
    setState(() => _loading = true);
    try { _provinces = await ApiService.fetchNmcProvinces(); } catch (_) {}
    setState(() => _loading = false);
  }

  void _loadCities(String code) async {
    setState(() { _loading = true; _selectedProvince = code; _cities = []; });
    try { _cities = await ApiService.fetchNmcCities(code); } catch (_) {}
    setState(() => _loading = false);
  }
}
