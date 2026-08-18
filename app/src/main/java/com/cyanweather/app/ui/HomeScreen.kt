package com.cyanweather.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cyanweather.app.data.SkyKind
import com.cyanweather.app.data.caiyunSkyconKind
import com.cyanweather.app.data.nmcSkyconKind
import com.cyanweather.app.model.DailyItem
import com.cyanweather.app.model.HourlyItem
import com.cyanweather.app.model.WeatherData
import com.cyanweather.app.model.YesterdayData
import com.cyanweather.app.update.UpdateResult
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    state: UiState,
    onSettings: () -> Unit,
    onRefresh: () -> Unit,
    onOpenCityPicker: () -> Unit,
    onOpenRainForecast: () -> Unit,
    onConfirmUpdate: () -> Unit,
    onDismissUpdate: () -> Unit
) {
    val weather = state.weather
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        TopBar(weather, state.refreshing, onSettings, onRefresh, onOpenCityPicker)
        Spacer(Modifier.height(8.dp))

        when {
            state.loading -> {
                Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(Modifier.size(64.dp))
                        Spacer(Modifier.height(20.dp))
                        Text("正在获取天气...", style = fst(24))
                    }
                }
            }
            weather == null && state.error != null -> {
                Column(
                    Modifier.fillMaxWidth().padding(top = 80.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(state.error ?: "", style = fst(22), color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center)
                    Spacer(Modifier.height(24.dp))
                    BigButton("重新获取", onRefresh)
                }
            }
            weather != null -> {
                WeatherBody(weather, state.error, onRefresh, onOpenRainForecast)
            }
        }
        Spacer(Modifier.height(24.dp))
    }

    val update = state.updateResult
    if (update is UpdateResult.UpdateAvailable) {
        UpdateDialog(result = update, onConfirm = onConfirmUpdate, onDismiss = onDismissUpdate)
    }
}

@Composable
private fun TopBar(
    weather: WeatherData?,
    refreshing: Boolean,
    onSettings: () -> Unit,
    onRefresh: () -> Unit,
    onOpenCityPicker: () -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onSettings, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Default.Settings, contentDescription = "设置", tint = Color(0xFF333333), modifier = Modifier.size(36.dp))
        }
        Column(
            Modifier.weight(1f).padding(horizontal = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                weather?.cityName ?: "选择城市",
                style = fst(30, FontWeight.Bold),
                color = MaterialTheme.colorScheme.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                if (refreshing) "更新中..." else weather?.updatedAt ?: "",
                style = fst(14),
                color = Color(0xFF666666),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        IconButton(onClick = onRefresh, modifier = Modifier.size(56.dp)) {
            Icon(Icons.Default.Refresh, contentDescription = "刷新", tint = Color(0xFF333333), modifier = Modifier.size(36.dp))
        }
    }
}

