package com.cyanweather.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Net {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(25, TimeUnit.SECONDS)
        .build()

    val json: Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    suspend fun get(url: String): String = get(url, emptyMap())

    suspend fun get(url: String, headers: Map<String, String>): String = withContext(Dispatchers.IO) {
        val builder = Request.Builder().url(url).header("User-Agent", "CyanWeather/1.0")
        headers.forEach { (k, v) -> builder.header(k, v) }
        val req = builder.build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw RuntimeException("网络请求失败: ${resp.code}")
            resp.body?.string() ?: throw RuntimeException("返回内容为空")
        }
    }
}