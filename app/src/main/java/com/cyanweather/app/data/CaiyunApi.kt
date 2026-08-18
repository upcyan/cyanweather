package com.cyanweather.app.data

import android.util.Base64
import com.cyanweather.app.model.CaiyunWeather
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object CaiyunApi {
    private const val BASE = "https://api.caiyunapp.com/v2.6"

    suspend fun getWeatherV1(token: String, lat: Double, lng: Double): CaiyunWeather {
        val body = Net.get("$BASE/$token/$lng,$lat/weather.json")
        return Net.json.decodeFromString(body)
    }

    suspend fun getWeatherV1(token: String, lat: Double, lng: Double, dailystart: Int, dailysteps: Int): CaiyunWeather {
        val path = "/$token/$lng,$lat/weather"
        val query = linkedMapOf(
            "alert" to "true",
            "dailysteps" to dailysteps.toString(),
            "dailystart" to dailystart.toString(),
            "hourlysteps" to "48"
        ).entries.joinToString("&") { "${it.key}=${it.value}" }
        val url = "$BASE$path?$query"
        val body = Net.get(url)
        return Net.json.decodeFromString(body)
    }

    suspend fun getWeatherV3(key: String, secret: String, lat: Double, lng: Double): CaiyunWeather {
        val coordPath = "/$key/$lng,$lat/weather"
        val signPath = "/v2.6$coordPath"
        val nonce = java.util.UUID.randomUUID().toString()
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val query = linkedMapOf(
            "alert" to "true",
            "dailysteps" to "1",
            "hourlysteps" to "24"
        ).entries.joinToString("&") { "${it.key}=${it.value}" }
        val stringToSign = "GET:$signPath:$query:$key:$nonce:$timestamp"
        val signature = hmacSha256Base64Url(stringToSign, secret)
        val url = "$BASE$coordPath?$query"
        val body = Net.get(url, mapOf(
            "x-cy-nonce" to nonce,
            "x-cy-timestamp" to timestamp,
            "x-cy-signature" to signature
        ))
        return Net.json.decodeFromString(body)
    }

    private fun hmacSha256Base64Url(data: String, secret: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val digest = mac.doFinal(data.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_WRAP)
    }
}