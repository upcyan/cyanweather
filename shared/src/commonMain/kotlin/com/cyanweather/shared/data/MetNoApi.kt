package com.cyanweather.shared.data

import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** MET Norway（挪威气象局）Locationforecast 2.0，免密钥，CC BY 4.0 需署名。 */
object MetNoApi {
    // MET 要求可识别的 User-Agent（含联系方式），并对响应做合理缓存
    private const val USER_AGENT = "CyanWeather/1.0 (github.com/upcyan/cyanweather)"
    private val TZ = TimeZone.of("Asia/Shanghai")

    suspend fun weather(lat: Double, lon: Double, cityName: String): WeatherData {
        val headers = mapOf("User-Agent" to USER_AGENT)
        val url = "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f"
            .format(lat, lon)
        val root = Net.json.parseToJsonElement(Net.get(url, headers)).jsonObject
        val props = root["properties"]?.jsonObject ?: JsonObject(emptyMap())
        val series = props["timeseries"]?.jsonArray ?: JsonArray(emptyList())
        require(series.isNotEmpty()) { "MET Norway 未返回数据" }
        val updatedAt = props["meta"]?.jsonObject?.get("updated_at")
            ?.jsonPrimitive?.contentOrNull?.substringAfter('T', "")?.take(5).orEmpty()

        fun symbolText(code: String): String {
            val base = code.substringBefore("_day").substringBefore("_night")
            return when {
                base == "clearsky" || base == "fair" -> "晴"
                base == "partlycloudy" -> "多云"
                base == "cloudy" -> "阴"
                base == "fog" -> "雾"
                base.startsWith("thunder") || base.contains("andthunder") -> "雷阵雨"
                base.contains("sleet") -> "雨夹雪"
                base.startsWith("heavysnow") || base == "snowshowers" -> "大雪"
                base.startsWith("light") && base.contains("snow") -> "小雪"
                base.contains("snow") -> "中雪"
                base.startsWith("heavyrain") -> "大雨"
                base.startsWith("lightrain") -> "小雨"
                base.contains("rain") -> "中雨"
                else -> "多云"
            }
        }

        fun detailsOf(entry: kotlinx.serialization.json.JsonElement): JsonObject? {
            val o = entry.jsonObject
            return o["data"]?.jsonObject?.get("instant")?.jsonObject?.get("details")?.jsonObject
        }

        fun symbolOf(entry: kotlinx.serialization.json.JsonElement, block: String): String? =
            entry.jsonObject["data"]?.jsonObject?.get(block)?.jsonObject
                ?.get("summary")?.jsonObject?.get("symbol_code")?.jsonPrimitive?.contentOrNull

        // 实况 = 第一个时间点
        val first = series.first().jsonObject
        val firstTime = first["time"]!!.jsonPrimitive.content
        val now = detailsOf(first)
        val firstSymbol = symbolOf(first, "next_1_hours")
            ?: symbolOf(first, "next_6_hours").orEmpty()
        val windFromDeg = now?.double("wind_from_direction")
        val windSpeed = now?.double("wind_speed")

        // 逐时：所有带 next_1_hours 的时间点（约未来 48 小时）
        val hourly = series.mapNotNull { e ->
            val sym = symbolOf(e, "next_1_hours") ?: return@mapNotNull null
            val t = e.jsonObject["time"]!!.jsonPrimitive.content
            val local = Instant.parse(t).toLocalDateTime(TZ)
            val det = detailsOf(e)
            HourlyItem(
                time = local.toString().substring(0, 16),
                temperature = det?.double("air_temperature"),
                condition = symbolText(sym)
            )
        }

        // 多日：按本地日期聚合瞬时温度，白天取 ~14 时符号，夜间取 ~02 时符号
        data class DayAcc(val date: String) {
            var min: Double? = null
            var max: Double? = null
            var dayText = ""
            var nightText = ""
        }
        val byDate = LinkedHashMap<String, DayAcc>()
        for (e in series) {
            val t = e.jsonObject["time"]!!.jsonPrimitive.content
            val local = Instant.parse(t).toLocalDateTime(TZ)
            val date = local.date.toString()
            val acc = byDate.getOrPut(date) { DayAcc(date) }
            val temp = detailsOf(e)?.double("air_temperature") ?: continue
            acc.min = minOf(acc.min ?: temp, temp)
            acc.max = maxOf(acc.max ?: temp, temp)
            val h = local.hour
            val sym = symbolOf(e, "next_6_hours") ?: symbolOf(e, "next_1_hours") ?: continue
            if (h in 13..15 && acc.dayText.isEmpty()) acc.dayText = symbolText(sym)
            if (h in 1..4 && acc.nightText.isEmpty()) acc.nightText = symbolText(sym)
        }
        val daily = byDate.values.map { acc ->
            DailyItem(
                date = acc.date,
                dayText = acc.dayText.ifBlank { acc.nightText.ifBlank { "多云" } },
                nightText = acc.nightText.ifBlank { acc.dayText.ifBlank { "多云" } },
                high = acc.max,
                low = acc.min
            )
        }

        return WeatherData(
            cityName = cityName,
            updatedAt = updatedAt,
            temperature = now?.double("air_temperature"),
            condition = symbolText(firstSymbol.ifBlank { "partlycloudy" }),
            feelsLike = null,
            humidity = now?.double("relative_humidity")?.toInt(),
            windDirect = windFromDeg?.let { windDirection(it) }.orEmpty(),
            windPower = windSpeed?.let { "${beaufort(it)}级" }.orEmpty(),
            todayHigh = daily.firstOrNull()?.high,
            todayLow = daily.firstOrNull()?.low,
            sourceTag = "数据来源：MET Norway",
            hourly = hourly,
            hourlyLabel = "MET 48小时预报",
            daily = daily
        )
    }
}


private fun JsonObject.text(key: String): String = this[key]?.jsonPrimitive?.contentOrNull.orEmpty()

private fun JsonObject.double(key: String): Double? =
    this[key]?.jsonPrimitive?.let { it.doubleOrNull ?: it.contentOrNull?.trim()?.toDoubleOrNull() }

private fun JsonObject.int(key: String): Int? =
    this[key]?.jsonPrimitive?.let { it.intOrNull ?: it.contentOrNull?.trim()?.toIntOrNull() }

