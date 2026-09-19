package com.cyanweather.cyanweather_flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.JsonWriter
import androidx.core.app.ActivityCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.StringWriter
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/// 系统定位：对齐 webf 端的成熟方案——直接走 LocationManager（网络优先，GPS 兜底），
/// 规避 geolocator 插件在 MIUI/无 GMS 设备上高精度定位超时的问题。
class MainActivity : FlutterActivity() {

    private val channelName = "cyanweather/location"

    companion object {
        @JvmStatic @Volatile var latestFix: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) window.isNavigationBarContrastEnforced = false
        WindowInsetsControllerCompat(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }
        // 全新安装时权限被清空：主动弹授权
        if (!hasLocationPermission()) {
            ActivityCompat.requestPermissions(this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 1)
        }
        // 启动即在后台线程解析位置并缓存
        Thread { runCatching { resolveLocation(null) } }.start()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        Thread { resolveLocation(null) }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "fix") {
                Thread { resolveLocation(result) }.start()
            } else if (call.method == "cached") {
                result.success(latestFix)
            } else if (call.method == "openAppSettings") {
                try {
                    val i = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.fromParts("package", packageName, null))
                    i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(i)
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("error", e.message ?: "无法打开设置", null)
                }
            } else if (call.method == "openLocationSettings") {
                try {
                    val i = android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                    i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(i)
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("error", e.message ?: "无法打开设置", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    /** 全部 provider 的最近缓存取最优（passive 会吸收其它 App 的定位结果） */
    private fun bestLastKnown(lm: LocationManager): Location? {
        var best: Location? = null
        for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER,
                 LocationManager.PASSIVE_PROVIDER, "fused")) {
            try {
                val l: Location? = lm.getLastKnownLocation(p)
                if (l != null && (best == null || l.time > best!!.time)) best = l
            } catch (_: Exception) { }
        }
        return best
    }

    private fun resolveLocation(result: MethodChannel.Result?) {
        // Flutter 契约：Result 必须在主线程调用
        fun deliver(action: () -> Unit) = runOnUiThread(action)
        try {
            if (!hasLocationPermission()) {
                result?.let { deliver { it.error("no-permission", "定位权限未授予，请在系统设置中允许", null) } }
                return
            }
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            // 1) 2 小时内的最近已知位置直接采用
            bestLastKnown(lm)?.let { last ->
                val ageMin = (System.currentTimeMillis() - last.time) / 60000L
                if (ageMin < 120) {
                    latestFix = toJson(last)
                    result?.let { deliver { it.success(toJson(last)) } }
                    return
                }
            }

            // 2) 主动单次请求：优先 WiFi/基站（NETWORK_PROVIDER），失败再 GPS
            var fixed: Location? = null
            val latch = CountDownLatch(1)
            val listener = LocationListener { l ->
                synchronized(this) { if (fixed == null) fixed = l }
                latch.countDown()
            }
            val providers = mutableListOf<String>()
            try { if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) providers.add(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { }
            try { if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) providers.add(LocationManager.GPS_PROVIDER) } catch (_: Exception) { }

            if (providers.isNotEmpty()) {
                for (p in providers) {
                    try { lm.requestSingleUpdate(p, listener, Looper.getMainLooper()) } catch (_: Exception) { }
                }
                latch.await(12, TimeUnit.SECONDS)
                try { lm.removeUpdates(listener) } catch (_: Exception) { }
            }

            val chosen = fixed ?: bestLastKnown(lm)
            if (chosen != null) {
                val json = toJson(chosen)
                latestFix = json
                result?.let { deliver { it.success(json) } }
            } else {
                result?.let { deliver { it.error("no-fix", "无法获取位置：请确认系统“位置信息”已开启并稍后重试", null) } }
            }
        } catch (e: Exception) {
            result?.let { deliver { it.error("error", e.message ?: "定位异常", null) } }
        }
    }

    private fun toJson(l: Location): String {
        val sw = StringWriter(); val w = JsonWriter(sw)
        w.beginObject().name("latitude").value(l.latitude).name("longitude").value(l.longitude).endObject().close()
        return sw.toString()
    }
}
