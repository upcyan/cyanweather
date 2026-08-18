package com.cyanweather.app.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.cyanweather.app.data.AppSettings
import com.cyanweather.app.data.SettingsStore
import com.cyanweather.app.data.WeatherRepository
import com.cyanweather.app.location.LocationHelper
import com.cyanweather.app.model.NmcCityItem
import com.cyanweather.app.model.NmcProvinceItem
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
    val selectedProvince: String? = null
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val context = app
    private val settingsStore = SettingsStore
    private val locationHelper = LocationHelper(context)
    private val repository = WeatherRepository(context, locationHelper)

    var ui by mutableStateOf(UiState())
        private set

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
                val cache = settingsStore.loadCache(context)
                val msg = e.message ?: "网络错误"
                ui = ui.copy(
                    loading = false,
                    refreshing = false,
                    error = msg,
                    weather = cache ?: ui.weather
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