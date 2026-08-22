import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

class CyanWeatherApp extends StatelessWidget {
  final SharedPreferences prefs;
  const CyanWeatherApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '晴暖天气',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6BCB),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}
