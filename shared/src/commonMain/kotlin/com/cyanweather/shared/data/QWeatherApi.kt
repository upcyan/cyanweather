package com.cyanweather.shared.data

import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object QWeatherApi {
    suspend fun weather(host: String, apiKey: String, lat: Double, lon: Double, cityName: String): WeatherData {
        val base = host.trim().removePrefix("https://").removePrefix("http://").trimEnd('/')
        require(base.isNotBlank()) { "请填写和风天气 API Host" }
        require(apiKey.isNotBlank()) { "请填写和风天气 API Key" }
        val headers = mapOf("X-QW-Api-Key" to apiKey.trim())
        val location = "$lat,$lon"
        val now = get("https://$base/v7/weather/now?location=$location&lang=zh", headers)
        val hourly = get("https://$base/v7/weather/24h?location=$location&lang=zh", headers)
        val daily = get("https://$base/v7/weather/7d?location=$location&lang=zh", headers)
        val warning = runCatching {
            get("https://$base/v7/warning/now?location=$location&lang=zh", headers)
        }.getOrNull()

        checkCode(now)
        checkCode(hourly)
        checkCode(daily)
        val n = now["now"]?.jsonObject ?: JsonObject(emptyMap())
        val days = daily["daily"]?.jsonArray ?: JsonArray(emptyList())
        val firstDay = days.firstOrNull()?.jsonObject
        return WeatherData(
            cityName = cityName,
            updatedAt = now.text("updateTime").substringAfter('T', "").take(5).ifBlank { n.text("obsTime") },
            temperature = n.double("temp"),
            condition = n.text("text"),
            feelsLike = n.double("feelsLike"),
            humidity = n.int("humidity"),
            windDirect = n.text("windDir"),
            windPower = n.text("windScale").let { if (it.isBlank()) "" else "${it}级" },
            todayHigh = firstDay?.double("tempMax"),
            todayLow = firstDay?.double("tempMin"),
            warning = warning?.get("warning")?.jsonArray?.firstOrNull()?.jsonObject?.text("title")?.takeIf { it.isNotBlank() },
            sunrise = firstDay?.text("sunrise"),
            sunset = firstDay?.text("sunset"),
            uvIndex = firstDay?.text("uvIndex").orEmpty(),
            sourceTag = "数据来源：和风天气",
            hourly = (hourly["hourly"]?.jsonArray ?: JsonArray(emptyList())).map { item ->
                val o = item.jsonObject
                HourlyItem(o.text("fxTime"), o.double("temp"), o.text("text"), true, o.double("pop"))
            },
            daily = days.map { item ->
                val o = item.jsonObject
                DailyItem(o.text("fxDate"), o.text("textDay"), o.text("textNight"), o.double("tempMax"), o.double("tempMin"))
            }
        )
    }

    private suspend fun get(url: String, headers: Map<String, String>): JsonObject =
        Net.json.parseToJsonElement(Net.get(url, headers)).jsonObject

    private fun checkCode(root: JsonObject) {
        val code = root.text("code")
        if (code != "200") throw RuntimeException("和风天气接口返回 $code")
    }
}

private fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()
private fun JsonObject.double(key: String): Double? = this[key]?.jsonPrimitive?.doubleOrNull
private fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.intOrNull
