package com.cyanweather.shared.data

import com.cyanweather.shared.model.CaiyunWeather
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.util.Base64

object CaiyunApi {
    private const val BASE = "https://api.caiyunapp.com/v2.6"

    suspend fun weatherV1(token: String, lat: Double, lng: Double): CaiyunWeather {
        val body = Net.get("$BASE/$token/$lng,$lat/weather.json")
        return Net.json.decodeFromString<CaiyunWeather>(body)
    }

    suspend fun weatherV1(token: String, lat: Double, lng: Double, dailystart: Int, dailysteps: Int): CaiyunWeather {
        val path = "/$token/$lng,$lat/weather"
        val query = linkedMapOf(
            "alert" to "true",
            "dailysteps" to dailysteps.toString(),
            "dailystart" to dailystart.toString(),
            "hourlysteps" to "48"
        ).entries.joinToString("&") { "${it.key}=${it.value}" }
        val url = "$BASE$path?$query"
        val body = Net.get(url)
        return Net.json.decodeFromString<CaiyunWeather>(body)
    }

    suspend fun weatherV3(
        appKey: String,
        appSecret: String,
        lat: Double,
        lng: Double,
        dailysteps: Int = 3,
        hourlysteps: Int = 48
    ): CaiyunWeather {
        val coordPath = "/$appKey/$lng,$lat/weather"
        val signPath = "/v2.6$coordPath"
        val nonce = UUID.randomUUID().toString()
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val query = linkedMapOf(
            "alert" to "true",
            "dailysteps" to dailysteps.toString(),
            "hourlysteps" to hourlysteps.toString()
        ).entries.joinToString("&") { "${it.key}=${it.value}" }
        val stringToSign = "GET:$signPath:$query:$appKey:$nonce:$timestamp"
        val signature = hmacSha256Base64Url(stringToSign, appSecret)
        val url = "$BASE$coordPath?$query"
        val body = Net.get(url, mapOf(
            "x-cy-nonce" to nonce,
            "x-cy-timestamp" to timestamp,
            "x-cy-signature" to signature
        ))
        return Net.json.decodeFromString<CaiyunWeather>(body)
    }

    private fun hmacSha256Base64Url(data: String, secret: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val digest = mac.doFinal(data.toByteArray(Charsets.UTF_8))
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }
}
