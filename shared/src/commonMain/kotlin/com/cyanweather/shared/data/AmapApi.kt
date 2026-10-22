package com.cyanweather.shared.data

import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.WeatherData
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** 高德地图天气 API（数据源：中国气象局）。需 Key；坐标先逆地理编码取 adcode。 */
object AmapApi {

    private fun payload(raw: String): JsonObject {
        val root = Net.json.parseToJsonElement(raw).jsonObject
        val status = root["status"]?.jsonPrimitive?.content
        if (status != "1") {
            val info = root["info"]?.jsonPrimitive?.content ?: "未知错误"
            throw RuntimeException("高德天气：$info")
        }
        return root
    }

    private fun str(o: JsonObject, key: String): String =
        o[key]?.jsonPrimitive?.contentOrNull ?: o[key]?.jsonPrimitive?.double?.toString() ?: ""

    suspend fun weather(key: String, lat: Double, lon: Double, cityName: String): WeatherData {
        require(key.isNotBlank()) { "请填写高德天气 Key" }
        val location = "%.6f,%.6f".format(lon, lat)

        // 逆地理编码拿 adcode（天气接口只认行政区代码）
        val regeoRaw = Net.get(
            "https://restapi.amap.com/v3/geocode/regeo?output=json&location=$location&key=$key"
        )
        val regeo = payload(regeoRaw)
        val regeocode = regeo["regeocodes"]?.jsonArray?.firstOrNull()?.jsonObject
            ?: JsonObject(emptyMap())
        val adcode = str(regeocode, "adcode")
        require(adcode.isNotBlank()) { "高德未识别当前位置的行政区代码" }

        val baseRaw = Net.get(
            "https://restapi.amap.com/v3/weather/weatherInfo?output=json&city=$adcode&key=$key&extensions=base"
        )
        val base = payload(baseRaw)
        val live = base["lives"]?.jsonArray?.firstOrNull()?.jsonObject ?: JsonObject(emptyMap())

        // 预报：今天 + 未来 3 天（dayweather/nightweather/daytemp/nighttemp）
        val forecastRaw = runCatching {
            Net.get("https://restapi.amap.com/v3/weather/weatherInfo?output=json&city=$adcode&key=$key&extensions=all")
        }.getOrNull()
        val casts = forecastRaw?.let {
            payload(it)["forecasts"]?.jsonArray?.firstOrNull()?.jsonObject
                ?.get("casts")?.jsonArray
        } ?: kotlinx.serialization.json.JsonArray(emptyList())
        val daily = casts.map { c ->
            val o = c.jsonObject
            DailyItem(
                date = str(o, "date"),
                dayText = str(o, "dayweather").ifBlank { "多云" },
                nightText = str(o, "nightweather").ifBlank { "多云" },
                high = str(o, "daytemp").toDoubleOrNull(),
                low = str(o, "nighttemp").toDoubleOrNull()
            )
        }

        val reportTime = str(live, "reporttime")
        val windPowerRaw = str(live, "windpower").removeSuffix("级")
        return WeatherData(
            cityName = cityName,
            updatedAt = reportTime.take(16).takeIf { it.length == 16 }?.substring(11) ?: "",
            temperature = str(live, "temperature").toDoubleOrNull(),
            condition = str(live, "weather").ifBlank { "多云" },
            feelsLike = null,
            humidity = str(live, "humidity").toIntOrNull(),
            windDirect = str(live, "winddirection"),
            windPower = if (windPowerRaw.isNotBlank()) "${windPowerRaw}级" else "",
            todayHigh = daily.firstOrNull()?.high,
            todayLow = daily.firstOrNull()?.low,
            sourceTag = "数据来源：高德天气（中国气象局）",
            hourly = emptyList(),
            hourlyLabel = "高德暂无逐时预报",
            daily = daily
        )
    }
}
