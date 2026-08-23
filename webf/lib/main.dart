import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webf/webf.dart';

/// 系统 LocationManager 定位：原生启动即后台解析并缓存，
/// JS 通过同步模块读取，完全避开跨 FFI 异步回调。
class SystemLocation {
  static const _channel = MethodChannel('cyanweather/location');
  static String? latest;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFix' && call.arguments is String) {
        latest = call.arguments as String;
        debugPrint('[GPS] cache updated: $latest');
      }
      return null;
    });
    // 原生 handler 注册时序可能晚于 Dart main，重试直至接通
    Future(() async {
      for (var i = 0; i < 10; i++) {
        try {
          await _channel.invokeMethod<String>('start');
          debugPrint('[GPS] start ok (attempt $i)');
          return;
        } catch (e) {
          debugPrint('[GPS] start retry $i: ${e.toString().replaceAll(String.fromCharCode(10), " | ")}');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    });
  }
}

/// GPS 定位桥接模块。
/// JS 端调用方式：
///   webf.invokeModule('GPS', 'getLocation', [], callback)
/// 成功时回调收到 JSON 字符串 '{"latitude":..,"longitude":..}'。
class GpsModule extends WebFBaseModule {
  GpsModule(super.moduleManager);

  @override
  String get name => 'GPS';

  @override
  dynamic invoke(String method, List<dynamic> params) {
    if (method == 'getLocation') {
      // 同步返回缓存；原生 onCreate 起持续刷新该缓存
      final v = SystemLocation.latest;
      debugPrint('[GPS] sync read: $v');
      return v ?? '{"error":"not-ready"}';
    }
    return null;
  }

  @override
  void dispose() {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemLocation.init();
  ModuleManager.defineModule((moduleManager) => GpsModule(moduleManager));

  WebFControllerManager.instance.initialize(
    const WebFControllerManagerConfig(
      maxAliveInstances: 5,
      maxAttachedInstances: 3,
    ),
  );

  WebFControllerManager.instance.addOrUpdateControllerWithLoading(
    name: 'home',
    createController: () => WebFController(),
    bundle: WebFBundle.fromUrl('assets:///assets/web/index.html'),
    mode: WebFLoadingMode.preloading,
  );

  runApp(const CyanWeatherWebfApp());
}

class CyanWeatherWebfApp extends StatelessWidget {
  const CyanWeatherWebfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '青色天气',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.cyan),
      home: Scaffold(
        body: SafeArea(
          child: WebF.fromControllerName(
            controllerName: 'home',
            loadingWidget: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
