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
import com.cyanweather.shared.model.NmcCityItem
import com.cyanweather.shared.model.NmcProvinceItem
import com.cyanweather.app.update.UpdateChecker
import com.cyanweather.app.update.UpdateResult
import com.cyanweather.shared.data.OpenMeteoApi
import com.cyanweather.shared.model.WeatherData
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
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
    val locationNotice: String? = null,
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
    val updateDownloadId: Long? = null,
    val updateProgressText: String? = null
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val context = app
    private val settingsStore = SettingsStore
    private val locationHelper = LocationHelper(context)
    private val repository = WeatherRepository(context, locationHelper)
    private var updateFileName: String? = null

    var ui by mutableStateOf(UiState())
        private set

    private var lastPauseTime = 0L
    private var settingsLoaded = false
    private var refreshJob: kotlinx.coroutines.Job? = null

    init {
        viewModelScope.launch {
            settingsStore.flow(context).collect { s ->
                val firstLoad = !settingsLoaded
                settingsLoaded = true
                ui = ui.copy(
                    settings = s,
                    fontScale = when (s.fontSize) {
                        "standard" -> 1.0f
                        "xlarge" -> 1.6f
                        else -> 1.3f
                    }
                )
                // 首次拿到持久化设置后再检查更新，否则读到默认值，用户关闭的开关不生效
                if (firstLoad && s.autoCheckUpdate) checkUpdate()
            }
        }
        viewModelScope.launch {
            ui = ui.copy(locationNotice = refreshLocation())
            refresh()
        }
        startAutoRefresh()
        observeLifecycle()
    }

    private fun checkUpdate() {
        viewModelScope.launch {
            val result = UpdateChecker.checkForUpdate(context)
            if (result is UpdateResult.UpdateAvailable) {
                ui = ui.copy(updateResult = result)
            }
        }
    }

    fun manualCheckUpdate() {
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
            updateFileName = fileName
            ui = ui.copy(updateDownloading = true, updateDownloadId = downloadId)
            // DownloadManager 不弹安装框：必须在应用内轮询下载状态，完成后主动拉起安装器；
            // waitMs 设长（1天）保证轮询持续到下载完成，进度会实时展示在 UI 上
            checkDownloadComplete(waitMs = 24 * 60 * 60 * 1000L)
        }
    }

    fun checkDownloadComplete(waitMs: Long = 0L) {
        val id = ui.updateDownloadId ?: return
        viewModelScope.launch {
            val result = try {
                pollDownload(id, waitMs)
            } catch (_: Exception) {
                null
            }
            ui = ui.copy(updateProgressText = null)
            if (result == false) {
                // 超时未完成：保留 downloadId，回到前台时继续检查
                ui = ui.copy(updateDownloading = false)
                return@launch
            }
            val fileName = updateFileName
            updateFileName = null
            ui = ui.copy(updateDownloading = false, updateDownloadId = null)
            if (result == true && fileName != null) {
                try {
                    val fileUri = com.cyanweather.app.update.UpdateChecker.getApkFileUri(context, fileName)
                    com.cyanweather.app.update.UpdateChecker.installApk(context, fileUri)
                } catch (_: Exception) { }
            }
        }
    }

    /** 轮询下载状态：成功返回 true；超时返回 false；失败抛异常。 */
    private suspend fun pollDownload(id: Long, waitMs: Long): Boolean {
        val dm = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
        val deadline = System.currentTimeMillis() + waitMs
        while (true) {
            dm.query(android.app.DownloadManager.Query().setFilterById(id))?.use { c ->
                if (c.moveToFirst()) {
                    val statusIdx = c.getColumnIndex(android.app.DownloadManager.COLUMN_STATUS)
                    val reasonIdx = c.getColumnIndex(android.app.DownloadManager.COLUMN_REASON)
                    if (statusIdx >= 0) {
                        when (c.getInt(statusIdx)) {
                            android.app.DownloadManager.STATUS_SUCCESSFUL -> return true
                            android.app.DownloadManager.STATUS_FAILED -> throw RuntimeException(
                                "下载失败" + if (reasonIdx >= 0) "（code=${c.getInt(reasonIdx)}）" else ""
                            )
                        }
                    }
                    if (waitMs > 0) {
                        val doneIdx = c.getColumnIndex(android.app.DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                        val totalIdx = c.getColumnIndex(android.app.DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                        if (doneIdx >= 0 && totalIdx >= 0) {
                            val done = c.getLong(doneIdx)
                            val total = c.getLong(totalIdx)
                            if (total > 0) {
                                val text = "已下载 ${done * 100 / total}%"
                                if (ui.updateProgressText != text) ui = ui.copy(updateProgressText = text)
                            }
                        }
                    }
                }
            }
            if (System.currentTimeMillis() >= deadline) return false
            delay(1_000)
        }
    }

    private fun observeLifecycle() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onPause(owner: LifecycleOwner) {
                lastPauseTime = System.currentTimeMillis()
            }
            override fun onResume(owner: LifecycleOwner) {
                if (ui.updateDownloadId != null) checkDownloadComplete()
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
        // 新请求取消旧的进行中请求，避免并发刷新竞态覆盖，也保证设置变更后的重刷用最新配置
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            ui = ui.copy(refreshing = true, error = null, loading = ui.weather == null)
            try {
                val locationNotice = refreshLocation()
                val w = repository.loadWeather()
                settingsStore.saveCache(context, w)
                ui = ui.copy(weather = w, loading = false, refreshing = false, error = null, locationNotice = locationNotice)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                val msg = e.message ?: "网络错误"
                ui = ui.copy(loading = false, refreshing = false, error = msg)
            }
        }
    }

    fun openSettings() { ui = ui.copy(screen = Screen.Settings) }
    fun closeSettings() { ui = ui.copy(screen = Screen.Home) }
    /** Handles the Android system back button without exiting while a child screen is open. */
    fun handleBack(): Boolean = when (ui.screen) {
        is Screen.Home -> false
        is Screen.Settings -> { closeSettings(); true }
        is Screen.RainForecast -> { closeRainForecast(); true }
        is Screen.CityPicker -> {
            if (ui.selectedProvince != null) backFromCities() else closeCityPicker()
            true
        }
    }
    fun openCityPicker() {
        ui = ui.copy(screen = Screen.CityPicker)
        if (ui.provinces.isEmpty()) loadProvinces()
    }
    fun closeCityPicker() { ui = ui.copy(screen = Screen.Home) }

    fun setSource(source: String) = launchEdit { settingsStore.setSource(context, source); refresh() }

    fun setWeatherSources(sources: List<String>) = launchEdit {
        settingsStore.setWeatherSources(context, sources)
        refresh()
    }

    fun setCaiyunMode(mode: String) = launchEdit {
        settingsStore.setCaiyunMode(context, mode)
        refresh()
    }

    fun setCaiyunV3Key(key: String) = launchEdit { settingsStore.setCaiyunV3Key(context, key) }

    fun setCaiyunV3Secret(secret: String) = launchEdit { settingsStore.setCaiyunV3Secret(context, secret) }

    fun setToken(token: String) = launchEdit { settingsStore.setToken(context, token) }

    fun setQWeatherHost(host: String) = launchEdit { settingsStore.setQWeatherHost(context, host) }

    fun setQWeatherKey(key: String) = launchEdit { settingsStore.setQWeatherKey(context, key) }

    fun setFont(size: String) = launchEdit { settingsStore.setFont(context, size) }

    fun setRefreshInterval(v: String) = launchEdit { settingsStore.setRefreshInterval(context, v) }

    fun setExtendedForecast(v: Boolean) = launchEdit { settingsStore.setExtendedForecast(context, v) }

    fun setExtendedDays(v: Int) = launchEdit { settingsStore.setExtendedDays(context, v) }

    fun setGetYesterday(v: Boolean) = launchEdit { settingsStore.setGetYesterday(context, v) }

    fun setAutoCheckUpdate(v: Boolean) = launchEdit { settingsStore.setAutoCheckUpdate(context, v) }

    fun setUseGps(v: Boolean) = launchEdit {
        settingsStore.setUseGps(context, v)
        ui = ui.copy(settings = ui.settings.copy(useGps = v), locationNotice = null)
        refresh()
    }

    fun saveLatLng(lat: Double, lng: Double) = launchEdit { settingsStore.setLatLng(context, lat, lng) }

    fun saveCurrentLocation() {
        viewModelScope.launch {
            ui = ui.copy(locationNotice = refreshLocation())
        }
    }

    private suspend fun refreshLocation(): String? {
        val current = settingsStore.flow(context).first()
        if (!current.useGps) return null
        if (!locationHelper.hasPermission()) return "未获取定位权限，请手动选择城市；当前默认显示北京天气"
        if (!locationHelper.isLocationEnabled()) return "定位服务未开启，当前显示默认城市北京"
        val loc = locationHelper.requestFreshLocation()
            ?: return "定位失败，请检查网络/GPS后重试；当前显示默认城市北京"
        settingsStore.setLatLng(context, loc.latitude, loc.longitude)
        if (!current.manualCity) {
            try {
                val name = OpenMeteoApi.reverseGeocode(loc.latitude, loc.longitude)
                if (name.isNotBlank() && name != current.cityName) {
                    settingsStore.setCity(context, name, current.cityCode, manual = false)
                }
            } catch (_: Exception) { }
        }
        return null
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
