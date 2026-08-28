import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;
  const WeatherIcon({super.key, required this.condition, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final path = _getIconPath(condition);
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      placeholderBuilder: (_) => Text(_getEmoji(condition), style: TextStyle(fontSize: size)),
    );
  }

  String _getIconPath(String c) {
    if (c.contains('雷')) return 'assets/meteocons/thunderstorms.svg';
    if (c.contains('雨夹雪')) return 'assets/meteocons/sleet.svg';
    if (c.contains('雨')) return 'assets/meteocons/rain.svg';
    if (c.contains('雪')) return 'assets/meteocons/snow.svg';
    if (c.contains('雾') || c.contains('霾')) return 'assets/meteocons/fog.svg';
    if (c.contains('阴')) return 'assets/meteocons/overcast.svg';
    if (c.contains('多云') || c.contains('晴朗')) return 'assets/meteocons/partly-cloudy-day.svg';
    if (c.contains('晴')) return 'assets/meteocons/clear-day.svg';
    return 'assets/meteocons/overcast.svg';
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
