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
    if (c.contains('雷')) return 'assets/icons/thunder.svg';
    if (c.contains('阵雨')) return 'assets/icons/rain.svg';
    if (c.contains('雨')) return 'assets/icons/rain.svg';
    if (c.contains('雪')) return 'assets/icons/snow.svg';
    if (c.contains('雾')) return 'assets/icons/fog.svg';
    if (c.contains('阴')) return 'assets/icons/cloud.svg';
    if (c.contains('多云') || c.contains('晴朗')) return 'assets/icons/partly_cloudy.svg';
    if (c.contains('晴')) return 'assets/icons/sun.svg';
    return 'assets/icons/cloud.svg';
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
