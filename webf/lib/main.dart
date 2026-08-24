import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webf/webf.dart';

/// 系统 LocationManager 定位：原生 onCreate 即后台解析并写入
/// files/gps_fix.json；任意 Flutter 引擎/隔离区直接读该文件，
/// 完全避开跨引擎 MethodChannel 注册时序问题。
class SystemLocation {
  static const _fixFile = '/data/data/com.cyanweather.cyanweather_webf/files/gps_fix.json';
  static const _channel = MethodChannel('cyanweather/location');
  static String? latest;

  /** 应用内更新：交给系统 DownloadManager */
  static Future<String> installApk(String url, {String title = '晴暖天气更新'}) async {
    final r = await _channel.invokeMethod<String>('installApk', {'url': url, 'title': title});
    return r ?? 'ok';
  }

  static void init() {
    // 周期读取原生落盘的定位结果（最多 60 秒）
    var n = 0;
    Timer.periodic(const Duration(seconds: 2), (t) async {
      n++;
      if (latest != null || n > 30) { t.cancel(); return; }
      try {
        final f = File(_fixFile);
        if (!await f.exists()) return;
        final s = await f.readAsString();
        if (s.contains('latitude')) {
          latest = s;
          debugPrint('[GPS] cache updated from file: $s');
          t.cancel();
        }
      } catch (_) { }
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
    if (method == 'trace') {
      // JS 调试通道：写入共享 trace 文件
      try {
        File('/data/data/com.cyanweather.cyanweather_webf/files/gps_trace.txt')
            .writeAsStringSync('[js] ${params.isNotEmpty ? params[0] : ""}\n',
                mode: FileMode.append);
      } catch (_) {}
      return '';
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
            bundle: WebFBundle.fromUrl('assets:///assets/web/index.html'),
            createController: () => WebFController(),
            loadingWidget: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
