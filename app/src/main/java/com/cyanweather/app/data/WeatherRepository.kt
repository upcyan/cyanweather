package com.cyanweather.app.data

import android.content.Context
import com.cyanweather.app.location.LocationHelper
import com.cyanweather.shared.data.CaiyunApi
import com.cyanweather.shared.data.NmcApi
import com.cyanweather.shared.data.OpenMeteoApi
import com.cyanweather.shared.data.AmapApi
import com.cyanweather.shared.data.MetNoApi
import com.cyanweather.shared.data.QWeatherApi
import com.cyanweather.shared.data.XiaomiWeatherApi
import com.cyanweather.shared.data.caiyunSkyconText
import com.cyanweather.shared.data.parseCaiyun
import com.cyanweather.shared.data.parseNmc
import com.cyanweather.shared.data.parseOpenMeteo
import com.cyanweather.shared.model.CaiyunWeather
import com.cyanweather.shared.model.DailyItem
import com.cyanweather.shared.model.NmcCityItem
import com.cyanweather.shared.model.NmcProvinceItem
import com.cyanweather.shared.model.WeatherData
import com.cyanweather.shared.model.clean
import com.cyanweather.shared.model.skyconTextOf
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.first

class WeatherRepository(
    private val context: Context,
    private val locationHelper: LocationHelper
) {

    suspend fun loadProvinces(): List<NmcProvinceItem> = NmcApi.loadProvinces()

    suspend fun loadCities(provinceCode: String): List<NmcCityItem> = NmcApi.loadCities(provinceCode)

    suspend fun loadAllCities(): List<NmcCityItem> {
        val provinces = NmcApi.loadProvinces()
        return coroutineScope {
            provinces.map { p ->
                async { runCatching { NmcApi.loadCities(p.code) }.getOrDefault(emptyList()) }
            }.awaitAll().flatten()
        }
    }

    suspend fun loadWeather(): WeatherData {
        val settings = SettingsStore.flow(context).first()
        val selected = settings.weatherSources.filter { it in SUPPORTED_SOURCES }
            .ifEmpty { listOf("nmc", "openmeteo") }
        val results = mutableListOf<Pair<String, WeatherData>>()
        val failures = mutableListOf<String>()
        // 并发请求所有数据源：总耗时 = 最慢单源（15s 超时），而非各源串行累加（N 源最坏 N×15s）。
        // 注意 runCatching 会把 CancellationException 一起捕获成结果，所以在这里分型处理，
        // 刷新被新请求取代/作用域取消时必须原样上抛，不能当成单个数据源的失败。
        val outcome = coroutineScope {
            selected.map { source ->
                async { source to runCatching { loadSource(source, settings) } }
            }.awaitAll()
        }
        for ((source, result) in outcome) {
            result.fold(
                onSuccess = { results += source to it },
                onFailure = { e ->
                    when (e) {
                        is kotlinx.coroutines.CancellationException -> throw e
                        else -> failures += "${sourceName(source)}：${e.message ?: "不可用"}"
                    }
                }
            )
        }
        if (results.isEmpty()) {
            throw RuntimeException(failures.joinToString("；").ifBlank { "没有启用可用的天气源" })
        }
        return if (results.size == 1) {
            results.first().second.copy(
                sourceTag = "数据来源：${sourceName(results.first().first)}"
            )
        } else {
            com.cyanweather.shared.data.WeatherAggregator.aggregate(results)
        }
    }

    private suspend fun loadSource(source: String, settings: AppSettings): WeatherData = when (source) {
        "qweather" -> loadQWeather(settings)
        "metno" -> loadMetNo(settings)
        "amap" -> loadAmap(settings)
        "xiaomi" -> loadXiaomi(settings)
        "openmeteo" -> loadOpenMeteo(settings)
        "caiyun" -> when {
            settings.caiyunMode == "v1" && settings.caiyunToken.isNotBlank() -> loadCaiyunV1(settings)
            settings.caiyunMode == "v3" && settings.caiyunV3Key.isNotBlank() && settings.caiyunV3Secret.isNotBlank() -> loadCaiyunV3(settings)
            else -> throw RuntimeException("凭证未填写完整")
        }
        else -> loadNmc(settings)
    }

    private suspend fun loadQWeather(settings: AppSettings): WeatherData {
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        return QWeatherApi.weather(settings.qweatherHost, settings.qweatherKey, lat, lng, name)
    }

    private suspend fun loadMetNo(settings: AppSettings): WeatherData {
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        return MetNoApi.weather(lat, lng, name)
    }

    private suspend fun loadAmap(settings: AppSettings): WeatherData {
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        return AmapApi.weather(settings.amapKey, lat, lng, name)
    }

    private suspend fun loadXiaomi(settings: AppSettings): WeatherData {
        XiaomiLocalWeather.read(context)?.let { return it }
        val (lat, lng) = currentLatLng(settings)
        var code = settings.cityCode
        var name = settings.cityName
        if (code.isBlank()) {
            val resolved = resolveNmcByLocation(lat, lng)
            name = resolved.first
            code = resolved.second
        }
        return XiaomiWeatherApi.weather(lat, lng, code, name)
    }

    private fun mergePrimary(primary: WeatherData, fallback: WeatherData, tag: String): WeatherData {
        val useFallbackHourly = primary.hourly.isEmpty() ||
            (!primary.hourlyLabel.contains("预报") && fallback.hourlyLabel.contains("预报"))
        return primary.copy(
        cityName = primary.cityName.ifBlank { fallback.cityName },
        temperature = primary.temperature ?: fallback.temperature,
        condition = primary.condition.ifBlank { fallback.condition },
        feelsLike = primary.feelsLike ?: fallback.feelsLike,
        humidity = primary.humidity ?: fallback.humidity,
        windDirect = primary.windDirect.ifBlank { fallback.windDirect },
        windPower = primary.windPower.ifBlank { fallback.windPower },
        todayHigh = primary.todayHigh ?: fallback.todayHigh,
        todayLow = primary.todayLow ?: fallback.todayLow,
        aqi = primary.aqi ?: fallback.aqi,
        aqiText = primary.aqiText ?: fallback.aqiText,
        warning = primary.warning ?: fallback.warning,
        sunrise = primary.sunrise ?: fallback.sunrise,
        sunset = primary.sunset ?: fallback.sunset,
        minutelyText = primary.minutelyText ?: fallback.minutelyText,
        uvIndex = primary.uvIndex.ifBlank { fallback.uvIndex },
        sourceTag = tag,
        hourly = if (useFallbackHourly) fallback.hourly else primary.hourly,
        hourlyLabel = if (useFallbackHourly) fallback.hourlyLabel else primary.hourlyLabel,
        daily = if (primary.daily.size >= fallback.daily.size) primary.daily
            else primary.daily + fallback.daily.drop(primary.daily.size),
        yesterday = primary.yesterday ?: fallback.yesterday
        )
    }

    private fun sourceName(source: String): String = when (source) {
        "nmc" -> "中国气象局"
        "openmeteo" -> "Open-Meteo"
        "caiyun" -> "彩云天气"
        "qweather" -> "和风天气"
        "xiaomi" -> "小米天气"
        else -> source
    }

    companion object {
        private val SUPPORTED_SOURCES = setOf("nmc", "openmeteo", "caiyun", "qweather", "xiaomi", "metno", "amap")
    }

    // ---------- NMC ----------

    private var cachedLocation: Triple<Double, Double, Pair<String, String>>? = null

    private suspend fun loadNmc(settings: AppSettings): WeatherData {
        var code = settings.cityCode
        var name = settings.cityName

        if (settings.useGps && !settings.manualCity) {
            // Use real location (fetch GPS if coords still at Beijing defaults)
            val (lat, lng) = currentLatLng(settings)
            val cached = cachedLocation?.takeIf { it.first == lat && it.second == lng }
            if (cached != null) {
                name = cached.third.first
                code = cached.third.second
            } else {
                try {
                    val (n, c) = resolveNmcByLocation(lat, lng)
                    cachedLocation = Triple(lat, lng, n to c)
                    name = n
                    code = c
                    SettingsStore.setCity(context, n, c, manual = false)
                } catch (e: Exception) {
                    // GPS resolution failed, fallback to manual city
                }
            }
        }

        val finalCode = code.ifBlank { resolveBeijingCode() }
        val data = NmcApi.weatherByStationId(finalCode)
        return parseNmc(data, name.ifBlank { settings.cityName })
    }

    private suspend fun resolveNmcByLocation(lat: Double, lng: Double): Pair<String, String> {
        val geo = OpenMeteoApi.reverseGeocodeFull(lat, lng)
            ?: throw RuntimeException("定位失败，无法自动选择城市")
        val provName = simp(geo.first).trim()
        val cityName = simp(geo.second).trim()
        val locName = simp(geo.third).trim()
        if (provName.isBlank() && cityName.isBlank() && locName.isBlank()) {
            throw RuntimeException("定位失败，无法自动选择城市")
        }

        val provinces = NmcApi.loadProvinces()
        val prov = provinces.firstOrNull { p ->
            val n = simp(p.name).stripAdmin()
            n.isNotEmpty() && provName.contains(n)
        } ?: provinces.firstOrNull { p ->
            val n = simp(p.name).stripAdmin()
            n.isNotEmpty() && (cityName.contains(n) || locName.contains(n))
        } ?: provinces.first()
        val cities = NmcApi.loadCities(prov.code)

        fun matches(g: String, c: NmcCityItem): Boolean {
            val full = simp(c.city).trim()
            if (full.isEmpty()) return false
            val stripped = full.stripAdmin()
            return full == g || g.startsWith(full) || g.contains(full) ||
                (stripped.length >= 2 && (stripped == g || g.startsWith(stripped) || g.contains(stripped)))
        }

        val geoParts = listOfNotNull(locName, cityName)
        var match: NmcCityItem? = null
        for (g in geoParts) {
            match = cities.firstOrNull { matches(g, it) }
            if (match != null) break
        }
        val picked = match ?: cities.firstOrNull { c -> geoParts.any { g -> matches(g, c) } }
            ?: cities.first()

        // 显示用名称优先取 locality（如 宿松县），退而取城市名
        val displayName = locName.ifBlank { cityName.ifBlank { picked.city } }
        return displayName to picked.code
    }

    private suspend fun resolveBeijingCode(): String {
        val provinces = NmcApi.loadProvinces()
        val bj = provinces.firstOrNull { it.name.contains("北京") } ?: provinces.first()
        val cities = NmcApi.loadCities(bj.code)
        val city = cities.firstOrNull { it.city.contains("北京") } ?: cities.first()
        return city.code
    }

    // ---------- Caiyun ----------

    private suspend fun loadCaiyunV1(settings: AppSettings): WeatherData {
        val token = settings.caiyunToken.trim()
        val (lat, lng) = currentLatLng(settings)
        val name = resolveCaiyunCityName(settings, lat, lng)
        if (settings.extendedForecast) {
            return loadCaiyunExtended(settings, lat, lng, name)
        }
        val resp = CaiyunApi.weatherV1(token, lat, lng)
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
        val resp = CaiyunApi.weatherV3(key, secret, lat, lng)
        if (resp.status != "ok") throw RuntimeException("彩云接口返回异常，请检查 AppKey / AppSecret")
        return parseCaiyun(resp, name)
    }

    private suspend fun loadCaiyunExtended(settings: AppSettings, lat: Double, lng: Double, name: String): WeatherData {
        val token = settings.caiyunToken.trim()
        val days = settings.extendedDays.coerceAtLeast(3)
        // 免费版单次最多返回 3 天，按 3 天一批无缝拼接；
        // 开启「获取昨日天气」时首批从 dailystart=-1 开始（昨日+今明两天）
        val firstStart = if (settings.getYesterday) -1 else 0
        val batches = mutableListOf<CaiyunWeather>()
        coroutineScope {
            val jobs = mutableListOf<Deferred<CaiyunWeather?>>()
            jobs += async { runCatching { CaiyunApi.weatherV1(token, lat, lng, firstStart, 3) }.getOrNull() }
            var start = firstStart + 3
            while (start < days) {
                val s = start
                jobs += async { runCatching { CaiyunApi.weatherV1(token, lat, lng, s, 3) }.getOrNull() }
                start += 3
            }
            jobs.forEach { j -> j.await()?.let { batches.add(it) } }
        }
        val base = batches.firstOrNull() ?: throw RuntimeException("彩云请求失败")
        val parsed = parseCaiyun(base, name)
        if (batches.size == 1) return parsed

        // 按日期去重合并后续批次的多日预报
        val mergedDaily = parsed.daily.toMutableList()
        val seen = mergedDaily.map { it.date }.toMutableSet()
        batches.drop(1).forEach { resp ->
            val r = resp.result ?: return@forEach
            val daily = r.daily ?: return@forEach
            val temps = daily.temperature ?: return@forEach
            val skys = daily.skycon.associateBy { it.date }
            temps.forEach { t ->
                val dateStr = if (t.date.contains("T")) t.date.substring(0, 10) else t.date
                if (dateStr in seen) return@forEach
                val sky = skys[t.date]
                mergedDaily.add(
                    DailyItem(
                        date = dateStr,
                        dayText = caiyunSkyconText(skyconTextOf(sky?.value)),
                        nightText = "",
                        high = t.max?.clean(),
                        low = t.min?.clean()
                    )
                )
                seen.add(dateStr)
            }
        }
        return parsed.copy(daily = mergedDaily.sortedBy { it.date })
    }

    private suspend fun resolveCaiyunCityName(settings: AppSettings, lat: Double, lng: Double): String {
        if (settings.manualCity) return settings.cityName
        return try {
            val geoName = OpenMeteoApi.reverseGeocode(lat, lng)
            val name = simp(geoName).stripAdmin()
            name.ifBlank { settings.cityName }
        } catch (_: Exception) {
            settings.cityName
        }
    }

    // ---------- Open-Meteo ----------

    private suspend fun loadOpenMeteo(settings: AppSettings): WeatherData {
        val (lat, lng) = currentLatLng(settings)
        val w = OpenMeteoApi.weather(lat, lng)
        val air = OpenMeteoApi.airQuality(lat, lng)
        // 已持久化的城市名是权威值：手动选择或上一轮 GPS 解析过的名字都不应被本源
        // 的反查结果覆盖。否则启动瞬间 lastKnown 还是旧坐标（如昨天测试过的城市）
        // 时，标题会先闪现旧城市名，等新定位返回才自愈。
        // 反查只用于「还没有任何真实城市名」的兜底（首次安装/名字被清空）。
        val persistedName = settings.cityName.trim()
        val hasRealName = persistedName.isNotBlank() && persistedName != "北京"
        var cityName = if (hasRealName) persistedName else "未识别位置"
        if (!hasRealName) {
            try {
                val geoName = OpenMeteoApi.reverseGeocode(lat, lng)
                val name = simp(geoName).stripAdmin()
                if (name.isNotBlank()) cityName = name
            } catch (_: Exception) {
            }
        }
        return parseOpenMeteo(w, air, cityName)
    }

    private suspend fun currentLatLng(settings: AppSettings): Pair<Double, Double> {
        var lat = settings.lat
        var lng = settings.lng
        if (settings.useGps && lat == 39.9042 && lng == 116.4074) {
            val loc = locationHelper.getBestLocation()
            if (loc != null) {
                lat = loc.latitude
                lng = loc.longitude
            }
        }
        return lat to lng
    }

    // ---------- Name normalization ----------

    private fun simp(s: String): String = CityNameSimplify.simp(s)

    private fun String.stripAdmin(): String =
        trim().replace(Regex("(自治区|自治州|特别行政区|省|市|区|县|盟|州)$"), "")
}
