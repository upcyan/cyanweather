package com.cyanweather.app.data

import com.cyanweather.app.model.CaiyunDaily
import com.cyanweather.app.model.CaiyunHourly
import com.cyanweather.app.model.CaiyunRealtime
import com.cyanweather.app.model.CaiyunWeather
import com.cyanweather.app.model.DailyItem
import com.cyanweather.app.model.HourlyItem
import com.cyanweather.app.model.NmcData
import com.cyanweather.app.model.OpenMeteoAirCurrent
import com.cyanweather.app.model.OpenMeteoAirQuality
import com.cyanweather.app.model.OpenMeteoCurrent
import com.cyanweather.app.model.OpenMeteoDaily
import com.cyanweather.app.model.OpenMeteoHourly
import com.cyanweather.app.model.OpenMeteoResponse
import com.cyanweather.app.model.WeatherData
import com.cyanweather.app.model.YesterdayData
import com.cyanweather.app.model.clean
import com.cyanweather.app.model.cleanInt
import com.cyanweather.app.model.skyconTextOf
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.serialization.json.jsonObject

enum class SkyKind { SUN, MOON, CLOUD, PARTLY, RAIN, SNOW, THUNDER, FOG, HAZE, WIND, SLEET, UNKNOWN }

fun caiyunSkyconText(code: String): String = when (code) {
    "CLEAR_DAY" -> "晴"
    "CLEAR_NIGHT" -> "晴"
    "PARTLY_CLOUDY_DAY" -> "多云"
    "PARTLY_CLOUDY_NIGHT" -> "多云"
    "CLOUDY" -> "阴"
    "LIGHT_HAZE" -> "轻度霾"
    "MODERATE_HAZE" -> "中度霾"
    "HEAVY_HAZE" -> "重度霾"
    "LIGHT_RAIN" -> "小雨"
    "MODERATE_RAIN" -> "中雨"
    "HEAVY_RAIN" -> "大雨"
    "STORM_RAIN" -> "暴雨"
    "FOG" -> "雾"
    "LIGHT_SNOW" -> "小雪"
    "MODERATE_SNOW" -> "中雪"
    "HEAVY_SNOW" -> "大雪"
    "STORM_SNOW" -> "暴雪"
    "DUST" -> "浮尘"
    "SAND" -> "沙尘"
    "WIND" -> "大风"
    "THUNDER_SHOWER" -> "雷阵雨"
    "HAIL" -> "冰雹"
    "SLEET" -> "雨夹雪"
    "TORNADO" -> "龙卷风"
    else -> code
}

fun caiyunSkyconKind(code: String): SkyKind = when (code) {
    "CLEAR_DAY" -> SkyKind.SUN
    "CLEAR_NIGHT" -> SkyKind.MOON
    "PARTLY_CLOUDY_DAY" -> SkyKind.PARTLY
    "PARTLY_CLOUDY_NIGHT" -> SkyKind.PARTLY
    "CLOUDY" -> SkyKind.CLOUD
    "LIGHT_HAZE", "MODERATE_HAZE", "HEAVY_HAZE", "DUST", "SAND" -> SkyKind.HAZE
    "LIGHT_RAIN", "MODERATE_RAIN", "HEAVY_RAIN", "STORM_RAIN" -> SkyKind.RAIN
    "FOG" -> SkyKind.FOG
    "LIGHT_SNOW", "MODERATE_SNOW", "HEAVY_SNOW", "STORM_SNOW" -> SkyKind.SNOW
    "WIND" -> SkyKind.WIND
    "THUNDER_SHOWER" -> SkyKind.THUNDER
    "HAIL" -> SkyKind.RAIN
    "SLEET" -> SkyKind.SLEET
    "TORNADO" -> SkyKind.WIND
    else -> SkyKind.UNKNOWN
}

fun nmcSkyconKind(text: String): SkyKind = when {
    text.contains("雷") -> SkyKind.THUNDER
    text.contains("雪") -> SkyKind.SNOW
    text.contains("雨夹雪") -> SkyKind.SLEET
    text.contains("雨") -> SkyKind.RAIN
    text.contains("晴") -> SkyKind.SUN
    text.contains("云") -> SkyKind.PARTLY
    text.contains("阴") -> SkyKind.CLOUD
    text.contains("雾") -> SkyKind.FOG
    text.contains("霾") || text.contains("尘") || text.contains("沙") -> SkyKind.HAZE
    text.contains("风") -> SkyKind.WIND
    else -> SkyKind.UNKNOWN
}

fun windDirection(degree: Double): String {
    val dirs = arrayOf("北风", "东北风", "东风", "东南风", "南风", "西南风", "西风", "西北风")
    val idx = (((degree + 22.5) / 45.0).toInt()) % 8
    return dirs[idx]
}

