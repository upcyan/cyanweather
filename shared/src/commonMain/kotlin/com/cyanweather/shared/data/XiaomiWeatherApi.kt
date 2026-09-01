package com.cyanweather.shared.data

import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import com.cyanweather.shared.model.YesterdayData
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object XiaomiWeatherApi {
    private const val BASE = "https://weatherapi.market.xiaomi.com/wtr-v3/weather/all"

    suspend fun weather(lat: Double, lon: Double, stationId: String, cityName: String): WeatherData {
        require(stationId.isNotBlank()) { "小米天气需要中国气象局城市代码" }
        val url = "$BASE?latitude=$lat&longitude=$lon&isLocated=true" +
            "&locationKey=weathercn%3A$stationId&days=15&appKey=weather20151024" +
            "&sign=zUFJoAR2ZVrDy1vF3D07&isGlobal=false&locale=zh_cn"
        val root = Net.json.parseToJsonElement(Net.get(url)).jsonObject
        val current = root.obj("current")
        val fd = root.obj("forecastDaily")
        val fh = root.obj("forecastHourly")
        val temps = fd.values("temperature")
        val weather = fd.values("weather")
        val sun = fd.values("sunRiseSet")
        val hourlyTemps = fh.values("temperature")
        val hourlyWeather = fh.values("weather")
        val pubTime = fh.obj("temperature").text("pubTime")
        val baseHour = pubTime.takeIf { it.length >= 13 }?.substring(0, 13)
        val hourly = (0 until minOf(hourlyTemps.size, hourlyWeather.size)).map { i ->
            val hour = baseHour?.let { runCatching { it.takeLast(2).toInt() + i }.getOrNull() }
            HourlyItem(
                time = hour?.let { "%02d:00".format(it % 24) }.orEmpty(),
                temperature = hourlyTemps[i].jsonPrimitive.doubleOrNull,
                condition = xiaomiWeatherText(hourlyWeather[i].jsonPrimitive.intOrNull),
                isForecast = true
            )
        }
        val daily = (0 until minOf(temps.size, weather.size)).map { i ->
            val t = temps[i].jsonObject
            val w = weather[i].jsonObject
            DailyItem(
                date = "第${i + 1}天",
                dayText = xiaomiWeatherText(w.int("from")),
                nightText = xiaomiWeatherText(w.int("to")),
                high = t.double("from"),
                low = t.double("to")
            )
        }
        val y = root["yesterday"]?.jsonObject
        return WeatherData(
            cityName = cityName,
            updatedAt = current.text("pubTime"),
            temperature = current.obj("temperature").double("value"),
            condition = xiaomiWeatherText(current.int("weather")),
            feelsLike = current.obj("feelsLike").double("value"),
            humidity = current.obj("humidity").int("value"),
            windDirect = degreeText(current.obj("wind").obj("direction").double("value")),
            windPower = current.obj("wind").obj("speed").text("value").let { if (it.isBlank()) "" else "$it km/h" },
            todayHigh = daily.firstOrNull()?.high,
            todayLow = daily.firstOrNull()?.low,
            aqi = root.obj("aqi").int("aqi"),
            warning = root["alerts"]?.jsonArray?.firstOrNull()?.jsonObject?.let { it.text("title").ifBlank { it.text("detail") } }?.takeIf { it.isNotBlank() },
            sunrise = sun.firstOrNull()?.jsonObject?.text("from")?.takeLast(14)?.take(5),
            sunset = sun.firstOrNull()?.jsonObject?.text("to")?.takeLast(14)?.take(5),
            uvIndex = current.text("uvIndex"),
            sourceTag = "数据来源：小米天气（实验性）",
            hourly = hourly,
            daily = daily,
            yesterday = y?.let { YesterdayData(it.double("tempMax"), it.double("tempMin")) }
        )
    }
}

private fun JsonObject.obj(key: String): JsonObject = this[key]?.jsonObject ?: JsonObject(emptyMap())
private fun JsonObject.values(key: String): JsonArray = obj(key)["value"]?.jsonArray ?: JsonArray(emptyList())
private fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()
private fun JsonObject.double(key: String): Double? = this[key]?.jsonPrimitive?.doubleOrNull
private fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.intOrNull

private fun xiaomiWeatherText(code: Int?): String = when (code) {
    0 -> "晴"; 1 -> "多云"; 2 -> "阴"; 3, 4, 5 -> "阵雨"; 6 -> "雨夹雪"
    7 -> "小雨"; 8 -> "中雨"; 9 -> "大雨"; 10, 11, 12 -> "暴雨"
    13 -> "阵雪"; 14 -> "小雪"; 15 -> "中雪"; 16 -> "大雪"; 17 -> "暴雪"
    18 -> "雾"; 19 -> "冻雨"; 20, 21 -> "沙尘"; 22 -> "小到中雨"; 23 -> "中到大雨"
    24 -> "大到暴雨"; 25 -> "暴雨到大暴雨"; 26 -> "小到中雪"; 27 -> "中到大雪"
    28 -> "大到暴雪"; 29 -> "浮尘"; 30 -> "扬沙"; 31 -> "强沙尘暴"; 53 -> "霾"
    else -> "未知"
}

private fun degreeText(degree: Double?): String = when (degree) {
    null -> ""
    in 22.5..67.5 -> "东北风"; in 67.5..112.5 -> "东风"; in 112.5..157.5 -> "东南风"
    in 157.5..202.5 -> "南风"; in 202.5..247.5 -> "西南风"; in 247.5..292.5 -> "西风"
    in 292.5..337.5 -> "西北风"; else -> "北风"
}
