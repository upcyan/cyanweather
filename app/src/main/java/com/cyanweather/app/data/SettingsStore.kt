package com.cyanweather.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.cyanweather.shared.model.WeatherData
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

data class AppSettings(
    val source: String = "openmeteo",
    val caiyunMode: String = "v1",
    val caiyunToken: String = "",
    val caiyunV3Key: String = "",
    val caiyunV3Secret: String = "",
    val cityName: String = "北京",
    val cityCode: String = "",
    val manualCity: Boolean = false,
    val fontSize: String = "large",
    val refreshInterval: String = "30",
    val extendedForecast: Boolean = false,
    val extendedDays: Int = 3,
    val getYesterday: Boolean = false,
    val autoCheckUpdate: Boolean = true,
    val useGps: Boolean = true,
    val lat: Double = 39.9042,
    val lng: Double = 116.4074
)

private val Context.dataStore by preferencesDataStore(name = "settings")

object SettingsStore {
    private val KEY_SOURCE = stringPreferencesKey("source")
    private val KEY_CAIYUN_MODE = stringPreferencesKey("caiyun_mode")
    private val KEY_CAIYUN_ENABLED = booleanPreferencesKey("caiyun_enabled")
    private val KEY_TOKEN = stringPreferencesKey("caiyun_token")
    private val KEY_CAIYUN_V3_KEY = stringPreferencesKey("caiyun_v3_key")
    private val KEY_CAIYUN_V3_SECRET = stringPreferencesKey("caiyun_v3_secret")
    private val KEY_CITY_NAME = stringPreferencesKey("city_name")
    private val KEY_CITY_CODE = stringPreferencesKey("city_code")
    private val KEY_MANUAL_CITY = booleanPreferencesKey("manual_city")
    private val KEY_FONT = stringPreferencesKey("font_size")
    private val KEY_AUTO = booleanPreferencesKey("auto_refresh")
    private val KEY_INTERVAL = stringPreferencesKey("refresh_interval")
    private val KEY_EXTENDED = booleanPreferencesKey("extended_forecast")
    private val KEY_EXTENDED_DAYS = longPreferencesKey("extended_days")
    private val KEY_GET_YESTERDAY = booleanPreferencesKey("get_yesterday")
    private val KEY_AUTO_UPDATE = booleanPreferencesKey("auto_check_update")
    private val KEY_GPS = booleanPreferencesKey("use_gps")
    private val KEY_LAT = doublePreferencesKey("lat")
    private val KEY_LNG = doublePreferencesKey("lng")
    private val KEY_CACHE = stringPreferencesKey("cached_weather")
    private val KEY_CACHE_TIME = longPreferencesKey("cache_time")

    private val json = Json { ignoreUnknownKeys = true }

    fun flow(context: Context): Flow<AppSettings> = context.dataStore.data.map { p ->
        AppSettings(
            source = p[KEY_SOURCE] ?: "openmeteo",
            caiyunMode = p[KEY_CAIYUN_MODE] ?: if (p[KEY_CAIYUN_ENABLED] == true) "v1" else "v1",
            caiyunToken = p[KEY_TOKEN] ?: "",
            caiyunV3Key = p[KEY_CAIYUN_V3_KEY] ?: "",
            caiyunV3Secret = p[KEY_CAIYUN_V3_SECRET] ?: "",
            cityName = p[KEY_CITY_NAME] ?: "北京",
            cityCode = p[KEY_CITY_CODE] ?: "",
            manualCity = p[KEY_MANUAL_CITY] ?: false,
            fontSize = p[KEY_FONT] ?: "large",
            refreshInterval = p[KEY_INTERVAL] ?: if (p[KEY_AUTO] == false) "off" else "30",
            extendedForecast = p[KEY_EXTENDED] ?: false,
            extendedDays = (p[KEY_EXTENDED_DAYS] ?: 3).toInt(),
            getYesterday = p[KEY_GET_YESTERDAY] ?: false,
            autoCheckUpdate = p[KEY_AUTO_UPDATE] ?: true,
            useGps = p[KEY_GPS] ?: true,
            lat = p[KEY_LAT] ?: 39.9042,
            lng = p[KEY_LNG] ?: 116.4074
        )
    }

    suspend fun setSource(context: Context, v: String) = context.dataStore.edit { it[KEY_SOURCE] = v }

    suspend fun setCaiyunMode(context: Context, v: String) =
        context.dataStore.edit { it[KEY_CAIYUN_MODE] = v }

    suspend fun setToken(context: Context, v: String) = context.dataStore.edit { it[KEY_TOKEN] = v }

    suspend fun setCaiyunV3Key(context: Context, v: String) =
        context.dataStore.edit { it[KEY_CAIYUN_V3_KEY] = v }

    suspend fun setCaiyunV3Secret(context: Context, v: String) =
        context.dataStore.edit { it[KEY_CAIYUN_V3_SECRET] = v }

    suspend fun setCity(context: Context, name: String, code: String, manual: Boolean) =
        context.dataStore.edit { it[KEY_CITY_NAME] = name; it[KEY_CITY_CODE] = code; it[KEY_MANUAL_CITY] = manual }

    suspend fun setManualCity(context: Context, v: Boolean) =
        context.dataStore.edit { it[KEY_MANUAL_CITY] = v }

    suspend fun setFont(context: Context, v: String) = context.dataStore.edit { it[KEY_FONT] = v }

    suspend fun setRefreshInterval(context: Context, v: String) =
        context.dataStore.edit { it[KEY_INTERVAL] = v }

    suspend fun setExtendedForecast(context: Context, v: Boolean) =
        context.dataStore.edit { it[KEY_EXTENDED] = v }

    suspend fun setExtendedDays(context: Context, v: Int) =
        context.dataStore.edit { it[KEY_EXTENDED_DAYS] = v.toLong() }

    suspend fun setGetYesterday(context: Context, v: Boolean) =
        context.dataStore.edit { it[KEY_GET_YESTERDAY] = v }

    suspend fun setAutoCheckUpdate(context: Context, v: Boolean) =
        context.dataStore.edit { it[KEY_AUTO_UPDATE] = v }

    suspend fun setUseGps(context: Context, v: Boolean) = context.dataStore.edit { it[KEY_GPS] = v }

    suspend fun setLatLng(context: Context, lat: Double, lng: Double) =
        context.dataStore.edit { it[KEY_LAT] = lat; it[KEY_LNG] = lng }

    suspend fun saveCache(context: Context, w: WeatherData) {
        val s = json.encodeToString(w)
        context.dataStore.edit { it[KEY_CACHE] = s; it[KEY_CACHE_TIME] = System.currentTimeMillis() }
    }

    suspend fun loadCache(context: Context): WeatherData? {
        val p = context.dataStore.data.firstOrNull() ?: return null
        val s = p[KEY_CACHE] ?: return null
        return try {
            json.decodeFromString<WeatherData>(s)
        } catch (e: Exception) {
            null
        }
    }
}