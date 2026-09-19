package com.cyanweather.shared

import com.cyanweather.shared.data.WeatherAggregator
import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AggregatorTest {

    private fun data(
        id: String,
        temp: Double? = 20.0,
        hourly: List<HourlyItem> = emptyList(),
        condition: String = "晴"
    ) = WeatherData(
        cityName = "测试市",
        temperature = temp,
        condition = condition,
        sourceTag = id,
        hourly = hourly
    )

    @Test
    fun testSingleSourcePassthrough() {
        val w = WeatherAggregator.aggregate(listOf("nmc" to data("nmc", temp = 25.5)))
        assertEquals(25.5, w.temperature)
    }

    @Test
    fun testTwoSourcesAverage() {
        val w = WeatherAggregator.aggregate(listOf("nmc" to data("nmc", 20.0), "openmeteo" to data("openmeteo", 22.0)))
        // 两源按权重(0.9/0.8)加权平均，介于 20~22 之间且偏向气象局
        val t = w.temperature!!
        assertTrue(t in 20.0..22.0 && t < 21.1, "聚合温度 $t")
    }

    @Test
    fun testOutlierFiltered() {
        // 一个源坏数据（如 35 度）应被稳健过滤，不拉高聚合结果
        val w = WeatherAggregator.aggregate(
            listOf(
                "nmc" to data("nmc", 20.0),
                "openmeteo" to data("openmeteo", 21.0),
                "caiyun" to data("caiyun", 35.0)
            )
        )
        assertTrue(w.temperature!! < 23.0, "聚合温度 ${w.temperature}，坏数据未过滤")
    }

    @Test
    fun testHourlyMergedAcrossFormats() {
        // 修复点：气象局 "2026-09-19 14:00"（空格）与 Open-Meteo "2026-09-19T14:00" 应合并为同一小时
        val w = WeatherAggregator.aggregate(
            listOf(
                "nmc" to data("nmc", hourly = listOf(HourlyItem("2026-09-19 14:00", 18.0, "", false))),
                "openmeteo" to data("openmeteo", hourly = listOf(HourlyItem("2026-09-19T14:00", 20.0, "多云", true)))
            )
        )
        assertEquals(1, w.hourly.size, "同一小时未合并: ${w.hourly.map { it.time }}")
        assertEquals("2026-09-19T14:00", w.hourly.first().time)
        val t = w.hourly.first().temperature!!
        assertTrue(t in 18.0..20.0, "合并后温度 $t")
    }

    @Test
    fun testEmptyThrows() {
        try {
            WeatherAggregator.aggregate(emptyList())
            throw AssertionError("应当抛异常")
        } catch (e: IllegalArgumentException) {
            // expected
        }
    }

    @Test
    fun testSourceTagAndConfidence() {
        val w = WeatherAggregator.aggregate(listOf("nmc" to data("nmc"), "openmeteo" to data("openmeteo")))
        assertTrue(w.sourceTag.contains("中国气象局"))
        assertTrue(w.confidence in 0f..1f)
        assertTrue(w.sourceContributions.isNotEmpty())
    }

    @Test
    fun testDailyMergedByDate() {
        val a = data("nmc").copy(daily = listOf(DailyItem("2026-09-20", "晴", "多云", 28.0, 18.0)))
        val b = data("openmeteo").copy(daily = listOf(DailyItem("2026-09-20", "多云", "", 29.0, 19.0)))
        val w = WeatherAggregator.aggregate(listOf("nmc" to a, "openmeteo" to b))
        assertEquals(1, w.daily.size)
        val h = w.daily.first().high!!
        assertTrue(h in 28.0..29.0, "合并高温 $h")
    }
}
