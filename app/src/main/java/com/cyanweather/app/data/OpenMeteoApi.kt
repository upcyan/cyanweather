package com.cyanweather.app.data

import com.cyanweather.app.model.OpenMeteoAirQuality
import com.cyanweather.app.model.OpenMeteoResponse
import com.cyanweather.app.model.ReverseGeocode

object OpenMeteoApi {

    suspend fun getWeather(lat: Double, lng: Double): OpenMeteoResponse {
        val url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=$lat&longitude=$lng" +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m" +
            "&hourly=temperature_2m,weather_code,precipitation_probability,relative_humidity_2m,apparent_temperature,uv_index" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max" +
            "&forecast_days=16&forecast_hours=48&past_days=1&past_hours=36&timezone=Asia%2FShanghai"
        return Net.json.decodeFromString(Net.get(url))
    }

    suspend fun getAirQuality(lat: Double, lng: Double): OpenMeteoAirQuality? {
        return try {
            val url = "https://air-quality-api.open-meteo.com/v1/air-quality" +
                "?latitude=$lat&longitude=$lng&current=us_aqi,pm2_5,pm10&timezone=Asia%2FShanghai"
            Net.json.decodeFromString(Net.get(url))
        } catch (e: Exception) {
            null
        }
    }

    suspend fun reverseGeocode(lat: Double, lng: Double): ReverseGeocode? {
        return try {
            val url = "https://api.bigdatacloud.net/data/reverse-geocode-client" +
                "?latitude=$lat&longitude=$lng&localityLanguage=zh"
            Net.json.decodeFromString(Net.get(url))
        } catch (e: Exception) {
            null
        }
    }
}