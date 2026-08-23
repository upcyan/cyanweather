package com.cyanweather.cyanweather_webf

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import android.util.JsonWriter
import android.widget.Toast
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.StringWriter
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val channelName = "cyanweather/location"
    private var methodChannel: MethodChannel? = null

    companion object {
        @JvmStatic @Volatile var latestFix: String? = null
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // 启动即在后台线程解析位置并缓存，JS 稍后同步读取
        Thread { resolveLocation(null) }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        android.util.Log.i("GPS", "configureFlutterEngine: registering $channelName")
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = ch
        ch.setMethodCallHandler { call, result ->
            android.util.Log.i("GPS", "dart call: " + call.method)
            if (call.method == "fix") {
                Thread { resolveLocation(result) }.start()
            } else if (call.method == "cached") {
                result.success(latestFix)
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

    /** 全部 provider 的最近缓存取最优 */
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
        // Flutter 契约：Result 必须在主线程调用，否则回调会被丢弃
        fun deliver(action: () -> Unit) = runOnUiThread(action)
        try {
            if (!hasLocationPermission()) {
                result?.let { deliver { it.error("no-permission", "定位权限未授予，请在系统设置中允许", null) } }
                return
            }
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager

            // 1) 最近已知位置（passive 会吸收其它 App 的定位结果）
            bestLastKnown(lm)?.let { last ->
                val ageMin = (System.currentTimeMillis() - last.time) / 60000L
                android.util.Log.i("GPS", "lastKnown age=${ageMin}min ${last.latitude},${last.longitude} (${last.provider})")
                if (ageMin < 120) { result?.let { runOnUiThread { it.success(toJson(last)) } }; return }
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
                android.util.Log.i("GPS", "requestSingleUpdate on $providers")
                val got = latch.await(12, TimeUnit.SECONDS)
                try { lm.removeUpdates(listener) } catch (_: Exception) { }
                android.util.Log.i("GPS", "singleUpdate got=$got ${fixed?.latitude},${fixed?.longitude}")
            } else {
                android.util.Log.i("GPS", "all providers disabled")
            }

            val chosen = fixed ?: bestLastKnown(lm)
            if (chosen != null) {
                val json = toJson(chosen)
                latestFix = json
                runOnUiThread {
                    val mc = methodChannel
                    if (mc != null) { try { mc.invokeMethod("onFix", json) } catch (_: Exception) { } }
                }
                result?.let { runOnUiThread { it.success(json) } }
            } else {
                result?.let { runOnUiThread { it.error("no-fix", "无法获取位置：请确认系统“位置信息”已开启并稍后重试", null) } }
            }
        } catch (e: Exception) {
            result?.let { runOnUiThread { it.error("error", e.message ?: "定位异常", null) } }
        }
    }

    private fun toJson(l: Location): String {
        val sw = StringWriter(); val w = JsonWriter(sw)
        w.beginObject().name("latitude").value(l.latitude).name("longitude").value(l.longitude).endObject().close()
        return sw.toString()
    }
}
