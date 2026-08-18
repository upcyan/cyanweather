package com.cyanweather.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cyanweather.shared.data.AdminHierarchy
import com.cyanweather.shared.model.NmcCityItem
import com.cyanweather.shared.model.NmcProvinceItem

@Composable
fun CityPickerScreen(
    provinces: List<NmcProvinceItem>,
    cities: List<NmcCityItem>,
    allCities: List<NmcCityItem>,
    allCitiesLoading: Boolean,
    provinceLoading: Boolean,
    cityLoading: Boolean,
    selectedProvince: String?,
    onBack: () -> Unit,
    onProvinceClick: (String) -> Unit,
    onCityClick: (String, String) -> Unit,
    onBackToProvince: () -> Unit,
    onUseCurrentLocation: () -> Unit,
    onEnsureAllCities: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    val q = query.trim()
    LaunchedEffect(q) { if (q.isNotEmpty()) onEnsureAllCities() }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { if (selectedProvince != null) onBackToProvince() else onBack() }) {
                Icon(Icons.Default.ArrowBack, contentDescription = "返回", tint = Color(0xFF333333), modifier = Modifier.width(32.dp).height(32.dp))
            }
            Text(
                if (selectedProvince != null) "选择城市 / 区县" else "选择省份",
                style = fst(32),
                fontWeight = FontWeight.Bold
            )
        }
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("搜索城市 / 区县", style = fst(18)) },
            textStyle = fst(20),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))

        if (q.isNotEmpty()) {
            when {
                allCitiesLoading && allCities.isEmpty() -> LoadingBox()
                allCities.isEmpty() -> EmptyBox("城市数据加载失败，请检查网络")
                else -> {
                    val matched = allCities.filter { it.city.contains(q) || it.province.contains(q) }
                    if (matched.isEmpty()) {
                        EmptyBox("未找到「$q」，换个名字试试")
                    } else {
                        LazyColumn {
                            items(matched) { c ->
                                BigListItem(text = "${c.city}（${c.province}）") { onCityClick(c.city, c.code) }
                            }
                        }
                    }
                }
            }
            return
        }

        when {
            selectedProvince != null -> {
                if (cityLoading) {
                    LoadingBox()
                } else {
                    if (cities.isEmpty()) {
                        EmptyBox("未找到城市，换个名字试试")
                    } else {
                        val grouped = remember(selectedProvince, cities) { groupCities(selectedProvince, cities) }
                        LazyColumn {
                            items(grouped) { (parent, child) ->
                                if (parent == null) {
                                    BigListItem(text = child.city) { onCityClick(child.city, child.code) }
                                } else {
                                    BigChildItem(text = child.city) { onCityClick(child.city, child.code) }
                                }
                            }
                        }
                    }
                }
            }
            else -> {
                if (provinceLoading) {
                    LoadingBox()
                } else {
                    LazyColumn {
                        item {
                            BigListItem(text = "📍 使用当前位置") { onUseCurrentLocation() }
                        }
                        items(provinces) { p ->
                            BigListItem(text = p.name) { onProvinceClick(p.code) }
                        }
                    }
                }
            }
        }
    }
}

private fun groupCities(provinceCode: String?, cities: List<NmcCityItem>): List<Pair<NmcCityItem?, NmcCityItem>> {
    val top = mutableListOf<NmcCityItem>()
    val children = mutableMapOf<String, MutableList<NmcCityItem>>()
    for (c in cities) {
        val parent = provinceCode?.let { AdminHierarchy.countyToCity["$it|${c.city}"] }
        if (parent != null && parent != c.city) {
            children.getOrPut(parent) { mutableListOf() }.add(c)
        } else {
            top.add(c)
        }
    }
    val out = mutableListOf<Pair<NmcCityItem?, NmcCityItem>>()
    val used = mutableSetOf<NmcCityItem>()
    for (t in top) {
        out.add(null to t)
        children[t.city]?.forEach { out.add(t to it); used.add(it) }
    }
    for (list in children.values) {
        for (cc in list) {
            if (cc !in used) out.add(null to cc)
        }
    }
    return out
}

@Composable
private fun BigChildItem(text: String, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 28.dp, top = 4.dp, bottom = 4.dp)
    ) {
        Text(
            "　$text",
            style = fst(22),
            color = Color(0xFF333333),
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 20.dp, vertical = 14.dp)
        )
    }
}

@Composable
private fun BigListItem(text: String, onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp)
    ) {
        Text(
            text,
            style = fst(26),
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 20.dp, vertical = 18.dp)
        )
    }
}

@Composable
private fun LoadingBox() {
    Column(
        Modifier.fillMaxWidth().padding(top = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(16.dp))
        Text("加载中...", style = fst(22))
    }
}

@Composable
private fun EmptyBox(text: String) {
    Column(
        Modifier.fillMaxWidth().padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text, style = fst(22), color = Color(0xFF666666))
    }
}