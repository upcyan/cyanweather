package com.cyanweather.shared.data

import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import com.cyanweather.shared.model.YesterdayData
import kotlinx.datetime.Clock
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

object WeatherAggregator {

    private val SOURCE_WEIGHTS = mapOf(
        "nmc" to 0.9f,
        "openmeteo" to 0.8f,
        "caiyun" to 0.85f,
        "qweather" to 0.85f,
        "xiaomi" to 0.7f
    )

    private val SOURCE_NAMES = mapOf(
        "nmc" to "中国气象局",
        "openmeteo" to "Open-Meteo",
        "caiyun" to "彩云天气",
        "qweather" to "和风天气",
        "xiaomi" to "小米天气"
    )

    fun aggregate(sources: List<Pair<String, WeatherData>>): WeatherData {
        if (sources.isEmpty()) throw IllegalArgumentException("No sources to aggregate")
        if (sources.size == 1) return sources.first().second

        val primary = sources.first().second
        val contributions = mutableMapOf<String, String>()

        sources.forEach { (id, data) ->
            val name = SOURCE_NAMES[id] ?: id
            val fields = mutableListOf<String>()
            if (data.temperature != null) fields.add("温度")
            if (data.condition.isNotBlank()) fields.add("天气")
            if (data.humidity != null) fields.add("湿度")
            if (data.aqi != null) fields.add("AQI")
            if (data.hourly.isNotEmpty()) fields.add("逐时${data.hourly.size}h")
            if (data.daily.isNotEmpty()) fields.add("多日${data.daily.size}天")
            if (data.warning != null) fields.add("预警")
            if (data.uvIndex.isNotBlank()) fields.add("UV")
            if (fields.isNotEmpty()) contributions[name] = fields.joinToString("/")
        }

        val weights = sources.map { (id, _) -> SOURCE_WEIGHTS[id] ?: 0.7f }

        return WeatherData(
            cityName = primary.cityName,
            updatedAt = primary.updatedAt,
            temperature = aggregateDouble(sources.map { it.second.temperature }, weights),
            condition = aggregateCondition(sources.map { it.second.condition to (SOURCE_WEIGHTS[it.first] ?: 0.7f) }),
            feelsLike = aggregateDouble(sources.map { it.second.feelsLike }, weights),
            humidity = aggregateInt(sources.map { it.second.humidity }, weights),
            windDirect = primary.windDirect.ifBlank { sources.firstOrNull { it.second.windDirect.isNotBlank() }?.second?.windDirect ?: "" },
            windPower = primary.windPower.ifBlank { sources.firstOrNull { it.second.windPower.isNotBlank() }?.second?.windPower ?: "" },
            todayHigh = aggregateDouble(sources.map { it.second.todayHigh }, weights),
            todayLow = aggregateDouble(sources.map { it.second.todayLow }, weights),
            aqi = aggregateInt(sources.map { it.second.aqi }, weights),
            aqiText = computeAqiText(aggregateInt(sources.map { it.second.aqi }, weights)),
            warning = aggregateWarning(sources),
            sunrise = primary.sunrise ?: sources.firstOrNull { it.second.sunrise != null }?.second?.sunrise,
            sunset = primary.sunset ?: sources.firstOrNull { it.second.sunset != null }?.second?.sunset,
            minutelyText = primary.minutelyText ?: sources.firstOrNull { it.second.minutelyText != null }?.second?.minutelyText,
            uvIndex = aggregateUvIndex(sources),
            sourceTag = buildSourceTag(sources),
            hourly = aggregateHourly(sources),
            hourlyLabel = buildHourlyLabel(sources),
            daily = aggregateDaily(sources),
            yesterday = aggregateYesterday(sources),
            savedAt = primary.savedAt,
            sourceContributions = contributions,
            confidence = computeConfidence(sources, weights),
            pm25 = aggregateDouble(sources.map { it.second.pm25 }, weights),
            pm10 = aggregateDouble(sources.map { it.second.pm10 }, weights),
            windSpeed = aggregateDouble(sources.map { it.second.windSpeed }, weights)
        )
    }

    private fun aggregateDouble(values: List<Double?>, weights: List<Float>): Double? {
        val valid = values.zip(weights).filter { (v, _) -> v != null }.map { (v, w) -> v!! to w }
        if (valid.isEmpty()) return null
        if (valid.size == 1) return valid.first().first
        val filtered = robustFilter(valid)
        val totalWeight = filtered.sumOf { it.second.toDouble() }
        return filtered.sumOf { it.first * it.second } / totalWeight
    }

