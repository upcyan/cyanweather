package com.cyanweather.app.data

import android.content.Context
import android.net.Uri
import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.WeatherData

object XiaomiLocalWeather {
    private val uri = Uri.parse("content://weather/actualWeatherData/1/0")
    private val columns = arrayOf(
        "publish_time", "city_name", "description", "temperature", "aqilevel", "humidity",
        "sunrise", "sunset", "wind", "tmphighs", "tmplows", "weathernamesfrom", "weathernamesto"
    )

    fun read(context: Context): WeatherData? = runCatching {
        context.contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            fun text(name: String): String = cursor.getColumnIndex(name).takeIf { it >= 0 }?.let(cursor::getString).orEmpty()
            fun number(value: String): Double? = Regex("-?\\d+(?:\\.\\d+)?").find(value)?.value?.toDoubleOrNull()
            fun strings(name: String): List<String> {
                val index = cursor.getColumnIndex(name)
                if (index < 0) return emptyList()
                return runCatching { cursor.getString(index)?.split(',', '|') ?: emptyList() }.getOrDefault(emptyList())
            }
            val highs = strings("tmphighs")
            val lows = strings("tmplows")
            val day = strings("weathernamesfrom")
            val night = strings("weathernamesto")
            val daily = (0 until maxOf(highs.size, lows.size, day.size, night.size)).map { i ->
                DailyItem(
                    date = "第${i + 1}天",
                    dayText = day.getOrNull(i).orEmpty(),
                    nightText = night.getOrNull(i).orEmpty(),
                    high = highs.getOrNull(i)?.let(::number),
                    low = lows.getOrNull(i)?.let(::number)
                )
            }
            val wind = text("wind").split(',')
            WeatherData(
                cityName = text("city_name"), updatedAt = text("publish_time"),
                temperature = number(text("temperature")), condition = text("description"),
                humidity = number(text("humidity"))?.toInt(), windDirect = wind.firstOrNull().orEmpty(),
                windPower = wind.getOrNull(1).orEmpty(), todayHigh = daily.firstOrNull()?.high,
                todayLow = daily.firstOrNull()?.low, aqi = number(text("aqilevel"))?.toInt(),
                sunrise = millisToTime(text("sunrise")), sunset = millisToTime(text("sunset")),
                sourceTag = "数据来源：小米天气（设备本地）", daily = daily
            )
        }
    }.getOrNull()

    private fun millisToTime(value: String): String? {
        val totalMinutes = value.toLongOrNull()?.div(60_000) ?: return null
        return "%02d:%02d".format((totalMinutes / 60) % 24, totalMinutes % 60)
    }
}