fun beaufort(speedMps: Double): String {
    val bft = when {
        speedMps < 0.3 -> 0
        speedMps < 1.6 -> 1
        speedMps < 3.4 -> 2
        speedMps < 5.5 -> 3
        speedMps < 8.0 -> 4
        speedMps < 10.8 -> 5
        speedMps < 13.9 -> 6
        speedMps < 17.2 -> 7
        speedMps < 20.8 -> 8
        else -> 9
    }
    return "${bft}级"
}

fun aqiText(aqi: Int?): String = when {
    aqi == null -> ""
    aqi <= 50 -> "优"
    aqi <= 100 -> "良"
    aqi <= 150 -> "轻度污染"
    aqi <= 200 -> "中度污染"
    aqi <= 300 -> "重度污染"
    else -> "严重污染"
}

fun wmoToText(code: Int?): String = when (code) {
    0, 1 -> "晴"
    2 -> "多云"
    3 -> "阴"
    45, 48 -> "雾"
    51, 53, 55 -> "小雨"
    56, 57 -> "雨夹雪"
    61 -> "小雨"
    63 -> "中雨"
    65 -> "大雨"
    66, 67 -> "雨夹雪"
    71 -> "小雪"
    73 -> "中雪"
    75 -> "大雪"
    77 -> "小雪"
    80 -> "小雨"
    81 -> "中雨"
    82 -> "大雨"
    85 -> "中雪"
    86 -> "大雪"
    95 -> "雷阵雨"
    96, 99 -> "雷阵雨"
    else -> "-"
}

fun wmoToSkycon(code: Int?): SkyKind = when (code) {
    0, 1 -> SkyKind.SUN
    2 -> SkyKind.PARTLY
    3 -> SkyKind.CLOUD
    45, 48 -> SkyKind.FOG
    51, 53, 55, 61, 63, 65, 80, 81, 82 -> SkyKind.RAIN
    56, 57, 66, 67 -> SkyKind.SLEET
    71, 73, 75, 77, 85, 86 -> SkyKind.SNOW
    95, 96, 99 -> SkyKind.THUNDER
    else -> SkyKind.UNKNOWN
}

fun uvLevelText(uv: Double?): String = when {
    uv == null -> ""
    uv < 3 -> "弱"
    uv < 6 -> "中等"
    uv < 8 -> "强"
    uv < 11 -> "很强"
    else -> "极强"
}

