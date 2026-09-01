package com.cyanweather.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.contentOrNull

// ---------- Unified UI data models ----------

@Serializable
data class WeatherData(
    val cityName: String = "",
    val updatedAt: String = "",
    val temperature: Double? = null,
    val condition: String = "",
    val feelsLike: Double? = null,
    val humidity: Int? = null,
    val windDirect: String = "",
    val windPower: String = "",
    val todayHigh: Double? = null,
    val todayLow: Double? = null,
    val aqi: Int? = null,
    val aqiText: String? = null,
    val warning: String? = null,
    val sunrise: String? = null,
    val sunset: String? = null,
    val minutelyText: String? = null,
    val uvIndex: String = "",
    val sourceTag: String = "",
    val hourly: List<HourlyItem> = emptyList(),
    val hourlyLabel: String = "hourly forecast",
    val daily: List<DailyItem> = emptyList(),
    val yesterday: YesterdayData? = null,
    val savedAt: Long = 0L,
    val sourceContributions: Map<String, String> = emptyMap(),
    val confidence: Float = 1.0f,
    val pm25: Double? = null,
    val pm10: Double? = null,
    val windSpeed: Double? = null
)

@Serializable
data class HourlyItem(
    val time: String = "",
    val temperature: Double? = null,
    val condition: String = "",
    val isForecast: Boolean = true,
    val rainProb: Double? = null
)

@Serializable
data class DailyItem(
    val date: String = "",
    val dayText: String = "",
    val nightText: String = "",
    val high: Double? = null,
    val low: Double? = null
)

@Serializable
data class YesterdayData(
    val high: Double? = null,
    val low: Double? = null,
    val hourly: List<HourlyItem> = emptyList()
)

fun Double?.clean(): Double? = if (this == null || this >= 9998.0) null else this

fun Int?.cleanInt(): Int? = if (this == null || this >= 9998) null else this

// ---------- NMC ----------

@Serializable
data class NmcResponse(
    @SerialName("data") val data: NmcData? = null,
    @SerialName("code") val code: Int = -1
)

@Serializable
data class NmcData(
    @SerialName("real") val real: NmcReal? = null,
    @SerialName("predict") val predict: NmcPredict? = null,
    @SerialName("air") val air: NmcAir? = null,
    @SerialName("tempchart") val tempchart: List<NmcTempChartDay> = emptyList(),
    @SerialName("passedchart") val passedchart: List<NmcPassedHour> = emptyList()
)

@Serializable
data class NmcReal(
    @SerialName("station") val station: NmcStation? = null,
    @SerialName("publish_time") val publishTime: String = "",
    @SerialName("weather") val weather: NmcRealWeather? = null,
    @SerialName("wind") val wind: NmcWind? = null,
    @SerialName("warn") val warn: NmcWarn? = null,
    @SerialName("sunriseSunset") val sunriseSunset: NmcSunrise? = null
)

@Serializable
data class NmcStation(
    @SerialName("city") val city: String = "",
    @SerialName("province") val province: String = ""
)

@Serializable
data class NmcRealWeather(
    @SerialName("temperature") val temperature: Double? = null,
    @SerialName("humidity") val humidity: Double? = null,
    @SerialName("info") val info: String = "",
    @SerialName("feelst") val feelst: Double? = null
)

@Serializable
data class NmcWind(
    @SerialName("direct") val direct: String = "",
    @SerialName("power") val power: String = ""
)

@Serializable
data class NmcWarn(
    @SerialName("alert") val alert: String = "",
    @SerialName("signaltype") val signaltype: String = "",
    @SerialName("signallevel") val signallevel: String = ""
)

@Serializable
data class NmcSunrise(
    @SerialName("sunrise") val sunrise: String = "",
    @SerialName("sunset") val sunset: String = ""
)

@Serializable
data class NmcPredict(
    @SerialName("publish_time") val publishTime: String = "",
    @SerialName("detail") val detail: List<NmcPredictDay> = emptyList()
)

@Serializable
data class NmcPredictDay(
    @SerialName("date") val date: String = "",
    @SerialName("day") val day: NmcDayPart? = null,
    @SerialName("night") val night: NmcDayPart? = null
)

