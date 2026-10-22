import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  /// 条目所属小时（0-23）。逐时卡必须传条目时间，否则夜里 20 点的「晴」
  /// 会错误沿用当前时刻的白昼判定。缺省按当前时刻（主天气卡用）。
  final int? hour;
  const WeatherIcon(
      {super.key, required this.condition, this.size = 48, this.hour});

  @override
  Widget build(BuildContext context) {
    final h = hour ?? DateTime.now().hour;
    final night = h >= 19 || h < 6;
    final path = _getIconPath(condition, night);
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      placeholderBuilder: (_) =>
          Text(_getEmoji(condition), style: TextStyle(fontSize: size)),
    );
  }

  String _getIconPath(String c, bool night) {
    if (c.contains('雷')) return 'assets/weather/thunderstorms.svg';
    if (c.contains('雨夹雪')) return 'assets/weather/sleet.svg';
    if (c.contains('暴雨') || c.contains('大雨'))
      return 'assets/weather/rain-heavy.svg';
    if (c.contains('中雨')) return 'assets/weather/rain-moderate.svg';
    if (c.contains('雨')) return 'assets/weather/rain.svg';
    if (c.contains('暴雪') || c.contains('大雪'))
      return 'assets/weather/snow-heavy.svg';
    if (c.contains('中雪')) return 'assets/weather/snow-moderate.svg';
    if (c.contains('雪')) return 'assets/weather/snow.svg';
    if (c.contains('霾')) return 'assets/weather/haze.svg';
    if (c.contains('雾')) return 'assets/weather/fog.svg';
    if (c.contains('阴')) return 'assets/weather/overcast.svg';
    if (c.contains('多云')) {
      return night
          ? 'assets/weather/partly-cloudy-night.svg'
          : 'assets/weather/partly-cloudy-day.svg';
    }
    if (c.contains('晴')) {
      return night
          ? 'assets/weather/clear-night.svg'
          : 'assets/weather/clear-day.svg';
    }
    return 'assets/weather/overcast.svg';
  }

  String _getEmoji(String c) {
    if (c.contains('雷')) return '⛈';
    if (c.contains('雨')) return '🌧';
    if (c.contains('雪')) return '❄';
    if (c.contains('雾')) return '🌫';
    if (c.contains('阴')) return '☁';
    if (c.contains('多云')) return '⛅';
    if (c.contains('晴')) return '☀';
    return '🌤';
  }
}
