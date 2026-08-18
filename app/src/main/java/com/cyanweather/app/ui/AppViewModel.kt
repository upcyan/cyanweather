package com.cyanweather.app.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.viewModelScope
import com.cyanweather.app.data.AppSettings
import com.cyanweather.app.data.SettingsStore
import com.cyanweather.app.data.WeatherRepository
import com.cyanweather.app.location.LocationHelper
import com.cyanweather.app.model.NmcCityItem
import com.cyanweather.app.model.NmcProvinceItem
import com.cyanweather.app.update.UpdateChecker
import com.cyanweather.app.update.UpdateResult
import com.cyanweather.app.model.WeatherData
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

sealed class Screen {
    object Home : Screen()
    object Settings : Screen()
    object CityPicker : Screen()
    object RainForecast : Screen()
}

data class UiState(
    val screen: Screen = Screen.Home,
    val settings: AppSettings = AppSettings(),
    val fontScale: Float = 1.3f,
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val error: String? = null,
    val weather: WeatherData? = null,
    val provinces: List<NmcProvinceItem> = emptyList(),
    val cities: List<NmcCityItem> = emptyList(),
    val allCities: List<NmcCityItem> = emptyList(),
    val allCitiesLoading: Boolean = false,
    val provinceLoading: Boolean = false,
    val cityLoading: Boolean = false,
    val selectedProvince: String? = null,
    val updateResult: UpdateResult? = null,
    val updateDownloading: Boolean = false,
    val updateDownloadId: Long? = null
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val context = app
    private val settingsStore = SettingsStore
    private val locationHelper = LocationHelper(context)
    private val repository = WeatherRepository(context, locationHelper)

    var ui by mutableStateOf(UiState())
        private set

    private var lastPauseTime = 0L

    init {
        viewModelScope.launch {
            settingsStore.flow(context).collect { s ->
                ui = ui.copy(
                    settings = s,
                    fontScale = when (s.fontSize) {
                        "standard" -> 1.0f
                        "xlarge" -> 1.6f
                        else -> 1.3f
                    }
                )
            }
        }
        refresh()
        startAutoRefresh()
        observeLifecycle()
        if (ui.settings.autoCheckUpdate) checkUpdate()
    }

    private fun checkUpdate() {
        viewModelScope.launch {
            val result = UpdateChecker.checkForUpdate(context)
            if (result is UpdateResult.UpdateAvailable) {
                ui = ui.copy(updateResult = result)
            }
        }
    }

    fun dismissUpdate() {
        ui = ui.copy(updateResult = null)
    }

    fun confirmUpdate() {
        val update = ui.updateResult as? UpdateResult.UpdateAvailable ?: return
        ui = ui.copy(updateResult = null)
        viewModelScope.launch {
            val url = update.downloadUrl
            if (url.isBlank()) return@launch
            val fileName = "cyanweather-v${update.version}.apk"
            val downloadId = com.cyanweather.app.update.UpdateChecker.downloadAndInstall(context, url, fileName)
            ui = ui.copy(updateDownloading = true, updateDownloadId = downloadId)
        }
    }

    fun checkDownloadComplete() {
        val id = ui.updateDownloadId ?: return
        val dm = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
        val query = android.app.DownloadManager.Query().setFilterById(id)
        val cursor = dm.query(query)
        cursor?.use { c ->
            if (c.moveToFirst()) {
                val statusIdx = c.getColumnIndex(android.app.DownloadManager.COLUMN_STATUS)
                if (statusIdx >= 0) {
                    val status = c.getInt(statusIdx)
                    if (status == android.app.DownloadManager.STATUS_SUCCESSFUL) {
                        val version = (ui.updateResult as? UpdateResult.UpdateAvailable)?.version ?: ""
                        val fileUri = com.cyanweather.app.update.UpdateChecker.getApkFileUri(context, "cyanweather-v${version}.apk")
                        com.cyanweather.app.update.UpdateChecker.installApk(context, fileUri)
                        ui = ui.copy(updateDownloading = false, updateDownloadId = null)
                    } else if (status == android.app.DownloadManager.STATUS_FAILED) {
                        ui = ui.copy(updateDownloading = false, updateDownloadId = null)
                    }
                }
            }
        }
    }

    private fun observeLifecycle() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onPause(owner: LifecycleOwner) {
                lastPauseTime = System.currentTimeMillis()
            }
            override fun onResume(owner: LifecycleOwner) {
                if (ui.settings.refreshInterval == "on_resume") {
                    val elapsed = System.currentTimeMillis() - lastPauseTime
                    if (lastPauseTime == 0L || elapsed > 30_000) {
                        refresh()
                    }
                }
            }
        })
    }

    fun fontScaleOf(): Float = ui.fontScale

    fun refresh() {
        viewModelScope.launch {
            ui = ui.copy(refreshing = true, error = null, loading = ui.weather == null)
            try {
                val w = repository.loadWeather()
                settingsStore.saveCache(context, w)
                ui = ui.copy(weather = w, loading = false, refreshing = false)
            } catch (e: Exception) {
                val msg = e.message ?: "网络错误"
                ui = ui.copy(
                    loading = false,
                    refreshing = false,
                    error = msg
                )
            }
        }
    }

    fun openSettings() { ui = ui.copy(screen = Screen.Settings) }
    fun closeSettings() { ui = ui.copy(screen = Screen.Home) }
    fun openCityPicker() {
        ui = ui.copy(screen = Screen.CityPicker)
        if (ui.provinces.isEmpty()) loadProvinces()
    }
    fun closeCityPicker() { ui = ui.copy(screen = Screen.Home) }

    fun setSource(source: String) = launchEdit { settingsStore.setSource(context, source); refresh() }

    fun setCaiyunMode(mode: String) = launchEdit {
        settingsStore.setCaiyunMode(context, mode)
        refresh()
    }

    fun setCaiyunV3Key(key: String) = launchEdit { settingsStore.setCaiyunV3Key(context, key) }

    fun setCaiyunV3Secret(secret: String) = launchEdit { settingsStore.setCaiyunV3Secret(context, secret) }

    fun setToken(token: String) = launchEdit { settingsStore.setToken(context, token) }

    fun setFont(size: String) = launchEdit { settingsStore.setFont(context, size) }

    fun setRefreshInterval(v: String) = launchEdit { settingsStore.setRefreshInterval(context, v) }

    fun setExtendedForecast(v: Boolean) = launchEdit { settingsStore.setExtendedForecast(context, v) }

    fun setExtendedDays(v: Int) = launchEdit { settingsStore.setExtendedDays(context, v) }

    fun setGetYesterday(v: Boolean) = launchEdit { settingsStore.setGetYesterday(context, v) }

    fun setAutoCheckUpdate(v: Boolean) = launchEdit { settingsStore.setAutoCheckUpdate(context, v) }

    fun setUseGps(v: Boolean) = launchEdit { settingsStore.setUseGps(context, v) }

    fun saveLatLng(lat: Double, lng: Double) = launchEdit { settingsStore.setLatLng(context, lat, lng) }

    fun saveCurrentLocation() {
        val loc = locationHelper.getBestLocation() ?: return
        saveLatLng(loc.latitude, loc.longitude)
    }

    fun selectCity(name: String, code: String) {
        viewModelScope.launch {
            settingsStore.setCity(context, name, code, manual = true)
            ui = ui.copy(screen = Screen.Home, selectedProvince = null)
            refresh()
        }
    }

    fun useCurrentLocation() {
        viewModelScope.launch {
            settingsStore.setManualCity(context, false)
            settingsStore.setUseGps(context, true)
            ui = ui.copy(screen = Screen.Home, selectedProvince = null)
            refresh()
        }
    }

    fun openRainForecast() { ui = ui.copy(screen = Screen.RainForecast) }
    fun closeRainForecast() { ui = ui.copy(screen = Screen.Home) }

    fun loadProvinces() {
        viewModelScope.launch {
            ui = ui.copy(provinceLoading = true)
            try {
                ui = ui.copy(provinces = repository.loadProvinces(), provinceLoading = false)
            } catch (e: Exception) {
                ui = ui.copy(provinceLoading = false)
            }
        }
    }

    fun loadCities(provinceCode: String) {
        viewModelScope.launch {
            ui = ui.copy(cityLoading = true, selectedProvince = provinceCode)
            try {
                ui = ui.copy(cities = repository.loadCities(provinceCode), cityLoading = false)
            } catch (e: Exception) {
                ui = ui.copy(cityLoading = false, cities = emptyList())
            }
        }
    }

    fun ensureAllCities() {
        if (ui.allCities.isNotEmpty() || ui.allCitiesLoading) return
        viewModelScope.launch {
            ui = ui.copy(allCitiesLoading = true)
            try {
                ui = ui.copy(allCities = repository.loadAllCities(), allCitiesLoading = false)
            } catch (e: Exception) {
                ui = ui.copy(allCitiesLoading = false)
            }
        }
    }

    fun backFromCities() {
        ui = ui.copy(selectedProvince = null, cities = emptyList())
    }

    private fun launchEdit(block: suspend () -> Unit) {
        viewModelScope.launch { block() }
    }

    private fun startAutoRefresh() {
        viewModelScope.launch {
            while (true) {
                val minutes = ui.settings.refreshInterval.toIntOrNull()
                if (minutes != null && minutes > 0) {
                    delay(minutes * 60 * 1000L)
                    refresh()
                } else {
                    delay(60 * 1000L)
                }
            }
        }
    }
}