@Serializable
data class NmcDayPart(
    @SerialName("weather") val weather: NmcDayWeather? = null,
    @SerialName("wind") val wind: NmcWind? = null
)

@Serializable
data class NmcDayWeather(
    @SerialName("info") val info: String = "",
    @SerialName("temperature") val temperature: String = ""
)

@Serializable
data class NmcAir(
    @SerialName("aqi") val aqi: Int? = null,
    @SerialName("text") val text: String = ""
)

@Serializable
data class NmcTempChartDay(
    @SerialName("time") val time: String = "",
    @SerialName("max_temp") val maxTemp: Double? = null,
    @SerialName("min_temp") val minTemp: Double? = null,
    @SerialName("day_text") val dayText: String = "",
    @SerialName("night_text") val nightText: String = ""
)

@Serializable
data class NmcPassedHour(
    @SerialName("time") val time: String = "",
    @SerialName("temperature") val temperature: Double? = null,
    @SerialName("humidity") val humidity: Double? = null,
    @SerialName("rain1h") val rain1h: Double? = null
)

@Serializable
data class NmcCityItem(
    @SerialName("code") val code: String = "",
    @SerialName("city") val city: String = "",
    @SerialName("province") val province: String = ""
)

@Serializable
data class NmcProvinceItem(
    @SerialName("code") val code: String = "",
    @SerialName("name") val name: String = ""
)

// ---------- Caiyun ----------

@Serializable
data class CaiyunWeather(
    @SerialName("status") val status: String = "",
    @SerialName("result") val result: CaiyunResult? = null
)

@Serializable
data class CaiyunResult(
    @SerialName("realtime") val realtime: CaiyunRealtime? = null,
    @SerialName("hourly") val hourly: CaiyunHourly? = null,
    @SerialName("daily") val daily: CaiyunDaily? = null,
    @SerialName("minutely") val minutely: CaiyunMinutely? = null,
    @SerialName("location") val location: List<String> = emptyList(),
    @SerialName("alert") val alert: JsonElement? = null
)

@Serializable
data class CaiyunRealtime(
    @SerialName("temperature") val temperature: Double? = null,
    @SerialName("humidity") val humidity: Double? = null,
    @SerialName("skycon") val skycon: String = "",
    @SerialName("apparent_temperature") val apparentTemperature: Double? = null,
    @SerialName("wind") val wind: CaiyunWind? = null,
    @SerialName("air_quality") val airQuality: CaiyunAirQuality? = null
)

@Serializable
data class CaiyunWind(
    @SerialName("speed") val speed: Double? = null,
    @SerialName("direction") val direction: Double? = null
)

@Serializable
data class CaiyunAirQuality(
    @SerialName("aqi") val aqi: CaiyunAqi? = null
)

@Serializable
data class CaiyunAqi(
    @SerialName("chn") val chn: Double? = null
)

@Serializable
data class CaiyunHourly(
    @SerialName("temperature") val temperature: List<CaiyunTItem> = emptyList(),
    @SerialName("skycon") val skycon: List<CaiyunSItem> = emptyList(),
    @SerialName("precipitation") val precipitation: List<CaiyunTItem> = emptyList()
)

@Serializable
data class CaiyunTItem(
    @SerialName("datetime") val datetime: String = "",
    @SerialName("value") val value: Double? = null
)

@Serializable
data class CaiyunSItem(
    @SerialName("datetime") val datetime: String = "",
    @SerialName("value") val value: JsonElement? = null
)

@Serializable
data class CaiyunDaily(
    @SerialName("temperature") val temperature: List<CaiyunDailyTemp> = emptyList(),
    @SerialName("skycon") val skycon: List<CaiyunDailySkycon> = emptyList(),
    @SerialName("astro") val astro: List<CaiyunAstro> = emptyList()
)

@Serializable
data class CaiyunDailyTemp(
    @SerialName("date") val date: String = "",
    @SerialName("max") val max: Double? = null,
    @SerialName("min") val min: Double? = null
)

