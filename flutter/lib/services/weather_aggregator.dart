import 'dart:math' as math;

import '../models/weather_model.dart';

/// 多源加权聚合（对齐 native shared WeatherAggregator）：
/// 气象局 0.9 / 彩云、和风 0.85 / Open-Meteo 0.8 / 小米 0.7，
/// 数值字段经 MAD 稳健过滤后加权平均，逐时/多日按时间与日期合并。
class WeatherAggregator {
  static const Map<String, double> sourceWeights = {
    'nmc': 0.9,
    'openmeteo': 0.8,
    'caiyun': 0.85,
    'qweather': 0.85,
    'xiaomi': 0.7,
  };

  static const Map<String, String> sourceNames = {
    'nmc': '中国气象局',
    'openmeteo': 'Open-Meteo',
    'caiyun': '彩云天气',
    'qweather': '和风天气',
    'xiaomi': '小米天气',
  };

  static String sourceName(String id) => sourceNames[id] ?? id;

  static WeatherData aggregate(List<MapEntry<String, WeatherData>> sources) {
    if (sources.isEmpty) throw ArgumentError('No sources to aggregate');
    if (sources.length == 1) return sources.first.value;

    final primary = sources.first.value;
    final weights =
        sources.map((e) => sourceWeights[e.key] ?? 0.7).toList();

    return WeatherData(
      cityName: primary.cityName,
      updatedAt: primary.updatedAt,
      temperature: _aggDouble(sources.map((e) => e.value.temperature).toList(), weights)!,
      condition: _aggCondition(
          List.generate(sources.length, (i) => MapEntry(sources[i].value.condition, weights[i]))),
      feelsLike: _aggDouble(sources.map((e) => e.value.feelsLike).toList(), weights),
      humidity: _aggInt(sources.map((e) => e.value.humidity).toList(), weights),
      windDirect: _firstNonBlank(sources.map((e) => e.value.windDirect).toList()),
      windPower: _firstNonBlank(sources.map((e) => e.value.windPower).toList()),
      todayHigh: _aggDouble(sources.map((e) => e.value.todayHigh).toList(), weights),
      todayLow: _aggDouble(sources.map((e) => e.value.todayLow).toList(), weights),
      aqi: _aggInt(sources.map((e) => e.value.aqi).toList(), weights),
      aqiText: _aqiText(_aggInt(sources.map((e) => e.value.aqi).toList(), weights)),
      pm25: _aggDouble(sources.map((e) => e.value.pm25).toList(), weights),
      pm10: _aggDouble(sources.map((e) => e.value.pm10).toList(), weights),
      windSpeed: _aggDouble(sources.map((e) => e.value.windSpeed).toList(), weights),
      warning: _aggWarning(sources),
      sunrise: _firstNonBlank(sources.map((e) => e.value.sunrise).toList()),
      sunset: _firstNonBlank(sources.map((e) => e.value.sunset).toList()),
      minutelyText: _firstNonBlank(sources.map((e) => e.value.minutelyText).toList()),
      uvIndex: _aggUvIndex(sources),
      sourceTag: _sourceTag(sources),
      hourlyLabel: _hourlyLabel(sources),
      confidence: _computeConfidence(sources, weights),
      hourly: _aggHourly(sources),
      daily: _aggDaily(sources),
      yesterday: _aggYesterday(sources),
    );
  }

  /// 置信度 = 源覆盖度×0.4 + 温度一致性×0.6（对齐 native computeConfidence）
  static double _computeConfidence(
      List<MapEntry<String, WeatherData>> sources, List<double> weights) {
    if (sources.length == 1) return weights.first;
    final totalWeight = weights.fold<double>(0, (s, w) => s + w);
    final coverage = totalWeight / (sources.length * 0.9);
    final agreement = _agreement(sources);
    final v = coverage * 0.4 + agreement * 0.6;
    return v.clamp(0.0, 1.0);
  }

  static double _agreement(List<MapEntry<String, WeatherData>> sources) {
    final temps = sources
        .map((e) => e.value.temperature)
        .where((t) => t > -900)
        .toList();
    if (temps.length < 2) return 1.0;
    final mean = temps.reduce((a, b) => a + b) / temps.length;
    final variance = temps
            .map((t) => (t - mean) * (t - mean))
            .reduce((a, b) => a + b) /
        temps.length;
    final std = math.sqrt(variance);
    return ((5.0 - std) / 5.0).clamp(0.0, 1.0);
  }