@Composable
private fun WeatherBody(weather: WeatherData, error: String?, onRefresh: () -> Unit, onOpenRainForecast: () -> Unit) {
    if (error != null) {
        Text(
            error,
            style = fst(18),
            color = MaterialTheme.colorScheme.error,
            modifier = Modifier.padding(bottom = 8.dp)
        )
    }

    // 预警横幅
    weather.warning?.let { warn ->
        Card(
            colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE)),
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        ) {
            Text(
                "⚠ $warn",
                style = fst(20),
                color = Color(0xFFB71C1C),
                modifier = Modifier.padding(16.dp),
                fontWeight = FontWeight.Medium
            )
        }
    }

    // 降雨提醒（可点击进入降雨趋势预报）
    val rainTip = remember(weather) { buildRainReminder(weather) }
    rainTip?.let {
        Card(
            onClick = onOpenRainForecast,
            colors = CardDefaults.cardColors(containerColor = Color(0xFFE3F2FD)),
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        ) {
            Column(Modifier.fillMaxWidth().padding(16.dp)) {
                Text("🌂 $it", style = fst(22))
                Spacer(Modifier.height(6.dp))
                Text("查看降雨趋势 ›", style = fst(18), color = Color(0xFF0B6BCB))
            }
        }
    }

    // 主天气：图标与温度同一行、缩小并下移，避免遮挡顶部时间文字
    Column(
        Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                WeatherGlyph(
                    kind = mainKind(weather),
                    modifier = Modifier.size(88.dp)
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    weather.condition,
                    style = fst(28, FontWeight.Medium),
                    textAlign = TextAlign.Center
                )
            }
            Spacer(Modifier.width(20.dp))
            Text(
                "${temp(weather.temperature)}°",
                style = fst(64, FontWeight.Bold),
                color = Color(0xFF111111)
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth()) {
            StatCol("最高", "${temp(weather.todayHigh)}°", Color(0xFFC62828), Modifier.weight(1f))
            StatCol("最低", "${temp(weather.todayLow)}°", Color(0xFF1565C0), Modifier.weight(1f))
        }
        weather.feelsLike?.let {
            Spacer(Modifier.height(8.dp))
            Text("体感温度 ${temp(it)}°", style = fst(20), color = Color(0xFF666666))
        }
    }

    // 日出日落（移到体感温度下方）
    if (weather.sunrise != null || weather.sunset != null) {
        Row(Modifier.fillMaxWidth().padding(vertical = 10.dp)) {
            SunCol("日出", weather.sunrise, Modifier.weight(1f))
            SunCol("日落", weather.sunset, Modifier.weight(1f))
        }
    }

    // 湿度 / 风力 / 空气质量 / 紫外线强度（整行卡片，标题与数值分行，避免换行重叠）
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        InfoCard("湿度", "${weather.humidity ?: "-"}%")
        InfoCard("风力", "${weather.windDirect} ${weather.windPower}".trim())
        InfoCard("空气质量", if (weather.aqi != null) "${weather.aqiText} ${weather.aqi}" else "-")
        if (weather.uvIndex.isNotBlank()) {
            InfoCard("紫外线强度", weather.uvIndex)
        }
    }

    // 彩云分钟级降水
    weather.minutelyText?.let {
        Card(
            colors = CardDefaults.cardColors(containerColor = Color(0xFFE3F2FD)),
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
        ) {
            Text(it, style = fst(22), modifier = Modifier.padding(16.dp))
        }
    }

    // 逐小时预报（Open-Meteo / 彩云；气象局的过去24小时实况并入昨日卡片）
    if (weather.hourly.isNotEmpty() && weather.hourlyLabel.contains("预报")) {
        SectionTitle(weather.hourlyLabel)
        HourlyRow(weather.hourly)
    }

    // 多日预报
    if (weather.daily.isNotEmpty()) {
        SectionTitle("未来多日预报（${weather.daily.size}天）")
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(Modifier.padding(vertical = 8.dp)) {
                weather.daily.forEach { d -> DailyRow(d) }
            }
        }
    }

    // 昨日天气（移到最下面）
    if (weather.yesterday != null) {
        SectionTitle("昨日天气")
        YesterdayCard(weather.yesterday)
    } else if (weather.sourceTag.contains("彩云")) {
        SectionTitle("昨日天气")
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                "彩云天气暂不提供昨日天气数据",
                style = fst(20),
                color = Color(0xFF666666),
                modifier = Modifier.padding(16.dp)
            )
        }
    }

    Spacer(Modifier.height(20.dp))
    Text(
        weather.sourceTag,
        style = fst(16),
        color = Color(0xFF888888),
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        textAlign = TextAlign.Center
    )
}

private fun mainKind(w: WeatherData): SkyKind {
    if (w.sourceTag.contains("彩云")) {
        return caiyunSkyconKind(w.condition.toSkycon())
    }
    return nmcSkyconKind(w.condition)
}

