package com.cyanweather.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import com.cyanweather.app.ui.AppViewModel
import com.cyanweather.app.ui.CityPickerScreen
import com.cyanweather.app.ui.CyanWeatherTheme
import com.cyanweather.app.ui.HomeScreen
import com.cyanweather.app.ui.LocalFontScale
import com.cyanweather.app.ui.RainForecastScreen
import com.cyanweather.app.ui.Screen
import com.cyanweather.app.ui.SettingsScreen
import com.cyanweather.app.ui.UiState

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels()

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                vm.saveCurrentLocation()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            permissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        } else {
            vm.saveCurrentLocation()
        }

        setContent {
            val state by vm::ui
            CyanWeatherTheme {
                CompositionLocalProvider(LocalFontScale provides state.fontScale) {
                    AppScreen(
                        state = state,
                        onSettings = vm::openSettings,
                        onRefresh = vm::refresh,
                        onOpenCityPicker = vm::openCityPicker,
                        onBackFromSettings = vm::closeSettings,
                        onSource = vm::setSource,
                        onCaiyunMode = vm::setCaiyunMode,
                        onToken = vm::setToken,
                        onCaiyunV3Key = vm::setCaiyunV3Key,
                        onCaiyunV3Secret = vm::setCaiyunV3Secret,
                        onFont = vm::setFont,
                        onRefreshInterval = vm::setRefreshInterval,
                        onExtendedForecast = vm::setExtendedForecast,
                        onExtendedDays = vm::setExtendedDays,
                        onGetYesterday = vm::setGetYesterday,
                        onUseGps = vm::setUseGps,
                        onCityBack = vm::closeCityPicker,
                        onProvinceClick = vm::loadCities,
                        onCityClick = vm::selectCity,
                        onBackToProvince = vm::backFromCities,
                        onUseCurrentLocation = vm::useCurrentLocation,
                        onOpenRainForecast = vm::openRainForecast,
                        onBackFromRainForecast = vm::closeRainForecast,
                        onEnsureAllCities = vm::ensureAllCities
                    )
                }
            }
        }
    }
}

@Composable
private fun AppScreen(
    state: UiState,
    onSettings: () -> Unit,
    onRefresh: () -> Unit,
    onOpenCityPicker: () -> Unit,
    onBackFromSettings: () -> Unit,
    onSource: (String) -> Unit,
    onCaiyunMode: (String) -> Unit,
    onToken: (String) -> Unit,
    onCaiyunV3Key: (String) -> Unit,
    onCaiyunV3Secret: (String) -> Unit,
    onFont: (String) -> Unit,
    onRefreshInterval: (String) -> Unit,
    onExtendedForecast: (Boolean) -> Unit,
    onExtendedDays: (Int) -> Unit,
    onGetYesterday: (Boolean) -> Unit,
    onUseGps: (Boolean) -> Unit,
    onCityBack: () -> Unit,
    onProvinceClick: (String) -> Unit,
    onCityClick: (String, String) -> Unit,
    onBackToProvince: () -> Unit,
    onUseCurrentLocation: () -> Unit,
    onOpenRainForecast: () -> Unit,
    onBackFromRainForecast: () -> Unit,
    onEnsureAllCities: () -> Unit
) {
    when (state.screen) {
        is Screen.Home -> HomeScreen(
            state,
            onSettings,
            onRefresh,
            onOpenCityPicker,
            onOpenRainForecast
        )
        is Screen.Settings -> SettingsScreen(
            settings = state.settings,
            onBack = onBackFromSettings,
            onSource = onSource,
            onCaiyunMode = onCaiyunMode,
            onToken = onToken,
            onCaiyunV3Key = onCaiyunV3Key,
            onCaiyunV3Secret = onCaiyunV3Secret,
            onFont = onFont,
            onRefreshInterval = onRefreshInterval,
            onExtendedForecast = onExtendedForecast,
            onExtendedDays = onExtendedDays,
            onGetYesterday = onGetYesterday,
            onUseGps = onUseGps,
            onOpenCityPicker = onOpenCityPicker
        )
        is Screen.CityPicker -> CityPickerScreen(
            provinces = state.provinces,
            cities = state.cities,
            allCities = state.allCities,
            allCitiesLoading = state.allCitiesLoading,
            provinceLoading = state.provinceLoading,
            cityLoading = state.cityLoading,
            selectedProvince = state.selectedProvince,
            onBack = onCityBack,
            onProvinceClick = onProvinceClick,
            onCityClick = onCityClick,
            onBackToProvince = onBackToProvince,
            onUseCurrentLocation = onUseCurrentLocation,
            onEnsureAllCities = onEnsureAllCities
        )
        is Screen.RainForecast -> RainForecastScreen(
            weather = state.weather,
            onBack = onBackFromRainForecast
        )
    }
}