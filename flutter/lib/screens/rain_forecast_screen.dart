import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../widgets/weather_icon.dart';

/// 降雨趋势预报页（对齐 native RainForecastScreen）
class RainForecastScreen extends StatelessWidget {
  final WeatherData? weather;
  const RainForecastScreen({super.key, this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Color(0xFF333333))),
                        SizedBox(width: 8 * fsOf(context)),
                        Text('降雨趋势预报',
                            style: TextStyle(
                                fontSize: 24 * fsOf(context),
                                fontWeight: FontWeight.bold)),
                      ]),
                      SizedBox(height: 8 * fsOf(context)),
                      Text(w?.cityName ?? '',
                          style: TextStyle(
                              fontSize: 16 * fsOf(context),
                              color: const Color(0xFF666666))),
                      SizedBox(height: 10 * fsOf(context)),
                      if (w == null) ...[
                        Text('暂无天气数据',
                            style: TextStyle(fontSize: 18 * fsOf(context)))
                      ] else ..._body(context, w!),
                    ]))));
  }

  double fsOf(BuildContext context) => 1.3;

  List<Widget> _body(BuildContext context, WeatherData w) {
    final hourlyRain = w.hourly
        .where((h) => h.isForecast && h.rainProb != null)
        .take(24)
        .toList();
    if (hourlyRain.isNotEmpty) {
      return [
        Text('未来24小时降雨概率',
            style: TextStyle(
                fontSize: 19 * fsOf(context), fontWeight: FontWeight.bold)),
        SizedBox(height: 4 * fsOf(context)),
        Text('数值为降雨概率，雨天与雷雨时段以蓝色标出。',
            style: TextStyle(
                fontSize: 13 * fsOf(context), color: const Color(0xFF666666))),
        SizedBox(height: 6 * fsOf(context)),
        ...hourlyRain.map((item) => _rainHourRow(context, item)),
        const SizedBox(height: 24),
      ];
    }
    return [
      Text('逐时降雨概率',
          style: TextStyle(
              fontSize: 19 * fsOf(context), fontWeight: FontWeight.bold)),
      SizedBox(height: 4 * fsOf(context)),
      Text('当前数据源暂不提供逐时降雨概率，以下为未来几日降雨趋势。',
          style: TextStyle(
              fontSize: 13 * fsOf(context), color: const Color(0xFF666666))),
      SizedBox(height: 6 * fsOf(context)),
      ...w.daily.take(7).map((d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            WeatherIcon(condition: d.dayText + d.nightText, size: 28),
            SizedBox(width: 10 * fsOf(context)),
            Expanded(
                child: Text(d.dayText + d.nightText,
                    style: TextStyle(fontSize: 16 * fsOf(context)))),
          ]))),
      const SizedBox(height: 24),
    ];
  }

  Widget _rainHourRow(BuildContext context, HourlyItem item) {
    final isRain =
        item.condition.contains('雨') || item.condition.contains('雷');
    final prob = (item.rainProb ?? 0.0).clamp(0.0, 100.0);
    final accent = (isRain || prob >= 50)
        ? const Color(0xFF0B6BCB)
        : const Color(0xFF666666);
    final parts = _dateHour(item.time);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Row(children: [
            SizedBox(
                width: 92,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parts.$1,
                          style: TextStyle(
                              fontSize: 14 * fsOf(context),
                              color: const Color(0xFF666666))),
                      Text(parts.$2,
                          style: TextStyle(
                              fontSize: 15 * fsOf(context),
                              color: const Color(0xFF666666))),
                    ])),
            Expanded(
                child: Text(item.condition.isEmpty ? '-' : item.condition,
                    style:
                        TextStyle(fontSize: 16 * fsOf(context), color: accent))),
            Text('${prob.toInt()}%',
                style: TextStyle(
                    fontSize: 16 * fsOf(context),
                    fontWeight: FontWeight.bold,
                    color: accent)),
          ]),
          SizedBox(height: 4 * fsOf(context)),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                  height: 12,
                  child: Stack(children: [
                    Container(color: const Color(0xFFE3EDF9)),
                    FractionallySizedBox(
                        widthFactor: prob / 100.0,
                        child: Container(
                            color: prob >= 50
                                ? const Color(0xFF0B6BCB)
                                : const Color(0xFF90CAF9))),
                  ]))),
        ]));
  }

  /// '2025-08-25T14:00' / '2025-08-25 14:00' -> ('08/25', '14时')
  (String, String) _dateHour(String time) {
    final t = time.trim();
    if ((t.contains('T') || t.contains(' ')) && t.length >= 16) {
      final date = t.substring(5, 10).replaceAll('-', '/');
      final hour = int.tryParse(t.substring(11, 13)) ?? '?';
      return (date, '$hour时');
    }
    return ('', t);
  }
}
