package com.cyanweather.shared.data

import com.cyanweather.shared.model.OpenMeteoAirQuality
import com.cyanweather.shared.model.OpenMeteoResponse
import com.cyanweather.shared.model.ReverseGeocode
import kotlinx.serialization.json.jsonObject

object OpenMeteoApi {
    private const val BASE = "https://api.open-meteo.com/v1"
    private const val AIR = "https://air-quality-api.open-meteo.com/v1"
    private const val GEO = "https://geocoding-api.open-meteo.com/v1"

    suspend fun weather(lat: Double, lon: Double): OpenMeteoResponse {
        val url = "$BASE/forecast" +
            "?latitude=$lat&longitude=$lon" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m" +
            "&hourly=temperature_2m,weather_code,precipitation_probability,relative_humidity_2m,apparent_temperature,uv_index" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max" +
            "&timezone=auto&forecast_days=15"
        val text = Net.get(url)
        return Net.json.decodeFromString<OpenMeteoResponse>(text)
    }

    suspend fun airQuality(lat: Double, lon: Double): OpenMeteoAirQuality? {
        val url = "$AIR/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm2_5,pm10"
        val text = Net.get(url)
        return try {
            Net.json.decodeFromString<OpenMeteoAirQuality>(text)
        } catch (_: Exception) {
            null
        }
    }

    suspend fun reverseGeocode(lat: Double, lon: Double): String {
        val url = "$GEO/reverse?latitude=$lat&longitude=$lon&count=1&language=zh"
        val text = Net.get(url)
        return try {
            val json = Net.json.parseToJsonElement(text)
            val results = json.jsonObject["results"]
            if (results != null && results.toString() != "null") {
                val arr = Net.json.decodeFromString<List<ReverseGeocode>>(results.toString())
                arr.firstOrNull()?.let {
                    listOf(it.city, it.province).filter { s -> s.isNotBlank() }.joinToString(" ")
                } ?: ""
            } else ""
        } catch (_: Exception) {
            ""
        }
    }
}