private fun todayStr(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

// ---------- 解析 Open-Meteo 数据 ----------

fun parseOpenMeteo(w: OpenMeteoResponse, air: OpenMeteoAirQuality?, cityName: String): WeatherData {
    val current = w.current ?: throw RuntimeException("Open-Meteo 无实时数据")
    val daily = w.daily
    val hourly = w.hourly
    val today = todayStr()

    val todayIdx = daily?.time?.indexOf(today) ?: -1

    val dailyList: List<DailyItem> = if (daily != null && todayIdx >= 0) {
        daily.time.mapIndexedNotNull { i, date ->
            if (i < todayIdx) return@mapIndexedNotNull null
            val high = daily.tempMax.getOrNull(i)?.clean()
            val low = daily.tempMin.getOrNull(i)?.clean()
            if (high == null && low == null) return@mapIndexedNotNull null
            DailyItem(
                date = date,
                dayText = wmoToText(daily.weatherCode.getOrNull(i)),
                nightText = "",
                high = high,
                low = low
            )
        }
    } else emptyList()

    val yesterday: YesterdayData? = if (daily != null && todayIdx >= 1) {
        val yIdx = todayIdx - 1
        val yDate = daily.time.getOrNull(yIdx) ?: ""
        val yHours = hourly?.time?.mapIndexedNotNull { i, t ->
            if (t.startsWith(yDate)) {
                HourlyItem(
                    time = t,
                    temperature = hourly.temperature.getOrNull(i)?.clean(),
                    condition = wmoToText(hourly.weatherCode.getOrNull(i)),
                    isForecast = false
                )
            } else null
        } ?: emptyList()
        YesterdayData(
            high = daily.tempMax.getOrNull(yIdx)?.clean(),
            low = daily.tempMin.getOrNull(yIdx)?.clean(),
            hourly = yHours
        )
    } else null

    val forecastHourly = hourly?.time?.mapIndexedNotNull { i, t ->
        if (t >= current.time) {
            HourlyItem(
                time = t,
                temperature = hourly.temperature.getOrNull(i)?.clean(),
                condition = wmoToText(hourly.weatherCode.getOrNull(i)),
                isForecast = true,
                rainProb = hourly.precipProb.getOrNull(i)?.toDouble()
            )
        } else null
    }?.take(48) ?: emptyList()

    val windSpeedKmh = current.windSpeed

    val uvMax = daily?.uvIndexMax?.getOrNull(todayIdx)

    val aqi = air?.current?.usAqi

    return WeatherData(
        cityName = cityName.ifBlank { "当前位置" },
        updatedAt = current.time.takeIf { it.length >= 16 }?.substring(5, 16)?.replace("T", " ") ?: current.time,
        temperature = current.temperature2m?.clean(),
        condition = wmoToText(current.weatherCode),
        feelsLike = current.apparentTemperature?.clean(),
        humidity = current.humidity,
        windDirect = current.windDirection?.let { windDirection(it) } ?: "",
        windPower = windSpeedKmh?.let { beaufort(it / 3.6) } ?: "",
        todayHigh = daily?.tempMax?.getOrNull(todayIdx)?.clean(),
        todayLow = daily?.tempMin?.getOrNull(todayIdx)?.clean(),
        aqi = aqi,
        aqiText = aqiText(aqi),
        warning = null,
        sunrise = daily?.sunrise?.getOrNull(todayIdx)?.takeIf { it.length >= 16 }?.substring(11, 16),
        sunset = daily?.sunset?.getOrNull(todayIdx)?.takeIf { it.length >= 16 }?.substring(11, 16),
        minutelyText = null,
        uvIndex = uvMax?.let { "${uvLevelText(it)}（${it.toInt()}）" } ?: "",
        sourceTag = "数据来源：Open-Meteo",
        hourly = forecastHourly,
        hourlyLabel = "未来48小时逐时预报",
        daily = dailyList,
        yesterday = yesterday,
        savedAt = System.currentTimeMillis()
    )
}

// ---------- 解析中央气象台数据 ----------

fun parseNmc(data: NmcData?, cityName: String): WeatherData {
    if (data == null) throw RuntimeException("气象局暂无数据")
    val real = data.real
    val weather = real?.weather
    val wind = real?.wind

    val todayHigh: Double?
    val todayLow: Double?
    var daily: List<DailyItem> = emptyList()
    val predict = data.predict?.detail ?: emptyList()
    if (predict.isNotEmpty()) {
        val first = predict[0]
        todayHigh = first.day?.weather?.temperature?.toDoubleOrNull()
        todayLow = first.night?.weather?.temperature?.toDoubleOrNull()
        daily = predict.map { d ->
            DailyItem(
                date = d.date,
                dayText = d.day?.weather?.info ?: "",
                nightText = d.night?.weather?.info ?: "",
                high = d.day?.weather?.temperature?.toDoubleOrNull(),
                low = d.night?.weather?.temperature?.toDoubleOrNull()
            )
        }
    } else {
        todayHigh = data.tempchart.lastOrNull()?.maxTemp?.clean()
        todayLow = data.tempchart.lastOrNull()?.minTemp?.clean()
        daily = data.tempchart.mapNotNull { t ->
            if (t.maxTemp?.clean() == null && t.minTemp?.clean() == null) null
            else DailyItem(
                date = t.time.replace("/", "-"),
                dayText = t.dayText.ifEmpty { t.nightText }.ifEmpty { "" },
                nightText = t.nightText,
                high = t.maxTemp.clean(),
                low = t.minTemp.clean()
            )
        }
    }

    // 过去24小时逐时（按时间正序）
    val passed = data.passedchart
        .filter { it.temperature?.clean() != null }
        .sortedBy { it.time }
        .map {
            HourlyItem(
                time = it.time,
                temperature = it.temperature.clean(),
                condition = "",
                isForecast = false
            )
        }

    // 昨日天气
    val yesterday: YesterdayData? = run {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val yItems = passed.filter { it.time.startsWith(today).not() }.takeLast(24)
        if (yItems.isEmpty()) {
            null
        } else {
            val temps = yItems.mapNotNull { it.temperature }
            val high = temps.maxOrNull()
            val low = temps.minOrNull()
            YesterdayData(high = high, low = low, hourly = yItems)
        }
    }

    val warning = real?.warn?.alert?.takeIf { it.isNotBlank() && it != "9999" }

    return WeatherData(
        cityName = cityName.ifBlank { real?.station?.city ?: "" },
        updatedAt = real?.publishTime ?: "",
        temperature = weather?.temperature?.clean(),
        condition = weather?.info ?: "",
        feelsLike = weather?.feelst?.clean(),
        humidity = weather?.humidity?.clean()?.toInt(),
        windDirect = wind?.direct ?: "",
        windPower = wind?.power ?: "",
        todayHigh = todayHigh,
        todayLow = todayLow,
        aqi = data.air?.aqi?.cleanInt(),
        aqiText = data.air?.text ?: "",
        warning = warning,
        sunrise = real?.sunriseSunset?.sunrise?.takeIf { it.length >= 16 }?.substring(11, 16),
        sunset = real?.sunriseSunset?.sunset?.takeIf { it.length >= 16 }?.substring(11, 16),
        sourceTag = "数据来源：中央气象台",
        hourly = passed,
        hourlyLabel = "过去24小时逐时实况",
        daily = daily,
        yesterday = yesterday,
        savedAt = System.currentTimeMillis()
    )
}

// ---------- 解析彩云天气数据 ----------

fun parseCaiyun(w: CaiyunWeather): WeatherData {
    val result = w.result ?: throw RuntimeException("彩云天气无数据")
    val rt = result.realtime
    val hourly = result.hourly
    val daily = result.daily

    if (rt == null) throw RuntimeException("彩云天气无实时数据")

    val cityName = result.location.getOrNull(1)?.takeIf { it.isNotBlank() }
        ?: result.location.getOrNull(0)
        ?: result.location.lastOrNull()
        ?: ""

    // 逐小时预报（未来）
    val hourlyList = buildHourlyList(hourly)

    val dailyList = buildDailyList(daily)

    val todayHigh = dailyList.firstOrNull()?.high
    val todayLow = dailyList.firstOrNull()?.low

    val astro = daily?.astro?.firstOrNull()
    val sunrise = astro?.sunrise?.time?.takeIf { it.isNotBlank() }
    val sunset = astro?.sunset?.time?.takeIf { it.isNotBlank() }

    val warning = extractAlert(result.alert)

    val windSpeed = rt.wind?.speed
    val windText = if (rt.wind?.direction != null && windSpeed != null) {
        "${windDirection(rt.wind.direction)} ${beaufort(windSpeed)}"
    } else ""

    val aqi = rt.airQuality?.aqi?.chn?.clean()?.toInt()

    return WeatherData(
        cityName = cityName,
        updatedAt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).format(Date()),
        temperature = rt.temperature?.clean(),
        condition = caiyunSkyconText(rt.skycon),
        feelsLike = rt.apparentTemperature?.clean(),
        humidity = rt.humidity?.let { (it * 100).toInt() },
        windDirect = rt.wind?.direction?.let { windDirection(it) } ?: "",
        windPower = windSpeed?.let { beaufort(it) } ?: "",
        todayHigh = todayHigh,
        todayLow = todayLow,
        aqi = aqi,
        aqiText = aqiText(aqi),
        warning = warning,
        sunrise = sunrise,
        sunset = sunset,
        minutelyText = result.minutely?.description?.takeIf { it.isNotBlank() },
        sourceTag = "数据来源：彩云天气",
        hourly = hourlyList,
        hourlyLabel = "未来48小时逐时预报",
        daily = dailyList,
        yesterday = null,
        savedAt = System.currentTimeMillis()
    )
}