private fun String.toSkycon(): String = when (this) {
    "晴" -> "CLEAR_DAY"
    "多云" -> "PARTLY_CLOUDY_DAY"
    "阴" -> "CLOUDY"
    "小雨" -> "LIGHT_RAIN"
    "中雨" -> "MODERATE_RAIN"
    "大雨" -> "HEAVY_RAIN"
    "暴雨" -> "STORM_RAIN"
    "小雪" -> "LIGHT_SNOW"
    "中雪" -> "MODERATE_SNOW"
    "大雪" -> "HEAVY_SNOW"
    "雷阵雨" -> "THUNDER_SHOWER"
    "雨夹雪" -> "SLEET"
    "雾" -> "FOG"
    else -> ""
}

private fun buildRainReminder(w: WeatherData): String? {
    val upcoming = w.hourly.filter { it.isForecast }.take(12)
    if (upcoming.isNotEmpty()) {
        val idx = upcoming.indexOfFirst { it.condition.contains("雨") || it.condition.contains("雷") }
        if (idx >= 0) {
            return if (idx <= 1) "现在或很快有降雨，出门请带伞"
            else "预计约 ${idx} 小时后可能有降雨，出门请带伞"
        }
    }
    val soon = w.daily.take(3).any { (it.dayText + it.nightText).contains("雨") || (it.dayText + it.nightText).contains("雷") }
    return if (soon) "近期可能有雨，请留意天气变化" else null
}

private fun temp(v: Double?): String = v?.let { it.round() } ?: "-"

private fun Double.round(): String = if (this % 1.0 == 0.0) this.toInt().toString() else String.format(Locale.US, "%.0f", this)

@Composable
private fun StatCol(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = fst(22), color = Color(0xFF666666))
        Text(value, style = fst(30, FontWeight.Bold), color = color)
    }
}

@Composable
private fun SunCol(label: String, time: String?, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = fst(22), color = Color(0xFF666666))
        Text(time ?: "-", style = fst(22, FontWeight.Medium))
    }
}

@Composable
private fun InfoCard(title: String, value: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
            Text(title, style = fst(20), color = Color(0xFF666666))
            Spacer(Modifier.height(4.dp))
            Text(value, style = fst(28, FontWeight.Medium), maxLines = 2)
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text,
        style = fst(24, FontWeight.Bold),
        modifier = Modifier.padding(top = 20.dp, bottom = 10.dp)
    )
}

@Composable
private fun HourlyRow(items: List<HourlyItem>) {
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val canPrev by remember {
        derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 0 }
    }
    val canNext by remember {
        derivedStateOf {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull()
            last != null && last.index < info.totalItemsCount - 1
        }
    }
    Box(Modifier.fillMaxWidth()) {
        LazyRow(
            state = listState,
            contentPadding = PaddingValues(horizontal = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            items(items) { item -> HourCard(item) }
        }
        if (canPrev) {
            HourArrowOverlay("‹", Modifier.align(Alignment.CenterStart)) {
                scope.launch { listState.scrollToItem(maxOf(0, listState.firstVisibleItemIndex - 3)) }
            }
        }
        if (canNext) {
            HourArrowOverlay("›", Modifier.align(Alignment.CenterEnd)) {
                scope.launch { listState.scrollToItem(listState.firstVisibleItemIndex + 3) }
            }
        }
    }
}

