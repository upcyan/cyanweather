package com.cyanweather.app

import com.cyanweather.app.ui.buildRainReminder
import com.cyanweather.app.ui.clothingIndex
import com.cyanweather.app.ui.exerciseIndex
import com.cyanweather.app.ui.carwashIndex
import com.cyanweather.app.ui.coldIndex
import com.cyanweather.app.ui.temp
import com.cyanweather.shared.model.HourlyItem
import com.cyanweather.shared.model.WeatherData
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class WeatherIndexTest {

    private fun weatherWithHourly(items: List<HourlyItem>) =
        WeatherData(cityName = "测试", hourly = items)

    // ---------- 降雨提醒 ----------

    @Test
    fun testRainReminderImmediate() {
        val w = weatherWithHourly(listOf(HourlyItem("2026-09-19T14:00", 20.0, "小雨", true)))
        assertEquals("现在或很快有降雨，出门请带伞", buildRainReminder(w))
    }

    @Test
    fun testRainReminderLater() {
        val items = (0 until 5).map { HourlyItem("t$it", 20.0, "晴", true) } +
            HourlyItem("t5", 20.0, "中雨", true)
        val tip = buildRainReminder(weatherWithHourly(items))
        assertEquals("预计约 5 小时后可能有降雨，出门请带伞", tip)
    }

    @Test
    fun testRainReminderByProbability() {
        // 现象无雨但未来 12 小时内概率 ≥60% → 带伞提醒
        val items = (0 until 11).map { HourlyItem("t$it", 20.0, "多云", true, rainProb = 20.0) } +
            HourlyItem("t11", 20.0, "多云", true, rainProb = 70.0)
        val tip = buildRainReminder(weatherWithHourly(items))
        assertTrue(tip != null && tip.contains("70%"), "实际: $tip")
    }

    @Test
    fun testRainReminderNone() {
        val items = (0 until 12).map { HourlyItem("t$it", 20.0, "晴", true, rainProb = 0.0) }
        assertNull(buildRainReminder(weatherWithHourly(items)))
    }

    @Test
    fun testRainReminderHistoricalRainNotCounted() {
        // 修复点：过去24小时实况（isForecast=false）不应触发"现在有雨"
        val items = listOf(HourlyItem("2026-09-19 13:00", 20.0, "中雨", false)) +
            (0 until 12).map { HourlyItem("t$it", 20.0, "晴", true) }
        assertNull(buildRainReminder(weatherWithHourly(items)))
    }

    // ---------- 温度展示 ----------

    @Test
    fun testTempFormatting() {
        assertEquals("-", temp(null))
        assertEquals("20", temp(20.0))
        assertEquals("20", temp(20.4))   // 修复前 20.4 会显示 "20.4"，对长辈不友好
        assertEquals("-", temp(9999.0))  // 哨兵值
    }

    // ---------- 生活指数 ----------

    @Test
    fun testClothingIndex() {
        assertTrue(clothingIndex(null, "晴").startsWith("-"))
        assertTrue(clothingIndex(32.0, "晴").contains("炎热"))
        assertTrue(clothingIndex(-5.0, "晴").contains("极寒"))
    }

    @Test
    fun testExerciseIndexBadAqi() {
        assertEquals("不宜\n空气质量差", exerciseIndex(22.0, "晴", 200))
        assertEquals("适宜\n温度舒适", exerciseIndex(22.0, "晴", 50))
    }

    @Test
    fun testCarwashIndex() {
        assertTrue(carwashIndex("晴", 80.0).startsWith("不宜"))
        assertTrue(carwashIndex("晴", 10.0).startsWith("适宜"))
    }

    @Test
    fun testColdIndex() {
        assertEquals("-", coldIndex(null, 10.0))
        assertTrue(coldIndex(25.0, 8.0).startsWith("易发"))
    }
}
