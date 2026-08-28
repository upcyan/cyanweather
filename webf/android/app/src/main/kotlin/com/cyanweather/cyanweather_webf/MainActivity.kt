package com.cyanweather.cyanweather_webf

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import android.graphics.Color
import android.os.Build
import android.util.JsonWriter
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
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
        @JvmStatic fun trace(ctx: Context?, msg: String) {
            try {
                android.util.Log.w("GPS", msg)
                if (ctx != null) {
                    java.io.File(ctx.filesDir, "gps_trace.txt")
                        .appendText(java.text.SimpleDateFormat("HH:mm:ss.SSS ", java.util.Locale.US)
                            .format(java.util.Date()) + msg + "\n")
                }
            } catch (_: Exception) { }
        }
    }

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(newBase)
        trace(newBase.applicationContext ?: newBase, "attachBaseContext")
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        trace(this, "onCreate")
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
        // 启动即在后台线程解析位置并缓存（写文件，供所有引擎的 Dart 读取）
        Thread {
            trace(this, "worker enter")
            try { resolveLocation(null) } catch (t: Throwable) { trace(this, "WORKER EXC: $t") }
            trace(this, "worker exit")
        }.start()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        trace(this, "perm result: " + grantResults.joinToString(","))
        Thread { resolveLocation(null) }.start()
    }

    /** 把定位结果写入 files 目录，跨引擎共享 */
    private fun persist(l: Location) {
        try {
            java.io.File(getFilesDir(), "gps_fix.json").writeText(toJson(l))
            trace(this, "persisted ${l.latitude},${l.longitude}")
        } catch (e: Exception) { trace(this, "persist fail: $e") }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        trace(this, "configureFlutterEngine: registering $channelName")
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = ch
        ch.setMethodCallHandler { call, result ->
            android.util.Log.i("GPS", "dart call: " + call.method)
            if (call.method == "fix") {
                Thread { resolveLocation(result) }.start()
            } else if (call.method == "cached") {
                result.success(latestFix)
            } else if (call.method == "openAppSettings") {
                // 跳转本应用系统设置页（用于「永久拒绝」后的授权引导）
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
                // 跳转系统位置信息开关页
                try {
                    val i = android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                    i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(i)
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("error", e.message ?: "无法打开设置", null)
                }
            } else if (call.method == "installApk") {
                // 应用内更新：交给系统 DownloadManager 下载，完成后通知栏点击安装
                val url = call.argument<String>("url")
                val title = call.argument<String>("title") ?: "晴暖天气更新"
                if (url.isNullOrBlank()) {
                    result.error("bad-args", "url 为空", null); return@setMethodCallHandler
                }
                try {
                    val dm = getSystemService(Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
                    val req = android.app.DownloadManager.Request(android.net.Uri.parse(url))
                        .setTitle(title)
                        .setDescription("正在下载更新包…")
                        .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        .setDestinationInExternalPublicDir(android.os.Environment.DIRECTORY_DOWNLOADS, "cyanweather_update.apk")
                        .setMimeType("application/vnd.android.package-archive")
                    dm.enqueue(req)
                    trace(this, "download enqueued: $url")
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("dl-error", e.message ?: "下载启动失败", null)
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
                trace(this, "NO PERMISSION")
                result?.let { deliver { it.error("no-permission", "定位权限未授予，请在系统设置中允许", null) } }
                return
            }
            trace(this, "perm ok")
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            trace(this, "lm ok")
            val best0 = bestLastKnown(lm)
            trace(this, "bestLastKnown: " + (best0?.let { "${it.latitude},${it.longitude} @${(System.currentTimeMillis()-it.time)/60000}min ${it.provider}" } ?: "none"))

            // 1) 最近已知位置（passive 会吸收其它 App 的定位结果）
            bestLastKnown(lm)?.let { last ->
                val ageMin = (System.currentTimeMillis() - last.time) / 60000L
                android.util.Log.i("GPS", "lastKnown age=${ageMin}min ${last.latitude},${last.longitude} (${last.provider})")
                if (ageMin < 120) { persist(last); result?.let { runOnUiThread { it.success(toJson(last)) } }; return }
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
            trace(this, "resolved: " + (chosen?.latitude?.toString() ?: "null") + "," + (chosen?.longitude?.toString() ?: "null"))
            if (chosen != null) {
                persist(chosen)
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
            trace(this, "resolve EXC: $e")
            result?.let { runOnUiThread { it.error("error", e.message ?: "定位异常", null) } }
        }
    }

    private fun toJson(l: Location): String {
        val sw = StringWriter(); val w = JsonWriter(sw)
        w.beginObject().name("latitude").value(l.latitude).name("longitude").value(l.longitude).endObject().close()
        return sw.toString()
    }
}