@Composable
private fun HourArrowOverlay(symbol: String, modifier: Modifier, onClick: () -> Unit) {
    val scale = LocalFontScale.current
    Box(
        modifier = modifier
            .padding(horizontal = 2.dp)
            .size(34.dp * scale)
            .clip(RoundedCornerShape(50))
            .background(Color(0xB3FFFFFF))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(
            symbol,
            style = fst(18),
            color = Color(0xFF0B6BCB),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun HourCard(item: HourlyItem) {
    val kind = when {
        item.isForecast && item.condition.isNotEmpty() -> caiyunSkyconKind(item.condition.toSkycon())
        item.isForecast -> SkyKind.UNKNOWN
        else -> nmcSkyconKind(item.condition)
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.width(100.dp)
    ) {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(hourLabel(item.time), style = fst(18), color = Color(0xFF666666))
            Spacer(Modifier.height(6.dp))
            WeatherGlyph(kind, Modifier.size(36.dp))
            if (item.condition.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text(item.condition, style = fst(18), textAlign = TextAlign.Center, maxLines = 2)
            }
            Spacer(Modifier.height(4.dp))
            Text("${temp(item.temperature)}°", style = fst(22, FontWeight.Bold))
        }
    }
}

private fun hourLabel(time: String): String {
    return when {
        time.contains("T") && time.length >= 13 -> "${time.substring(11, 13).toIntOrNull() ?: "?"}时"
        time.contains(" ") && time.length >= 16 -> "${time.substring(11, 13).toIntOrNull() ?: "?"}时"
        else -> time
    }
}

@Composable
private fun DailyRow(d: DailyItem) {
    val kind = when {
        d.dayText.isNotEmpty() -> nmcSkyconKind(d.dayText)
        else -> SkyKind.UNKNOWN
    }
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Text(dayLabel(d.date), style = fst(22, FontWeight.Medium), maxLines = 2)
        Spacer(Modifier.height(4.dp))
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            WeatherGlyph(kind, Modifier.size(40.dp))
            Spacer(Modifier.width(10.dp))
            Text(
                combineDayNight(d.dayText, d.nightText),
                style = fst(22),
                modifier = Modifier.weight(1f),
                maxLines = 2
            )
            Spacer(Modifier.width(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${temp(d.high)}°", style = fst(24, FontWeight.Bold), color = Color(0xFFC62828))
                Text("/", style = fst(24, FontWeight.Bold), color = Color(0xFF666666))
                Text("${temp(d.low)}°", style = fst(24, FontWeight.Bold), color = Color(0xFF1565C0))
            }
        }
    }
}

private fun combineDayNight(day: String, night: String): String = when {
    day.isNotEmpty() && night.isNotEmpty() && day != night -> "${day}转${night}"
    day.isNotEmpty() -> day
    night.isNotEmpty() -> night
    else -> "-"
}

private fun dayLabel(date: String): String {
    return try {
        val clean = if (date.contains("T")) date.substring(0, 10) else date
        val d = LocalDate.parse(clean.replace("/", "-"))
        val today = LocalDate.now()
        val weekday = d.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.CHINA)
        when (d) {
            today -> "今天 ${d.monthValue}月${d.dayOfMonth}日 $weekday"
            today.plusDays(1) -> "明天 ${d.monthValue}月${d.dayOfMonth}日 $weekday"
            today.plusDays(2) -> "后天 ${d.monthValue}月${d.dayOfMonth}日 $weekday"
            else -> "${d.monthValue}月${d.dayOfMonth}日 $weekday"
        }
    } catch (e: Exception) {
        date
    }
}

@Composable
private fun YesterdayCard(y: YesterdayData) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(
                Modifier.fillMaxWidth().padding(bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("昨日最高 ", style = fst(24), modifier = Modifier.weight(1f))
                Text("${temp(y.high)}°", style = fst(28, FontWeight.Bold), color = Color(0xFFC62828))
            }
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("昨日最低 ", style = fst(24), modifier = Modifier.weight(1f))
                Text("${temp(y.low)}°", style = fst(28, FontWeight.Bold), color = Color(0xFF1565C0))
            }
            if (y.hourly.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                HourlyRow(y.hourly)
            }
        }
    }
}

@Composable
fun BigButton(text: String, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = Color(0xFF0B6BCB)),
        shape = RoundedCornerShape(16.dp)
    ) {
        Text(
            text,
            color = Color.White,
            style = fst(28, FontWeight.Bold),
            modifier = Modifier.padding(horizontal = 40.dp, vertical = 16.dp)
        )
    }
}