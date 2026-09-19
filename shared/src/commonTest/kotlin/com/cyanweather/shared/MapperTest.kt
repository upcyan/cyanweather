package com.cyanweather.shared

import com.cyanweather.shared.data.normalizeHourTime
import com.cyanweather.shared.data.parseCaiyun
import com.cyanweather.shared.data.parseOpenMeteo
import com.cyanweather.shared.data.wmoToText
import com.cyanweather.shared.data.caiyunSkyconText
import com.cyanweather.shared.data.windDirection
import com.cyanweather.shared.data.beaufort
import com.cyanweather.shared.data.aqiText
import com.cyanweather.shared.model.CaiyunAqi
import com.cyanweather.shared.model.CaiyunAirQuality
import com.cyanweather.shared.model.CaiyunDaily
import com.cyanweather.shared.model.CaiyunDailyTemp
import com.cyanweather.shared.model.CaiyunHourly
import com.cyanweather.shared.model.CaiyunRealtime
import com.cyanweather.shared.model.CaiyunResult
import com.cyanweather.shared.model.CaiyunTItem
import com.cyanweather.shared.model.CaiyunWeather
import com.cyanweather.shared.model.CaiyunWind
import com.cyanweather.shared.model.CaiyunSItem
import kotlinx.serialization.json.JsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class MapperTest {

    // 测试数据必须用“今天”，因为 parseCaiyun/parseOpenMeteo 内部按当前日期过滤
    private val today: String = java.time.LocalDate.now().toString()

    // ---------- normalizeHourTime：多源聚合时间对齐 ----------

    @Test
    fun testNormalizeIsoT() {
        assertEquals("2026-09-19T14:00", normalizeHourTime("2026-09-19T14:00"))
    }

    @Test
    fun testNormalizeSpaceSeparated() {
        // 气象局实况格式：空格分隔 —— 修复前与 ISO 的 "T" 无法聚合到同一小时
        assertEquals("2026-09-19 14:00", "2026-09-19 14:00".let { normalizeHourTime(it).replace('T', ' ') })
    }

    @Test
    fun testNormalizeShortMonthDay() {
        // 气象局 passedchart 的 "MM-dd HH:mm" 格式，应补当前年份
        val normalized = normalizeHourTime("09-19 08:00")
        assertTrue(Regex("^\\d{4}-09-19T08:00$").matches(normalized), "实际: $normalized")
    }

    @Test
    fun testNormalizeNonZeroPadded() {
        assertEquals("2026-09-01T08:05", normalizeHourTime("2026/9/1 8:05"))
    }

    @Test
    fun testNormalizeInvalidUnchanged() {
        assertEquals("abc", normalizeHourTime("abc"))
    }

    // ---------- 风向 / 风级 / AQI ----------

    @Test
    fun testWindDirectionBoundaries() {
        assertEquals("北风", windDirection(0.0))
        assertEquals("北风", windDirection(350.0))  // 修复前 (350+22.5)/45=8 → 越界崩溃
        assertEquals("北风", windDirection(337.5))
        assertEquals("西北风", windDirection(337.4))
        assertEquals("东北风", windDirection(45.0))
    }

    @Test
    fun testBeaufortFullRange() {
        assertEquals("0级", beaufort(0.0))
        assertEquals("5级", beaufort(10.0))
        assertEquals("9级", beaufort(22.0))   // 修复前 22m/s 也显示 9 级
        assertEquals("10级", beaufort(25.0))
        assertEquals("12级", beaufort(40.0))  // 台风级
    }

    @Test
    fun testAqiText() {
        assertEquals("", aqiText(null))
        assertEquals("优", aqiText(50))
        assertEquals("良", aqiText(99))
        assertEquals("严重污染", aqiText(500))
    }

    // ---------- WMO 天气码 ----------

    @Test
    fun testWmoCodes() {
        assertEquals("晴", wmoToText(0))
        assertEquals("阴", wmoToText(3))
        assertEquals("雷阵雨", wmoToText(95))
        assertEquals("-", wmoToText(null))
    }

    // ---------- 彩云解析 ----------

    private fun caiyunWeather(): CaiyunWeather = CaiyunWeather(
        status = "ok",
        result = CaiyunResult(
            realtime = CaiyunRealtime(
                temperature = 23.4,
                humidity = 0.65,
                skycon = "CLEAR_DAY",
                apparentTemperature = 24.0,
                wind = CaiyunWind(speed = 3.2, direction = 135.0),
                airQuality = CaiyunAirQuality(aqi = CaiyunAqi(chn = 55.0))
            ),
            hourly = CaiyunHourly(
                temperature = listOf(CaiyunTItem("$today T12:00".replace(" ", ""), 25.0)),
                skycon = listOf(CaiyunSItem("$today" + "T12:00", JsonPrimitive("RAIN"))),
                precipitation = listOf(CaiyunTItem("$today" + "T12:00", 0.35))
            ),
            daily = CaiyunDaily(
                temperature = listOf(
                    CaiyunDailyTemp("${today}T00:00", 30.0, 21.0)
                ),
                skycon = listOf(),
                astro = listOf()
            ),
            alert = null
        )
    )

    @Test
    fun testParseCaiyunBasics() {
        val w = parseCaiyun(caiyunWeather(), "测试市")
        assertEquals(23.4, w.temperature)
        assertEquals("晴", w.condition)
        // 修复前湿度被放大 100 倍（0.65 → 65 是对的，但若上游已是 65 就会变 6500）：
        // 这里验证 0~1 小数口径被正确转为百分比
        assertEquals(65, w.humidity)
        assertEquals(55, w.aqi)
        assertEquals("东南风", w.windDirect)
        // 分钟级/逐时
        assertEquals(0.35 * 100, w.hourly.first().rainProb!!, 0.001)
    }

    @Test
    fun testParseCaiyunHourlyRainProbConverted() {
        val w = parseCaiyun(caiyunWeather(), "测试市")
        // 未映射 skycon 码按关键词降级为中文
        assertEquals("雨", w.hourly.first().condition)
    }

    @Test
    fun testCaiyunSkyconFallback() {
        assertEquals("雨", caiyunSkyconText("RAIN"))
        assertEquals("小雨", caiyunSkyconText("LIGHT_RAIN"))
        assertEquals("雪", caiyunSkyconText("HEAVY_SNOW_V2"))
    }

    // ---------- Open-Meteo 解析 ----------

    @Test
    fun testParseOpenMeteoWindSpeedConvertedToMs() {
        val resp = OpenMeteoRespForTest()
        val w = parseOpenMeteo(resp, null, "测试市")
        // API 返回 18 km/h → 应为 5.0 m/s（修复前直接存 18 且界面按 m/s 展示）
        assertEquals(5.0, w.windSpeed!!, 0.001)
    }

    private fun OpenMeteoRespForTest() = com.cyanweather.shared.model.OpenMeteoResponse(
        current = com.cyanweather.shared.model.OpenMeteoCurrent(
            time = "${today}T12:00",
            temperature2m = 20.0,
            humidity = 60,
            apparentTemperature = 19.0,
            weatherCode = 2,
            windSpeed = 18.0,
            windDirection = 90.0
        ),
        hourly = com.cyanweather.shared.model.OpenMeteoHourly(
            time = listOf("${today}T13:00", "${today}T14:00"),
            temperature = listOf(21.0, 22.0),
            weatherCode = listOf(3, 61),
            precipProb = listOf(10, 70)
        ),
        daily = com.cyanweather.shared.model.OpenMeteoDaily(
            time = listOf(today),
            weatherCode = listOf(2),
            tempMax = listOf(28.0),
            tempMin = listOf(18.0),
            sunrise = listOf("${today}T06:00"),
            sunset = listOf("${today}T18:00"),
            uvIndexMax = listOf(5.0)
        )
    )
}
