import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// 城市选择页（对齐 native CityPickerScreen）：
/// 首屏即「📍 使用当前位置」+ 全国省份列表 → 点击进市级列表；搜索走 NMC 全量城市（Open-Meteo 兜底）。
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});
  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  String _search = '';
  bool _loading = false;
  bool _allCitiesLoading = false;
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _allCities = [];
  String? _selectedProvince;
  String? _selectedProvName;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedProvince != null ? '选择城市 / 区县' : '选择省份'),
        leading: IconButton(
          onPressed: () {
            if (_selectedProvince != null) {
              setState(() { _selectedProvince = null; _selectedProvName = null; _cities = []; });
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          decoration: const InputDecoration(hintText: '搜索城市/区县', prefixIcon: Icon(Icons.search)),
          onChanged: (v) {
            setState(() => _search = v.trim());
            if (_search.isNotEmpty) _ensureAllCities();
          },
        )),
        const Divider(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildList() {
    // 搜索模式：NMC 全量城市匹配（对齐 native ensureAllCities + filter）
    if (_search.isNotEmpty) {
      if (_allCitiesLoading && _allCities.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_allCities.isEmpty) {
        return const Center(child: Text('城市数据加载失败，请检查网络'));
      }
      final matched = _allCities.where((c) {
        final city = (c['city'] ?? '').toString();
        final prov = (c['province'] ?? '').toString();
        return city.contains(_search) || prov.contains(_search);
      }).toList();
      if (matched.isEmpty) return Center(child: Text('未找到「$_search」，换个名字试试'));
      return ListView.builder(itemCount: matched.length, itemBuilder: (_, i) {
        final c = matched[i];
        final city = (c['city'] ?? '').toString();
        final prov = (c['province'] ?? '').toString();
        return _bigListTile('$city（$prov）', () => Navigator.pop(context, {'name': city, 'code': c['code'] ?? ''}));
      });
    }

    if (_selectedProvince != null) {
      // 市级列表
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_cities.isEmpty) return const Center(child: Text('未找到城市，换个名字试试'));
      return ListView.builder(itemCount: _cities.length, itemBuilder: (_, i) {
        final c = _cities[i];
        final name = (c['city'] ?? '').toString();
        return _bigListTile(name, () => Navigator.pop(context, {'name': name, 'code': c['code'] ?? ''}));
      });
    }

    // 省级列表：📍 使用当前位置 + 全国省份
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(children: [
      _bigListTile('📍 使用当前位置', () => Navigator.pop(context, {'useLocation': true})),
      ..._provinces.map((p) => _bigListTile(
          (p['name'] ?? '').toString(),
          () => _loadCities((p['code'] ?? '').toString()))),
    ]);
  }

  Widget _bigListTile(String text, VoidCallback onTap) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
          title: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          onTap: onTap,
        ),
      );

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

  /// 搜索时懒加载全国城市（对齐 native ensureAllCities）
  void _ensureAllCities() async {
    if (_allCities.isNotEmpty || _allCitiesLoading) return;
    setState(() => _allCitiesLoading = true);
    try {
      final provinces = await ApiService.fetchNmcProvinces();
      final all = <Map<String, dynamic>>[];
      for (final p in provinces) {
        try {
          final code = (p['code'] ?? '').toString();
          final provName = (p['name'] ?? '').toString();
          final cities = await ApiService.fetchNmcCities(code);
          for (final c in cities) {
            all.add({'city': c['city'], 'code': c['code'], 'province': provName});
          }
        } catch (_) {}
      }
      _allCities = all;
    } catch (_) {}
    if (mounted) setState(() => _allCitiesLoading = false);
  }
}
