package com.cyanweather.shared.data

import com.cyanweather.shared.model.NmcCityItem
import com.cyanweather.shared.model.NmcData
import com.cyanweather.shared.model.NmcProvinceItem
import com.cyanweather.shared.model.NmcResponse

object NmcApi {
    private const val BASE = "https://www.nmc.cn"

    suspend fun weatherByStationId(stationId: String): NmcData? {
        val body = Net.get("$BASE/rest/weather?stationid=$stationId")
        return try {
            Net.json.decodeFromString<NmcResponse>(body).data
        } catch (_: Exception) {
            null
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