    private fun aggregateInt(values: List<Int?>, weights: List<Float>): Int? {
        val valid = values.zip(weights).filter { (v, _) -> v != null }.map { (v, w) -> v!!.toDouble() to w }
        if (valid.isEmpty()) return null
        if (valid.size == 1) return valid.first().first.roundToInt()
        val filtered = robustFilter(valid)
        val totalWeight = filtered.sumOf { it.second.toDouble() }
        val weightedSum = filtered.sumOf { it.first * it.second }
        // 四舍五入而非向零截断：避免湿度/AQI 聚合结果系统性偏小（与 Flutter 版 round() 对齐）
        return (weightedSum / totalWeight).roundToInt()
    }

    /**
     * 小样本稳健离群值过滤（MAD 法）。
     * 原实现用均值±2σ，但样本数 n≤6 时任何单点的 z 分数上界为 (n-1)/√n ≤ 2，
     * 过滤条件永远不触发，坏数据无法剔除；改用中位数±2.5·MAD，并设 1.0 绝对下限。
     */
    private fun robustFilter(valid: List<Pair<Double, Float>>): List<Pair<Double, Float>> {
        if (valid.size < 3) return valid
        val values = valid.map { it.first }
        val med = median(values)
        val mad = median(values.map { abs(it - med) })
        val threshold = maxOf(2.5 * mad, 1.0)
        val kept = valid.filter { abs(it.first - med) <= threshold }
        return kept.ifEmpty { valid }
    }

