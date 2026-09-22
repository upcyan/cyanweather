package com.cyanweather.shared.data

import com.cyanweather.shared.model.NmcCityItem
import com.cyanweather.shared.model.NmcData
import com.cyanweather.shared.model.NmcProvinceItem
import com.cyanweather.shared.model.NmcResponse

object NmcApi {
    private const val BASE = "https://www.nmc.cn"

    /**
     * 错误语义分层：网络异常原样上抛（带 HTTP 状态），解析失败包装为可读错误，
     * 仅「接口正常但无数据」返回 null（调用方报「气象局暂无数据」）。
     * 之前三者都吞成 null，排障时无法区分「网络不通」和「接口改版」。
     */
    suspend fun weatherByStationId(stationId: String): NmcData? {
        val body = Net.get("$BASE/rest/weather?stationid=$stationId")
        return try {
            Net.json.decodeFromString<NmcResponse>(body).data
        } catch (e: kotlinx.serialization.SerializationException) {
            throw RuntimeException("气象局接口返回格式异常（可能已改版）", e)
        } catch (e: IllegalArgumentException) {
            throw RuntimeException("气象局接口返回格式异常（可能已改版）", e)
        }
    }

    suspend fun loadProvinces(): List<NmcProvinceItem> {
        val body = Net.get("$BASE/rest/province")
        return try {
            Net.json.decodeFromString<List<NmcProvinceItem>>(body)
        } catch (_: Exception) {
            emptyList()
        }
    }

    suspend fun loadCities(provinceCode: String): List<NmcCityItem> {
        val body = Net.get("$BASE/rest/province/$provinceCode")
        return try {
            Net.json.decodeFromString<List<NmcCityItem>>(body)
        } catch (_: Exception) {
            emptyList()
        }
    }

    suspend fun loadAllCities(): List<NmcCityItem> {
        val provinces = loadProvinces()
        return provinces.flatMap { p ->
            runCatching { loadCities(p.code) }.getOrDefault(emptyList())
        }
    }
}
