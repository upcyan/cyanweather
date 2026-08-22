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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cyanweather.app.data.AppSettings

@Composable
fun SettingsScreen(
    settings: AppSettings,
    onBack: () -> Unit,
    onSource: (String) -> Unit,
    onCaiyunMode: (String) -> Unit,
    onToken: (String) -> Unit,
    onCaiyunV3Key: (String) -> Unit,
    onCaiyunV3Secret: (String) -> Unit,
    onFont: (String) -> Unit,
    onRefreshInterval: (String) -> Unit,
    onExtendedForecast: (Boolean) -> Unit,
    onExtendedDays: (Int) -> Unit,
    onGetYesterday: (Boolean) -> Unit,
    onAutoCheckUpdate: (Boolean) -> Unit,
    onUseGps: (Boolean) -> Unit,
    onOpenCityPicker: () -> Unit,
    onManualCheckUpdate: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack, modifier = Modifier.width(56.dp).height(56.dp)) {
                Icon(Icons.Default.ArrowBack, contentDescription = "返回", tint = Color(0xFF333333), modifier = Modifier.width(32.dp).height(32.dp))
            }
            Text("设置", style = fst(32), fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))

        // 数据源
        SettingCard {
            Text("天气数据源", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            RadioRow("中国气象局", "中央气象台，免费无需密钥，支持县区级，含昨日天气", settings.source == "nmc", onSource, "nmc")
            RadioRow("Open-Meteo", "免费开放源，最长15天预报+紫外线+降水概率，按定位获取", settings.source == "openmeteo", onSource, "openmeteo")
            RadioRow("彩云天气", "实时精准，分钟级预报，按定位获取，需凭证", settings.source == "caiyun", onSource, "caiyun")
            if (settings.source == "caiyun") {
                Spacer(Modifier.height(8.dp))
                Text("接入方式", style = fst(18), fontWeight = FontWeight.Bold, color = Color(0xFF666666))
                RadioRow("V1：Token 接入", "免费版，3天预报，Token 在 URL 中", settings.caiyunMode == "v1", onCaiyunMode, "v1")
                RadioRow("V3：AppKey + AppSecret 接入", "开放平台凭证，签名鉴权", settings.caiyunMode == "v3", onCaiyunMode, "v3")
                if (settings.caiyunMode == "v1") {
                    Spacer(Modifier.height(6.dp))
                    var token by remember { mutableStateOf(settings.caiyunToken) }
                    OutlinedTextField(
                        value = token,
                        onValueChange = { token = it.replace(Regex("\\s"), ""); onToken(token) },
                        placeholder = { Text("填写 V1 Token", style = fst(18)) },
                        textStyle = MaterialTheme.typography.bodyLarge,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    Text("在 dashboard.caiyunapp.com 注册获取；免费版仅 3 天预报与 48 小时逐时。", style = fst(16), color = Color(0xFF666666))
                }
                if (settings.caiyunMode == "v3") {
                    Spacer(Modifier.height(6.dp))
                    var key by remember { mutableStateOf(settings.caiyunV3Key) }
                    var secret by remember { mutableStateOf(settings.caiyunV3Secret) }
                    OutlinedTextField(
                        value = key,
                        onValueChange = { key = it.replace(Regex("\\s"), ""); onCaiyunV3Key(key) },
                        placeholder = { Text("填写 AppKey", style = fst(18)) },
                        textStyle = MaterialTheme.typography.bodyLarge,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = secret,
                        onValueChange = { secret = it.replace(Regex("\\s"), ""); onCaiyunV3Secret(secret) },
                        placeholder = { Text("填写 AppSecret", style = fst(18)) },
                        textStyle = MaterialTheme.typography.bodyLarge,
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    Text("在彩云开放平台获取；使用 AppKey 与 AppSecret 生成签名访问接口。", style = fst(16), color = Color(0xFF666666))
                }
                Text("凭证未填写完整时，自动使用中国气象局数据。", style = fst(16), color = Color(0xFF666666))
            }
        }

        // 扩展多日预报（仅彩云天气凭证已填写时）
        if (settings.source == "caiyun" && settings.caiyunMode == "v1" && settings.caiyunToken.isNotBlank() ||
            settings.source == "caiyun" && settings.caiyunMode == "v3" && settings.caiyunV3Key.isNotBlank()) {
            SettingCard {
                SwitchRow(
                    "扩展多日预报",
                    "彩云天气免费版单次最多请求3天数据，多次请求叠加更多日期",
                    settings.extendedForecast,
                    onExtendedForecast
                )
                if (settings.extendedForecast) {
                    Spacer(Modifier.height(6.dp))
                    SwitchRow("获取昨日天气", "开启后从昨天开始获取，昨日计入总天数", settings.getYesterday, onGetYesterday)
                    Spacer(Modifier.height(6.dp))
                    val days = settings.extendedDays
                    val totalDays = days + if (settings.getYesterday) 1 else 0
                    val requests = (days + 2) / 3 + if (settings.getYesterday) 1 else 0
                    Text("总获取天数：${totalDays}天，共需 ${requests} 次请求", style = fst(18), color = Color(0xFF666666))
                    Spacer(Modifier.height(6.dp))
                    RadioRow("3天", "", days == 3, { it.toIntOrNull()?.let(onExtendedDays) }, "3")
                    RadioRow("5天", "", days == 5, { it.toIntOrNull()?.let(onExtendedDays) }, "5")
                    RadioRow("7天", "", days == 7, { it.toIntOrNull()?.let(onExtendedDays) }, "7")
                    RadioRow("10天", "", days == 10, { it.toIntOrNull()?.let(onExtendedDays) }, "10")
                    RadioRow("15天", "", days == 15, { it.toIntOrNull()?.let(onExtendedDays) }, "15")
                }
            }
        }

        // 城市
        SettingCard {
            Text("城市", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Card(
                onClick = onOpenCityPicker,
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(settings.cityName, style = fst(24), modifier = Modifier.weight(1f))
                    Text("更改 >", style = fst(24), color = Color(0xFF0B6BCB))
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(
                if (settings.source == "openmeteo" || settings.source == "caiyun") "该数据源使用定位获取，无需选择城市。"
                else "支持省份 → 城市 / 区县 两级选择。",
                style = fst(16),
                color = Color(0xFF666666)
            )
        }

        // 字号
        SettingCard {
            Text("字体大小", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            RadioRow("标准", "", settings.fontSize == "standard", onFont, "standard")
            RadioRow("大", "", settings.fontSize == "large", onFont, "large", badge = "推荐")
            RadioRow("特大", "", settings.fontSize == "xlarge", onFont, "xlarge")
        }

        // 自动定位
        SettingCard {
            SwitchRow("使用自动定位", "彩云与 Open-Meteo 按定位获取；需要定位权限", settings.useGps, onUseGps)
        }

        // 自动刷新
        SettingCard {
            Text("自动刷新", style = fst(24), fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(6.dp))
            RadioRow("关闭", "", settings.refreshInterval == "off", onRefreshInterval, "off")
            RadioRow("每次进入App", "", settings.refreshInterval == "on_resume", onRefreshInterval, "on_resume")
            RadioRow("每 10 分钟", "", settings.refreshInterval == "10", onRefreshInterval, "10")
            RadioRow("每 30 分钟", "", settings.refreshInterval == "30", onRefreshInterval, "30", badge = "推荐")
            RadioRow("每 60 分钟", "", settings.refreshInterval == "60", onRefreshInterval, "60")
            RadioRow("每 6 小时", "", settings.refreshInterval == "360", onRefreshInterval, "360")
            RadioRow("每 12 小时", "", settings.refreshInterval == "720", onRefreshInterval, "720")
            RadioRow("每 24 小时", "", settings.refreshInterval == "1440", onRefreshInterval, "1440")
        }

        // 检查更新
        SettingCard {
            SwitchRow("自动检查更新", "进入App时检查GitHub是否有新版本", settings.autoCheckUpdate, onAutoCheckUpdate)
            Spacer(Modifier.height(8.dp))
            Card(
                onClick = onManualCheckUpdate,
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("手动检查更新", style = fst(24), modifier = Modifier.weight(1f))
                    Text("检查 >", style = fst(24), color = Color(0xFF0B6BCB))
                }
            }
        }

        // 关于
        SettingCard {
            val context = LocalContext.current
            val versionName = remember {
                runCatching {
                    context.packageManager.getPackageInfo(context.packageName, 0).versionName
                }.getOrNull() ?: ""
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("关于", style = fst(24), fontWeight = FontWeight.Bold)
                if (versionName.isNotEmpty()) {
                    Spacer(Modifier.width(8.dp))
                    Text("v$versionName", style = fst(16), color = Color(0xFF888888))
                }
            }
            Spacer(Modifier.height(8.dp))
            Text("晴暖天气：为长辈设计的简洁大字天气应用。", style = fst(18), color = Color(0xFF666666))
            Text("数据来源：中央气象台 / 彩云天气 / Open-Meteo", style = fst(18), color = Color(0xFF666666))
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun SettingCard(content: @Composable () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp)
    ) {
        Column(Modifier.padding(16.dp)) { content() }
    }
}

@Composable
private fun RadioRow(
    label: String,
    hint: String,
    selected: Boolean,
    onSelect: (String) -> Unit,
    value: String,
    badge: String? = null
) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RadioButton(
            selected = selected,
            onClick = { onSelect(value) },
            colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF0B6BCB))
        )
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(label, style = fst(22))
                if (badge != null) {
                    Spacer(Modifier.width(8.dp))
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color(0xFF0B6BCB))
                            .padding(horizontal = 10.dp, vertical = 2.dp)
                    ) {
                        Text(badge, style = fst(14), color = Color.White)
                    }
                }
            }
            if (hint.isNotEmpty()) {
                Text(hint, style = fst(16), color = Color(0xFF666666))
            }
        }
    }
}

@Composable
private fun SwitchRow(
    label: String,
    hint: String,
    checked: Boolean,
    onChecked: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(label, style = fst(22))
            if (hint.isNotEmpty()) {
                Text(hint, style = fst(16), color = Color(0xFF666666))
            }
        }
        Switch(checked = checked, onCheckedChange = onChecked)
    }
}
