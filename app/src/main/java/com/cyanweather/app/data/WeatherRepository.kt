package com.cyanweather.app.data

import android.content.Context
import com.cyanweather.app.location.LocationHelper
import com.cyanweather.app.model.CaiyunWeather
import com.cyanweather.app.model.NmcCityItem
import com.cyanweather.app.model.NmcProvinceItem
import com.cyanweather.app.model.WeatherData
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.first

class WeatherRepository(
    private val context: Context,
    private val locationHelper: LocationHelper
) {

    suspend fun loadProvinces(): List<NmcProvinceItem> = NmcApi.getProvinces()

    suspend fun loadCities(provinceCode: String): List<NmcCityItem> = NmcApi.getCities(provinceCode)

    suspend fun loadAllCities(): List<NmcCityItem> {
        val provinces = NmcApi.getProvinces()
        return coroutineScope {
            provinces.map { p ->
                async { runCatching { NmcApi.getCities(p.code) }.getOrDefault(emptyList()) }
            }.awaitAll().flatten()
        }
    }

    suspend fun loadWeather(): WeatherData {
        val settings = SettingsStore.flow(context).first()
        return when {
            settings.source == "caiyun" && settings.caiyunMode == "v1" && settings.caiyunToken.isNotBlank() ->
                loadCaiyunV1(settings)
            settings.source == "caiyun" && settings.caiyunMode == "v3" &&
                settings.caiyunV3Key.isNotBlank() && settings.caiyunV3Secret.isNotBlank() -> loadCaiyunV3(settings)
            else -> when (settings.source) {
                "openmeteo" -> loadOpenMeteo(settings)
                else -> loadNmc(settings)
            }
        }
    }

    // ---------- 中央气象台 ----------

    private var cachedLocation: Triple<Double, Double, Pair<String, String>>? = null

    private suspend fun loadNmc(settings: AppSettings): WeatherData {
        var code = settings.cityCode
        var name = settings.cityName

        if (settings.useGps && !settings.manualCity) {
            val loc = locationHelper.getBestLocation()
            if (loc != null) {
                val cached = cachedLocation?.takeIf { it.first == loc.latitude && it.second == loc.longitude }
                if (cached != null) {
                    name = cached.third.first
                    code = cached.third.second
                } else {
                    try {
                        val (n, c) = resolveNmcByLocation(loc.latitude, loc.longitude)
                        cachedLocation = Triple(loc.latitude, loc.longitude, n to c)
                        name = n
                        code = c
                        SettingsStore.setCity(context, n, c, manual = false)
                    } catch (e: Exception) {
                        // 定位匹配失败时回退到手动选择城市
                    }
                }
            }
        }

        val finalCode = code.ifBlank { resolveBeijingCode() }
        val resp = NmcApi.getWeather(finalCode)
        val data = resp.data ?: throw RuntimeException("气象局暂无数据")
        return parseNmc(data, name.ifBlank { settings.cityName })
    }

    private suspend fun resolveNmcByLocation(lat: Double, lng: Double): Pair<String, String> {
        val geo = OpenMeteoApi.reverseGeocode(lat, lng)
            ?: throw RuntimeException("定位失败，无法自动选择城市")
        val provName = simp(geo.province).stripAdmin()
        val provinces = NmcApi.getProvinces()
        val prov = provinces.firstOrNull {
            val n = simp(it.name).stripAdmin()
            n.isNotEmpty() && (provName.isNotEmpty() && (n.contains(provName) || provName.contains(n)))
        } ?: provinces.first()
        val cities = NmcApi.getCities(prov.code)

        val targets = listOf(simp(geo.locality).stripAdmin(), simp(geo.city).stripAdmin()).filter { it.isNotEmpty() }
        val match = targets.firstNotNullOfOrNull { t ->
            cities.firstOrNull { c ->
                val cn = simp(c.city).stripAdmin()
                cn.isNotEmpty() && (cn == t || cn.contains(t) || t.contains(cn))
            }
        }
        val picked = match ?: cities.first()
        return picked.city to picked.code
    }

    private suspend fun resolveBeijingCode(): String {
        val provinces = NmcApi.getProvinces()
        val bj = provinces.firstOrNull { it.name.contains("北京") } ?: provinces.first()
        val cities = NmcApi.getCities(bj.code)
        val city = cities.firstOrNull { it.city.contains("北京") } ?: cities.first()
        return city.code
    }

    // ---------- 彩云天气 ----------

    private suspend fun loadCaiyunV1(settings: AppSettings): WeatherData {
        val token = settings.caiyunToken.trim()
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        if (settings.extendedForecast) {
            return loadCaiyunExtended(settings, lat, lng, name)
        }
        val resp = CaiyunApi.getWeatherV1(token, lat, lng)
        if (resp.status != "ok") throw RuntimeException("彩云接口返回异常，请检查 Token")
        return parseCaiyun(resp, name)
    }

    private suspend fun loadCaiyunV3(settings: AppSettings): WeatherData {
        val key = settings.caiyunV3Key.trim()
        val secret = settings.caiyunV3Secret.trim()
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        if (settings.extendedForecast) {
            return loadCaiyunExtended(settings, lat, lng, name)
        }
        val resp = CaiyunApi.getWeatherV3(key, secret, lat, lng)
        if (resp.status != "ok") throw RuntimeException("彩云接口返回异常，请检查 AppKey / AppSecret")
        return parseCaiyun(resp, name)
    }

    private suspend fun loadCaiyunExtended(settings: AppSettings, lat: Double, lng: Double, name: String): WeatherData {
        val token = settings.caiyunToken.trim()
        val days = settings.extendedDays
        val results = mutableListOf<CaiyunWeather>()
        coroutineScope {
            val jobs = mutableListOf<Deferred<CaiyunWeather?>>()
            // 昨天
            jobs += async { runCatching { CaiyunApi.getWeatherV1(token, lat, lng, -1, 1) }.getOrNull() }
            // 未来 N 天，每 5 天一批
            var offset = 0
            while (offset < days) {
                val batch = minOf(5, days - offset)
                val o = offset
                jobs += async { runCatching { CaiyunApi.getWeatherV1(token, lat, lng, o, batch) }.getOrNull() }
                offset += batch
            }
            jobs.forEach { j -> j.await()?.let { results.add(it) } }
        }
        val base = results.firstOrNull() ?: throw RuntimeException("彩云请求失败")
        return parseCaiyun(base, name)
    }

    private suspend fun resolveCaiyunCityName(settings: AppSettings, lat: Double, lng: Double): String {
        if (settings.manualCity) return settings.cityName
        return try {
            val geo = OpenMeteoApi.reverseGeocode(lat, lng)
            val name = geo?.let { simp(it.city).stripAdmin() + simp(it.locality).stripAdmin() } ?: ""
            name.ifBlank { settings.cityName }
        } catch (_: Exception) {
            settings.cityName
        }
    }

    // ---------- Open-Meteo ----------

    private suspend fun loadOpenMeteo(settings: AppSettings): WeatherData {
        val (lat, lng) = currentLatLng(settings)
        val w = OpenMeteoApi.getWeather(lat, lng)
        val air = OpenMeteoApi.getAirQuality(lat, lng)
        var cityName = "当前位置"
        if (settings.useGps) {
            try {
                OpenMeteoApi.reverseGeocode(lat, lng)?.let { geo ->
                    val name = simp(geo.city).stripAdmin() + simp(geo.locality).stripAdmin()
                    if (name.isNotBlank()) cityName = name
                }
            } catch (e: Exception) {
                // ignore
            }
        }
        return parseOpenMeteo(w, air, cityName)
    }

    private fun currentLatLng(settings: AppSettings): Pair<Double, Double> {
        if (settings.useGps) {
            val loc = locationHelper.getBestLocation()
            if (loc != null) {
                return loc.latitude to loc.longitude
            }
        }
        return settings.lat to settings.lng
    }

    // ---------- 名称归一化（繁体转简体、去行政区后缀） ----------

    private val TRAD_TO_SIMP = mapOf(
        "東" to "东", "濟" to "济", "廣" to "广", "陽" to "阳", "陰" to "阴",
        "臺" to "台", "灣" to "湾", "龍" to "龙", "雲" to "云", "島" to "岛",
        "縣" to "县", "區" to "区", "寧" to "宁", "蘇" to "苏", "澤" to "泽",
        "漢" to "汉", "濱" to "滨", "豐" to "丰", "麗" to "丽", "門" to "门",
        "華" to "华", "廈" to "厦", "閩" to "闽", "贛" to "赣", "晉" to "晋",
        "陝" to "陕", "貴" to "贵", "瓊" to "琼", "遼" to "辽", "鄒" to "邹",
        "臨" to "临", "萊" to "莱", "蕪" to "芜", "長" to "长", "慶" to "庆",
        "榮" to "荣", "單" to "单", "費" to "费", "濰" to "潍", "諸" to "诸",
        "兗" to "兖", "嶧" to "峄", "鄆" to "郓", "棲" to "栖", "遠" to "远",
        "樂" to "乐", "無" to "无", "蓮" to "莲", "齊" to "齐", "蘭" to "兰",
        "鄉" to "乡", "膠" to "胶", "黃" to "黄", "饒" to "饶", "興" to "兴",
        "棗" to "枣", "莊" to "庄", "幹" to "干", "烏" to "乌", "雙" to "双",
        "臺" to "台", "廈" to "厦", "澳" to "澳", "濰" to "潍", "蒼" to "苍",
        "濱" to "滨", "潁" to "颍", "滁" to "滁", "亳" to "亳", "懷" to "怀",
        "濰" to "潍", "滬" to "沪", "渝" to "渝", "贛" to "赣", "豫" to "豫",
        "冀" to "冀", "晉" to "晋", "蒙" to "蒙", "遼" to "辽", "吉" to "吉",
        "黑" to "黑", "蘇" to "苏", "浙" to "浙", "皖" to "皖", "閩" to "闽",
        "贛" to "赣", "魯" to "鲁", "鄂" to "鄂", "湘" to "湘", "粵" to "粤",
        "桂" to "桂", "瓊" to "琼", "川" to "川", "黔" to "黔", "滇" to "滇",
        "藏" to "藏", "陝" to "陕", "甘" to "甘", "青" to "青", "新" to "新",
        "寧" to "宁", "桂" to "桂"
    )

    private fun simp(s: String): String =
        s.map { TRAD_TO_SIMP[it.toString()] ?: it.toString() }.joinToString("")

    private fun String.stripAdmin(): String =
        replace(Regex("自治区|自治州|特别行政区|省|市|区|县|盟|州"), "")
}