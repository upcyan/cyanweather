package com.cyanweather.app.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

class LocationHelper(private val context: Context) {

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

    suspend fun requestFreshLocation(): Location? {
        if (!hasPermission()) return null
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null

        val networkEnabled = runCatching { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) }.getOrDefault(false)
        val gpsEnabled = runCatching { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false)

        if (!networkEnabled && !gpsEnabled) return null

        val lastKnown = getBestLocation()
        val handler = android.os.Handler(Looper.getMainLooper())

        return suspendCoroutine { cont ->
            var resumed = false
            fun safeResume(loc: Location?) {
                if (!resumed) {
                    resumed = true
                    cont.resume(loc)
                }
            }

            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    lm.removeUpdates(this)
                    handler.removeCallbacksAndMessages(null)
                    safeResume(location)
                }
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            val timeoutRunnable = Runnable {
                lm.removeUpdates(listener)
                safeResume(lastKnown)
            }

            try {
                if (networkEnabled) {
                    lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                } else {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0L, 0f, listener, Looper.getMainLooper())
                }
                handler.postDelayed(timeoutRunnable, 8_000)
            } catch (e: Exception) {
                safeResume(lastKnown)
            }
        }
    }

    private fun getBestLocation(): Location? {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        val all = providers.mapNotNull { p ->
            runCatching { lm.getLastKnownLocation(p) }.getOrNull()
        }
        if (all.isEmpty()) return null
        val now = System.currentTimeMillis()
        val fresh = all.filter { now - it.time < 10 * 60 * 1000L }
        val pool = if (fresh.isNotEmpty()) fresh else all
        return pool.minByOrNull { it.accuracy ?: Float.MAX_VALUE }
    }
}
