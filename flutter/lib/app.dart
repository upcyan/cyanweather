import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

class CyanWeatherApp extends StatelessWidget {
  final SharedPreferences prefs;
  const CyanWeatherApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ));
    return MaterialApp(
      title: '晴暖天气',
      debugShowCheckedModeBanner: false,
      // 字号由 App 内的 standard/large/xlarge 档位控制（同 native 的
      // LocalFontScale），不再叠加系统字体缩放，否则 1.3 档会被系统
      // 再放大一次，信息卡右侧胶囊过宽、左侧数值被挤断。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6BCB),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}