@Serializable
data class CaiyunDailySkycon(
    @SerialName("date") val date: String = "",
    @SerialName("value") val value: JsonElement? = null
)

@Serializable
data class CaiyunAstro(
    @SerialName("date") val date: String = "",
    @SerialName("sunrise") val sunrise: CaiyunAstroItem? = null,
    @SerialName("sunset") val sunset: CaiyunAstroItem? = null
)

@Serializable
data class CaiyunAstroItem(
    @SerialName("time") val time: String = ""
)

@Serializable
data class CaiyunMinutely(
    @SerialName("description") val description: String = "",
    @SerialName("precipitation_2h") val precipitation2h: List<Double?> = emptyList(),
    @SerialName("precipitation_1h") val precipitation1h: List<Double?> = emptyList()
)

fun skyconTextOf(el: JsonElement?): String {
    return when (el) {
        is kotlinx.serialization.json.JsonPrimitive -> el.contentOrNull ?: ""
        is kotlinx.serialization.json.JsonArray -> el.firstOrNull()?.let { skyconTextOf(it) } ?: ""
        else -> ""
    }
}

// ---------- Open-Meteo ----------

@Serializable
data class OpenMeteoResponse(
    @SerialName("current") val current: OpenMeteoCurrent? = null,
    @SerialName("hourly") val hourly: OpenMeteoHourly? = null,
    @SerialName("daily") val daily: OpenMeteoDaily? = null
)

@Serializable
data class OpenMeteoCurrent(
    @SerialName("time") val time: String = "",
    @SerialName("temperature_2m") val temperature2m: Double? = null,
    @SerialName("relative_humidity_2m") val humidity: Int? = null,
    @SerialName("apparent_temperature") val apparentTemperature: Double? = null,
    @SerialName("is_day") val isDay: Int? = null,
    @SerialName("precipitation") val precipitation: Double? = null,
    @SerialName("weather_code") val weatherCode: Int? = null,
    @SerialName("wind_speed_10m") val windSpeed: Double? = null,
    @SerialName("wind_direction_10m") val windDirection: Double? = null
)

@Serializable
data class OpenMeteoHourly(
    @SerialName("time") val time: List<String> = emptyList(),
    @SerialName("temperature_2m") val temperature: List<Double?> = emptyList(),
    @SerialName("weather_code") val weatherCode: List<Int?> = emptyList(),
    @SerialName("precipitation_probability") val precipProb: List<Int?> = emptyList(),
    @SerialName("relative_humidity_2m") val humidity: List<Int?> = emptyList(),
    @SerialName("apparent_temperature") val apparentTemperature: List<Double?> = emptyList(),
    @SerialName("uv_index") val uvIndex: List<Double?> = emptyList()
)

@Serializable
data class OpenMeteoDaily(
    @SerialName("time") val time: List<String> = emptyList(),
    @SerialName("weather_code") val weatherCode: List<Int?> = emptyList(),
    @SerialName("temperature_2m_max") val tempMax: List<Double?> = emptyList(),
    @SerialName("temperature_2m_min") val tempMin: List<Double?> = emptyList(),
    @SerialName("sunrise") val sunrise: List<String> = emptyList(),
    @SerialName("sunset") val sunset: List<String> = emptyList(),
    @SerialName("uv_index_max") val uvIndexMax: List<Double?> = emptyList(),
    @SerialName("precipitation_probability_max") val precipProbMax: List<Int?> = emptyList()
)

@Serializable
data class OpenMeteoAirQuality(
    @SerialName("current") val current: OpenMeteoAirCurrent? = null
)

@Serializable
data class OpenMeteoAirCurrent(
    @SerialName("us_aqi") val usAqi: Int? = null,
    @SerialName("pm2_5") val pm25: Double? = null,
    @SerialName("pm10") val pm10: Double? = null
)

// ---------- Reverse Geocoding ----------

@Serializable
data class ReverseGeocode(
    @SerialName("principalSubdivision") val province: String = "",
    @SerialName("city") val city: String = "",
    @SerialName("locality") val locality: String = ""
)