private fun buildHourlyList(hourly: CaiyunHourly?): List<HourlyItem> {
    if (hourly == null) return emptyList()
    val temps = hourly.temperature
    val skys = hourly.skycon.associateBy { it.datetime }
    val rains = hourly.precipitation.associateBy { it.datetime }
    return temps.map { t ->
        val sky = skys[t.datetime]
        HourlyItem(
            time = t.datetime,
            temperature = t.value?.clean(),
            condition = caiyunSkyconText(skyconTextOf(sky?.value)),
            isForecast = true,
            rainProb = rains[t.datetime]?.value?.let { it * 100 }
        )
    }
}

private fun buildDailyList(daily: CaiyunDaily?): List<DailyItem> {
    if (daily == null) return emptyList()
    val skys = daily.skycon.associateBy { it.date }
    return daily.temperature.map { t ->
        val sky = skys[t.date]
        DailyItem(
            date = t.date,
            dayText = caiyunSkyconText(skyconTextOf(sky?.value)),
            nightText = "",
            high = t.max?.clean(),
            low = t.min?.clean()
        )
    }
}

private fun extractAlert(alertEl: kotlinx.serialization.json.JsonElement?): String? {
    if (alertEl == null) return null
    val json = Net.json
    return try {
        when (alertEl) {
            is kotlinx.serialization.json.JsonArray -> {
                alertEl.firstOrNull()?.let { el ->
                    val obj = el.jsonObject
                    val title = obj["title"]?.toString()?.trim('"')
                    val desc = obj["description"]?.toString()?.trim('"')
                    listOfNotNull(title, desc).joinToString("。").takeIf { it.isNotBlank() }
                }
            }
            is kotlinx.serialization.json.JsonObject -> {
                val title = alertEl["title"]?.toString()?.trim('"')
                val desc = alertEl["description"]?.toString()?.trim('"')
                listOfNotNull(title, desc).joinToString("。").takeIf { it.isNotBlank() }
            }
            else -> null
        }
    } catch (e: Exception) {
        null
    }
}