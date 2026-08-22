package com.cyanweather.app.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class LocationHelper(private val context: Context) {

    private val locationManager: LocationManager? =
        context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

    fun isLocationEnabled(): Boolean {
        val lm = locationManager ?: return false
        return listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .any { provider -> runCatching { lm.isProviderEnabled(provider) }.getOrDefault(false) }
    }

    suspend fun requestFreshLocation(): Location? = withContext(Dispatchers.IO) {
        if (!hasPermission()) return@withContext null
        val lm = locationManager ?: return@withContext null

        val providers = getAvailableProviders(lm)
        if (providers.isEmpty()) return@withContext null

        val lastKnown = getBestLocation(lm)

        for (provider in providers) {
            try {
                val freshLoc = requestSingleUpdate(lm, provider, 5_000)
                if (freshLoc != null && (lastKnown == null || freshLoc.accuracy < lastKnown.accuracy)) {
                    return@withContext freshLoc
                }
            } catch (_: Exception) { }
        }

        lastKnown
    }

    fun getBestLocation(): Location? {
        val lm = locationManager ?: return null
        return getBestLocation(lm)
    }

    private fun getBestLocation(lm: LocationManager): Location? {
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        val all = providers.mapNotNull { p ->
            runCatching { lm.getLastKnownLocation(p) }.getOrNull()
        }
        if (all.isEmpty()) return null
        val now = System.currentTimeMillis()
        val fresh = all.filter { now - it.time < 10 * 60 * 1000L }
        val pool = if (fresh.isNotEmpty()) fresh else all
        return pool.minByOrNull { it.accuracy ?: Float.MAX_VALUE }
    }

    private fun getAvailableProviders(lm: LocationManager): List<String> {
        val result = mutableListOf<String>()
        if (runCatching { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) }.getOrDefault(false)) {
            result.add(LocationManager.NETWORK_PROVIDER)
        }
        if (runCatching { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) }.getOrDefault(false)) {
            result.add(LocationManager.GPS_PROVIDER)
        }
        if (runCatching { lm.isProviderEnabled(LocationManager.PASSIVE_PROVIDER) }.getOrDefault(false)) {
            result.add(LocationManager.PASSIVE_PROVIDER)
        }
        return result
    }

    private suspend fun requestSingleUpdate(
        lm: LocationManager,
        provider: String,
        timeoutMs: Long
    ): Location? = withContext(Dispatchers.IO) {
        val latch = CountDownLatch(1)
        var result: Location? = null

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (latch.count > 0) {
                    result = location
                    latch.countDown()
                }
            }
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        try {
            lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
            lm.removeUpdates(listener)
        } catch (_: Exception) { }

        result
    }
}
