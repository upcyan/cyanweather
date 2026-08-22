package com.cyanweather.shared.data

import com.cyanweather.shared.model.OpenMeteoAirQuality
import com.cyanweather.shared.model.OpenMeteoResponse
import com.cyanweather.shared.model.ReverseGeocode

object OpenMeteoApi {
    private const val BASE = "https://api.open-meteo.com/v1"
    private const val AIR = "https://air-quality-api.open-meteo.com/v1"

    suspend fun weather(lat: Double, lon: Double): OpenMeteoResponse {
        val url = "$BASE/forecast" +
            "?latitude=$lat&longitude=$lon" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m" +
            "&hourly=temperature_2m,weather_code,precipitation_probability,relative_humidity_2m,apparent_temperature,uv_index" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max" +
            "&timezone=auto&forecast_days=15&past_days=1"
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
        val geo = reverseGeocodeFull(lat, lon) ?: return ""
        return geo.third.ifBlank { geo.second }.ifBlank { geo.first }
    }

    suspend fun reverseGeocodeFull(lat: Double, lon: Double): Triple<String, String, String>? {
        val url = "https://api.bigdatacloud.net/data/reverse-geocode-client" +
            "?latitude=$lat&longitude=$lon&localityLanguage=zh"
        val text = Net.get(url)
        return try {
            val geo = Net.json.decodeFromString<ReverseGeocode>(text)
            Triple(geo.province, geo.city, geo.locality)
        } catch (_: Exception) {
            null
        }
    }
}
