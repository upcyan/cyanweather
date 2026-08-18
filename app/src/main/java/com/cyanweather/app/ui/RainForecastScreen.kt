package com.cyanweather.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cyanweather.app.model.WeatherData

@Composable
fun RainForecastScreen(weather: WeatherData?, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.Default.ArrowBack, contentDescription = "返回", tint = Color(0xFF333333), modifier = Modifier.width(32.dp).height(32.dp))
            }
            Text("降雨趋势预报", style = fst(30), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(10.dp))
        Text(weather?.cityName ?: "", style = fst(20), color = Color(0xFF666666))
        Spacer(Modifier.height(8.dp))

        val w = weather ?: run {
            Text("暂无天气数据", style = fst(22))
            return
        }

        val hourlyRain = w.hourly.filter { it.isForecast && it.rainProb != null }.take(24)
        if (hourlyRain.isNotEmpty()) {
            Text("未来24小时降雨概率", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text("数值为降雨概率，雨天与雷雨时段以蓝色标出。", style = fst(16), color = Color(0xFF666666))
            Spacer(Modifier.height(6.dp))
            hourlyRain.forEach { item -> RainHourRow(item) }
        } else {
            Text("逐时降雨概率", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text("当前数据源暂不提供逐时降雨概率，以下为未来几日降雨趋势。", style = fst(16), color = Color(0xFF666666))
            Spacer(Modifier.height(6.dp))
            w.daily.take(7).forEach { d ->
                RainDayRow(d.dayText + d.nightText)
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun RainHourRow(item: com.cyanweather.app.model.HourlyItem) {
    val isRain = item.condition.contains("雨") || item.condition.contains("雷")
    val prob = (item.rainProb ?: 0.0).coerceIn(0.0, 100.0)
    val accent = if (isRain || prob >= 50) Color(0xFF0B6BCB) else Color(0xFF666666)
    Column(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(hourLabel(item.time), style = fst(20), color = Color(0xFF666666), modifier = Modifier.width(88.dp), maxLines = 1)
            Text(item.condition.ifEmpty { "-" }, style = fst(20), color = accent, modifier = Modifier.weight(1f))
            Text("${prob.toInt()}%", style = fst(20), color = accent, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(4.dp))
        Box(
            Modifier.fillMaxWidth().height(12.dp)
                .background(Color(0xFFE3EDF9), MaterialTheme.shapes.small)
        ) {
Box(
            Modifier
                .fillMaxWidth((prob / 100.0).toFloat())
                .height(12.dp)
                .background(if (prob >= 50) Color(0xFF0B6BCB) else Color(0xFF90CAF9), MaterialTheme.shapes.small)
        )
        }
    }
}

@Composable
private fun RainDayRow(text: String) {
    val isRain = text.contains("雨") || text.contains("雷")
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.width(12.dp).height(12.dp).background(if (isRain) Color(0xFF0B6BCB) else Color(0xFF90CAF9)),
        )
        Spacer(Modifier.width(10.dp))
        Text(text.ifEmpty { "-" }, style = fst(22), color = if (isRain) Color(0xFF0B6BCB) else Color(0xFF111111))
    }
}

private fun hourLabel(time: String): String {
    val t = time.trim()
    val raw = if (t.length >= 13) t.substring(11, 13) else ""
    val hour = raw.toIntOrNull()
    return if (hour != null) "${hour}时" else t
}