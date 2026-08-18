package com.cyanweather.app.data

import com.cyanweather.app.model.NmcCityItem
import com.cyanweather.app.model.NmcProvinceItem
import com.cyanweather.app.model.NmcResponse

object NmcApi {
    private const val BASE = "https://www.nmc.cn"

    suspend fun getProvinces(): List<NmcProvinceItem> {
        val body = Net.get("$BASE/rest/province")
        return Net.json.decodeFromString(body)
    }

    suspend fun getCities(provinceCode: String): List<NmcCityItem> {
        val body = Net.get("$BASE/rest/province/$provinceCode")
        return Net.json.decodeFromString(body)
    }

    suspend fun getWeather(stationId: String): NmcResponse {
        val body = Net.get("$BASE/rest/weather?stationid=$stationId")
        return Net.json.decodeFromString(body)
    }
}