  static String _firstNonBlank(List<String> values) {
    for (final v in values) {
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static String _aggWarning(List<MapEntry<String, WeatherData>> sources) {
    for (final e in sources) {
      if (e.key == 'nmc' && e.value.warning.isNotEmpty) return e.value.warning;
    }
    for (final e in sources) {
      if (e.value.warning.isNotEmpty) return e.value.warning;
    }
    return '';
  }

  static String _aggUvIndex(List<MapEntry<String, WeatherData>> sources) =>
      _firstNonBlank(sources.map((e) => e.value.uvIndex).toList());

  static String _sourceTag(List<MapEntry<String, WeatherData>> sources) =>
      '数据来源：${sources.map((e) => sourceName(e.key)).join(' + ')}（智能聚合）';

  static String _hourlyLabel(List<MapEntry<String, WeatherData>> sources) {
    final maxHourly = sources.fold<int>(0, (m, e) => e.value.hourly.length > m ? e.value.hourly.length : m);
    return '未来$maxHourly小时逐时预报（多源聚合）';
  }

  static String _aqiText(int? aqi) {
    if (aqi == null) return '';
    if (aqi <= 50) return '优';
    if (aqi <= 100) return '良';
    if (aqi <= 150) return '轻度污染';
    if (aqi <= 200) return '中度污染';
    if (aqi <= 300) return '重度污染';
    return '严重污染';
  }

  static double? _aggDouble(List<double?> values, List<double> weights) {
    final valid = <MapEntry<double, double>>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) valid.add(MapEntry(v, weights[i]));
    }
    if (valid.isEmpty) return null;
    if (valid.length == 1) return valid.first.key;
    final filtered = _robustFilter(valid);
    final totalWeight = filtered.fold<double>(0, (s, e) => s + e.value);
    final sum = filtered.fold<double>(0, (s, e) => s + e.key * e.value);
    return sum / totalWeight;
  }

