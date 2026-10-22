import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Boot());
}

/// 先把首帧交出去，再异步读设置。
///
/// 旧实现是在 main() 里 `await SharedPreferences.getInstance()` 之后才
/// runApp：只要平台通道不返回（部分 ROM 的 DataStore/文件锁异常），
/// runApp 永远不执行，用户看到的就是纯黑屏且没有任何报错。
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  SharedPreferences? _prefs;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[CyanBoot] Dart boot screen mounted');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = '读取本地设置超时（6 秒）。\n可能是系统存储服务未响应，请重试。';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '读取本地设置失败：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs != null) return CyanWeatherApp(prefs: prefs);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F9FF),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Color(0xFF0B6BCB))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Color(0xFFC62828)),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? '启动失败',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
