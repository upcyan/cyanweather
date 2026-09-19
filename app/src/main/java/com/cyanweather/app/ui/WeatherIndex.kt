package com.cyanweather.app.ui

import com.cyanweather.shared.model.WeatherData
import java.util.Locale

/** 降雨提醒文案：三档——逐时雨字紧急提示 / 未来12小时降水概率≥60% 带伞提醒 / 近期可能有雨提示。 */
internal fun buildRainReminder(w: WeatherData): String? {
    val upcoming = w.hourly.filter { it.isForecast }.take(12)
    if (upcoming.isNotEmpty()) {
        val idx = upcoming.indexOfFirst { it.condition.contains("雨") || it.condition.contains("雷") }
        if (idx >= 0) {
            return if (idx <= 1) "现在或很快有降雨，出门请带伞"
            else "预计约 ${idx} 小时后可能有降雨，出门请带伞"
        }
        // 概率档：现象未报雨但概率显著时兜底
        val maxProb = upcoming.mapNotNull { it.rainProb }.maxOrNull() ?: 0.0
        if (maxProb >= 60.0) return "未来12小时降水概率最高达 ${maxProb.toInt()}%，出门建议带伞"
    }
    val soon = w.daily.take(3).any { (it.dayText + it.nightText).contains("雨") || (it.dayText + it.nightText).contains("雷") }
    return if (soon) "近期可能有雨，请留意天气变化" else null
}

/** 温度展示：null/哨兵值显示 "-"，整数不带小数。 */
internal fun temp(v: Double?): String = v?.takeIf { it < 9998.0 }?.round() ?: "-"

private fun Double.round(): String =
    if (this % 1.0 == 0.0) this.toInt().toString() else String.format(Locale.US, "%.0f", this)

internal fun clothingIndex(temp: Double?, condition: String): String {
    val t = temp ?: return "-"
    return when {
        t >= 35 -> "酷热\n穿透气薄衣"
        t >= 30 -> "炎热\n短袖短裤"
        t >= 25 -> "温暖\n轻薄长袖"
        t >= 20 -> "舒适\n长袖薄外套"
        t >= 15 -> "微凉\n夹克毛衣"
        t >= 10 -> "凉爽\n厚外套"
        t >= 5 -> "寒冷\n棉衣羽绒"
        t >= 0 -> "很冷\n厚羽绒保暖"
        else -> "极寒\n防寒服加厚"
    }
}

internal fun exerciseIndex(temp: Double?, condition: String, aqi: Int?): String {
    val t = temp ?: return "-"
    val badWeather = condition.contains("雨") || condition.contains("雪") || condition.contains("雾") || condition.contains("霾")
    val badAqi = aqi != null && aqi > 150
    return when {
        badWeather -> "不宜\n天气不佳"
        badAqi -> "不宜\n空气质量差"
        t >= 35 -> "不宜\n高温炎热"
        t >= 30 && t < 35 -> "较不宜\n偏热"
        t >= 15 && t <= 28 -> "适宜\n温度舒适"
        t >= 10 && t < 15 -> "较适宜\n注意保暖"
        else -> "较不宜\n温度偏低"
    }
}

internal fun carwashIndex(condition: String, rainProb: Double?): String {
    val hasRain = condition.contains("雨") || condition.contains("雪") || (rainProb != null && rainProb > 50.0)
    return if (hasRain) "不宜\n有降水" else "适宜\n近期无雨"
}

internal fun coldIndex(tempHigh: Double?, tempLow: Double?): String {
    if (tempHigh == null || tempLow == null) return "-"
    val diff = tempHigh - tempLow
    return when {
        diff >= 12 -> "易发\n温差大，注意增减衣物"
        diff >= 8 -> "较易发\n温差较大"
        diff >= 5 -> "少发\n温差适中"
        else -> "不易发\n温差小"
    }
}