    private fun median(values: List<Double>): Double {
        val sorted = values.sorted()
        val n = sorted.size
        return if (n % 2 == 1) sorted[n / 2] else (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    }

    private fun aggregateCondition(entries: List<Pair<String, Float>>): String {
        val nonBlank = entries.filter { it.first.isNotBlank() }
        if (nonBlank.isEmpty()) return ""
        if (nonBlank.size == 1) return nonBlank.first().first
        val sorted = nonBlank.sortedByDescending { it.second }
        return sorted.first().first
    }

    private fun aggregateWarning(sources: List<Pair<String, WeatherData>>): String? {
        val nmcWarning = sources.firstOrNull { it.first == "nmc" }?.second?.warning
        if (nmcWarning != null) return nmcWarning
        return sources.firstOrNull { it.second.warning != null }?.second?.warning
    }

    private fun aggregateUvIndex(sources: List<Pair<String, WeatherData>>): String {
        val primary = sources.first().second
        if (primary.uvIndex.isNotBlank()) return primary.uvIndex
        return sources.firstOrNull { it.second.uvIndex.isNotBlank() }?.second?.uvIndex ?: ""
    }

    private fun aggregateHourly(sources: List<Pair<String, WeatherData>>): List<HourlyItem> {
        val allHourly = sources.map { (id, data) ->
            data.hourly.map { it to (SOURCE_WEIGHTS[id] ?: 0.7f) }
        }.flatten()
        if (allHourly.isEmpty()) return emptyList()
        // 先规范化时间戳（气象局用空格分隔、其它源用 T），否则同一小时无法合并
        val normalized = allHourly.map { (item, w) -> item.copy(time = normalizeHourTime(item.time)) to w }
        val grouped = normalized.groupBy { it.first.time }
        return grouped.map { (time, items) ->
            val temps = items.map { it.first.temperature to it.second }
            val conds = items.map { it.first.condition to it.second }
            val rainProbs = items.filter { it.first.rainProb != null }.map { it.first.rainProb!! to it.second }
            HourlyItem(
                time = time,
                temperature = aggregateDouble(temps.map { it.first }, temps.map { it.second }),
                condition = aggregateCondition(conds),
                isForecast = items.any { it.first.isForecast },
                rainProb = if (rainProbs.isNotEmpty()) aggregateDouble(rainProbs.map { it.first }, rainProbs.map { it.second }) else null
            )
        }.sortedBy { it.time }
            // 气象局实况时段无天气文字，排在最前会导致逐时列表开头一排空卡；剔除已过去的非预报时段
            .filter { it.isForecast || it.time > currentHourKey() }
    }

    /** 当前本地小时起点（ISO yyyy-MM-ddTHH:00） */
    private fun currentHourKey(): String {
        val t = Clock.System.now().toLocalDateTime(TimeZone.currentSystemDefault())
        val d = t.date
        fun p2(v: Int) = v.toString().padStart(2, '0')
        return "${d.year}-${p2(d.monthNumber)}-${p2(d.dayOfMonth)}T${p2(t.hour)}:00"
    }

    private fun aggregateDaily(sources: List<Pair<String, WeatherData>>): List<DailyItem> {
        val allDaily = sources.map { (id, data) ->
            data.daily.map { it to (SOURCE_WEIGHTS[id] ?: 0.7f) }
        }.flatten()
        if (allDaily.isEmpty()) return emptyList()
        val grouped = allDaily.groupBy { it.first.date }
        return grouped.map { (date, items) ->
            val highs = items.map { it.first.high to it.second }
            val lows = items.map { it.first.low to it.second }
            val dayTexts = items.filter { it.first.dayText.isNotBlank() }.map { it.first.dayText to it.second }
            val nightTexts = items.filter { it.first.nightText.isNotBlank() }.map { it.first.nightText to it.second }
            DailyItem(
                date = date,
                dayText = aggregateCondition(dayTexts),
                nightText = aggregateCondition(nightTexts),
                high = aggregateDouble(highs.map { it.first }, highs.map { it.second }),
                low = aggregateDouble(lows.map { it.first }, lows.map { it.second })
            )
        }.sortedBy { it.date }
    }

    private fun aggregateYesterday(sources: List<Pair<String, WeatherData>>): YesterdayData? {
        val yesterdays = sources.mapNotNull { it.second.yesterday }
        if (yesterdays.isEmpty()) return null
        val highs = yesterdays.mapNotNull { it.high }
        val lows = yesterdays.mapNotNull { it.low }
        val hourly = yesterdays.flatMap { it.hourly }.groupBy { it.time }.map { (time, items) ->
            HourlyItem(
                time = time,
                temperature = aggregateDouble(items.map { it.temperature }, items.map { 0.8f }),
                condition = aggregateCondition(items.map { it.condition to 0.8f }),
                isForecast = false
            )
        }.sortedBy { it.time }
        return YesterdayData(
            high = highs.ifEmpty { null }?.let { it.sum() / it.size },
            low = lows.ifEmpty { null }?.let { it.sum() / it.size },
            hourly = hourly
        )
    }

    private fun buildSourceTag(sources: List<Pair<String, WeatherData>>): String {
        val names = sources.map { SOURCE_NAMES[it.first] ?: it.first }
        return "数据来源：${names.joinToString(" + ")}（智能聚合）"
    }

    private fun buildHourlyLabel(sources: List<Pair<String, WeatherData>>): String {
        val maxHourly = sources.maxOfOrNull { it.second.hourly.size } ?: 0
        return "未来${maxHourly}小时逐时预报（多源聚合）"
    }

    private fun computeConfidence(sources: List<Pair<String, WeatherData>>, weights: List<Float>): Float {
        if (sources.size == 1) return weights.first()
        val totalWeight = weights.sum()
        val maxPossibleWeight = sources.size * 0.9f
        val coverage = totalWeight / maxPossibleWeight
        val agreement = computeAgreement(sources)
        return (coverage * 0.4f + agreement * 0.6f).coerceIn(0f, 1f)
    }

    private fun computeAgreement(sources: List<Pair<String, WeatherData>>): Float {
        if (sources.size < 2) return 1f
        val temps = sources.mapNotNull { it.second.temperature }
        if (temps.size < 2) return 1f
        val mean = temps.sum() / temps.size
        val std = standardDeviation(temps)
        val maxStd = 5.0
        return ((maxStd - std) / maxStd).coerceIn(0.0, 1.0).toFloat()
    }

    private fun standardDeviation(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.sum() / values.size
        val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
        return sqrt(variance)
    }

    private fun computeAqiText(aqi: Int?): String = when {
        aqi == null -> ""
        aqi <= 50 -> "优"
        aqi <= 100 -> "良"
        aqi <= 150 -> "轻度污染"
        aqi <= 200 -> "中度污染"
        aqi <= 300 -> "重度污染"
        else -> "严重污染"
    }
}
