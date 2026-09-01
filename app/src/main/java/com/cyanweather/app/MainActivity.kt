package com.cyanweather.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.graphics.Color
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
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
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { vm.refresh() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) window.isNavigationBarContrastEnforced = false
        WindowInsetsControllerCompat(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (!vm.handleBack()) finish()
            }
        })

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
                        onWeatherSources = vm::setWeatherSources,
                        onCaiyunMode = vm::setCaiyunMode,
                        onToken = vm::setToken,
                        onCaiyunV3Key = vm::setCaiyunV3Key,
                        onCaiyunV3Secret = vm::setCaiyunV3Secret,
                        onQWeatherHost = vm::setQWeatherHost,
                        onQWeatherKey = vm::setQWeatherKey,
                        onFont = vm::setFont,
                        onRefreshInterval = vm::setRefreshInterval,
                        onExtendedForecast = vm::setExtendedForecast,
                        onExtendedDays = vm::setExtendedDays,
                        onGetYesterday = vm::setGetYesterday,
                        onAutoCheckUpdate = vm::setAutoCheckUpdate,
                        onUseGps = vm::setUseGps,
                        onCityBack = vm::closeCityPicker,
                        onProvinceClick = vm::loadCities,
                        onCityClick = vm::selectCity,
                        onBackToProvince = vm::backFromCities,
                        onUseCurrentLocation = vm::useCurrentLocation,
                        onOpenRainForecast = vm::openRainForecast,
                        onBackFromRainForecast = vm::closeRainForecast,
                        onEnsureAllCities = vm::ensureAllCities,
                        onConfirmUpdate = vm::confirmUpdate,
                        onDismissUpdate = vm::dismissUpdate,
                        onManualCheckUpdate = vm::manualCheckUpdate
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (vm.ui.settings.useGps) {
            if (hasLocationPermission()) vm.refresh()
            else ensureLocationPermission()
        } else {
            vm.refresh()
        }
    }

    private fun ensureLocationPermission() {
        if (!hasLocationPermission()) requestLocationPermission()
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun requestLocationPermission() {
        permissionLauncher.launch(arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ))
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
    onWeatherSources: (List<String>) -> Unit,
    onCaiyunMode: (String) -> Unit,
    onToken: (String) -> Unit,
    onCaiyunV3Key: (String) -> Unit,
    onCaiyunV3Secret: (String) -> Unit,
    onQWeatherHost: (String) -> Unit,
    onQWeatherKey: (String) -> Unit,
    onFont: (String) -> Unit,
    onRefreshInterval: (String) -> Unit,
    onExtendedForecast: (Boolean) -> Unit,
    onExtendedDays: (Int) -> Unit,
    onGetYesterday: (Boolean) -> Unit,
    onAutoCheckUpdate: (Boolean) -> Unit,
    onUseGps: (Boolean) -> Unit,
    onCityBack: () -> Unit,
    onProvinceClick: (String) -> Unit,
    onCityClick: (String, String) -> Unit,
    onBackToProvince: () -> Unit,
    onUseCurrentLocation: () -> Unit,
    onOpenRainForecast: () -> Unit,
    onBackFromRainForecast: () -> Unit,
    onEnsureAllCities: () -> Unit,
    onConfirmUpdate: () -> Unit,
    onDismissUpdate: () -> Unit,
    onManualCheckUpdate: () -> Unit
) {
    when (state.screen) {
        is Screen.Home -> HomeScreen(
            state,
            onSettings,
            onRefresh,
            onOpenCityPicker,
            onOpenRainForecast,
            onConfirmUpdate,
            onDismissUpdate
        )
        is Screen.Settings -> SettingsScreen(
            settings = state.settings,
            onBack = onBackFromSettings,
            onSource = onSource,
            onWeatherSources = onWeatherSources,
            onCaiyunMode = onCaiyunMode,
            onToken = onToken,
            onCaiyunV3Key = onCaiyunV3Key,
            onCaiyunV3Secret = onCaiyunV3Secret,
            onQWeatherHost = onQWeatherHost,
            onQWeatherKey = onQWeatherKey,
            onFont = onFont,
            onRefreshInterval = onRefreshInterval,
            onExtendedForecast = onExtendedForecast,
            onExtendedDays = onExtendedDays,
            onGetYesterday = onGetYesterday,
            onAutoCheckUpdate = onAutoCheckUpdate,
            onUseGps = onUseGps,
            onOpenCityPicker = onOpenCityPicker,
            onManualCheckUpdate = onManualCheckUpdate
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