  static int? _aggInt(List<int?> values, List<double> weights) {
    final valid = <MapEntry<double, double>>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) valid.add(MapEntry(v.toDouble(), weights[i]));
    }
    if (valid.isEmpty) return null;
    if (valid.length == 1) return valid.first.key.round();
    final filtered = _robustFilter(valid);
    final totalWeight = filtered.fold<double>(0, (s, e) => s + e.value);
    final sum = filtered.fold<double>(0, (s, e) => s + e.key * e.value);
    return (sum / totalWeight).round();
  }

  /// 小样本稳健离群值过滤（MAD 法）：中位数 ± 2.5·MAD，绝对下限 1.0。
  static List<MapEntry<double, double>> _robustFilter(List<MapEntry<double, double>> valid) {
    if (valid.length < 3) return valid;
    final values = valid.map((e) => e.key).toList();
    final med = _median(values);
    final mad = _median(values.map((v) => (v - med).abs()).toList());
    final threshold = 2.5 * mad > 1.0 ? 2.5 * mad : 1.0;
    final kept =
        valid.where((e) => (e.key - med).abs() <= threshold).toList();
    return kept.isEmpty ? valid : kept;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final n = sorted.length;
    return n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  static String _aggCondition(List<MapEntry<String, double>> entries) {
    final nonBlank = entries.where((e) => e.key.isNotEmpty).toList();
    if (nonBlank.isEmpty) return '';
    if (nonBlank.length == 1) return nonBlank.first.key;
    nonBlank.sort((a, b) => b.value.compareTo(a.value));
    return nonBlank.first.key;
  }

  /// 规范化逐时时间戳为 "yyyy-MM-ddTHH:mm"，兼容气象局的空格分隔与 "MM-dd HH:mm"（补当前年份）。
  static String normalizeHourTime(String t) {
    final v = t.trim().replaceAll('/', '-');
    var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})').firstMatch(v);
    if (m != null) {
      return '${m.group(1)}-${_p2(m.group(2)!)}-${_p2(m.group(3)!)}T${_p2(m.group(4)!)}:${m.group(5)}';
    }
    m = RegExp(r'^(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})').firstMatch(v);
    if (m != null) {
      final year = DateTime.now().year.toString();
      return '$year-${_p2(m.group(1)!)}-${_p2(m.group(2)!)}T${_p2(m.group(3)!)}:${m.group(4)}';
    }
    return t;
  }

  static String _p2(String v) => v.padLeft(2, '0');

  static List<HourlyItem> _aggHourly(List<MapEntry<String, WeatherData>> sources) {
    final all = <MapEntry<HourlyItem, double>>[];
    for (final e in sources) {
      final w = sourceWeights[e.key] ?? 0.7;
      for (final h in e.value.hourly) {
        all.add(MapEntry(h, w));
      }
    }
    if (all.isEmpty) return const [];
    final normalized = all
        .map((e) => MapEntry(
            HourlyItem(
              time: normalizeHourTime(e.key.time),
              temperature: e.key.temperature,
              condition: e.key.condition,
              isForecast: e.key.isForecast,
              rainProb: e.key.rainProb,
            ),
            e.value))
        .toList();
    final grouped = <String, List<MapEntry<HourlyItem, double>>>{};
    for (final e in normalized) {
      grouped.putIfAbsent(e.key.time, () => []).add(e);
    }
    final merged = grouped.entries.map((entry) {
      final items = entry.value;
      final temps = items.map((e) => e.key.temperature).toList();
      final ws = items.map((e) => e.value).toList();
      final conds =
          List.generate(items.length, (i) => MapEntry(items[i].key.condition, ws[i]));
      final rainProbs = <MapEntry<double, double>>[];
      for (final e in items) {
        final p = e.key.rainProb;
        if (p != null) rainProbs.add(MapEntry(p, e.value));
      }
      return HourlyItem(
        time: entry.key,
        temperature: _aggDouble(temps, ws),
        condition: _aggCondition(conds),
        isForecast: items.any((e) => e.key.isForecast),
        rainProb: rainProbs.isEmpty ? null : _aggDouble(rainProbs.map((e) => e.key).toList(), rainProbs.map((e) => e.value).toList()),
      );
    }).toList();
    merged.sort((a, b) => a.time.compareTo(b.time));
    // 气象局实况时段无天气文字，剔除已过去的非预报时段，避免列表开头一排空卡
    final now = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    final nowKey =
        '${now.year}-${p2(now.month)}-${p2(now.day)}T${p2(now.hour)}:00';
    merged.removeWhere((h) => !h.isForecast && h.time.compareTo(nowKey) <= 0);
    return merged;
  }

  static List<DailyItem> _aggDaily(List<MapEntry<String, WeatherData>> sources) {
    final all = <MapEntry<DailyItem, double>>[];
    for (final e in sources) {
      final w = sourceWeights[e.key] ?? 0.7;
      for (final d in e.value.daily) {
        all.add(MapEntry(d, w));
      }
    }
    if (all.isEmpty) return const [];
    final grouped = <String, List<MapEntry<DailyItem, double>>>{};
    for (final e in all) {
      grouped.putIfAbsent(e.key.date, () => []).add(e);
    }
    final merged = grouped.entries.map((entry) {
      final items = entry.value;
      final ws = items.map((e) => e.value).toList();
      final highs = items.map((e) => e.key.high).toList();
      final lows = items.map((e) => e.key.low).toList();
      final dayTexts = List.generate(items.length,
          (i) => MapEntry(items[i].key.dayText, ws[i]));
      final nightTexts = List.generate(items.length,
          (i) => MapEntry(items[i].key.nightText, ws[i]));
      return DailyItem(
        date: entry.key,
        dayText: _aggCondition(dayTexts),
        nightText: _aggCondition(nightTexts),
        high: _aggDouble(highs, ws),
        low: _aggDouble(lows, ws),
      );
    }).toList();
    merged.sort((a, b) => a.date.compareTo(b.date));
    return merged;
  }

  static YesterdayData? _aggYesterday(List<MapEntry<String, WeatherData>> sources) {
    final yesterdays = sources.map((e) => e.value.yesterday).whereType<YesterdayData>().toList();
    if (yesterdays.isEmpty) return null;
    final highs = yesterdays.map((y) => y.high).whereType<double>().toList();
    final lows = yesterdays.map((y) => y.low).whereType<double>().toList();
    final byTime = <String, List<HourlyItem>>{};
    for (final y in yesterdays) {
      for (final h in y.hourly) {
        // 时间规范化后按小时合并，否则 NMC（空格分隔）与 Open-Meteo（T 分隔）无法对齐
        final t = normalizeHourTime(h.time);
        byTime.putIfAbsent(t, () => []).add(h);
      }
    }
    final hourly = byTime.entries.map((entry) {
      final items = entry.value;
      final temps = items.map((h) => h.temperature).toList();
      final conds = List.generate(
          items.length, (i) => MapEntry(items[i].condition, 0.8));
      return HourlyItem(
        time: entry.key,
        temperature: _aggDouble(temps, List.filled(items.length, 0.8)),
        condition: _aggCondition(conds),
        isForecast: false,
      );
    }).toList();
    hourly.sort((a, b) => a.time.compareTo(b.time));
    return YesterdayData(
      high: highs.isEmpty ? null : highs.reduce((a, b) => a + b) / highs.length,
      low: lows.isEmpty ? null : lows.reduce((a, b) => a + b) / lows.length,
      hourly: hourly,
    );
  }
}
