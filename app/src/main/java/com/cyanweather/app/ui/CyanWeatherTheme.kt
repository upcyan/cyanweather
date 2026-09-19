package com.cyanweather.app.ui

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * 三端共享设计令牌（对齐 webf/assets/web/styles.css :root 与 flutter Theme）。
 * 修改任一色值时三端同步：CyanWeatherTheme.kt / styles.css :root / flutter ThemeData。
 */
object CyanTokens {
    val Primary = Color(0xFF0B6BCB)      // --accent
    val Background = Color(0xFFF5F9FF)   // --bg
    val Surface = Color.White            // --card
    val SurfaceVariant = Color(0xFFE3EDF9) // --accent-soft
    val OnBackground = Color(0xFF111111) // --text
    val OnSurfaceVariant = Color(0xFF333333) // --muted
    val Muted2 = Color(0xFF666666)       // --soft
    val HighRed = Color(0xFFC62828)      // --high-red
    val LowBlue = Color(0xFF1565C0)      // --low-blue
    val FeelTeal = Color(0xFF00897B)     // --feel-teal
    val RainTip = Color(0xFFE3F2FD)      // 降雨提醒卡底
    val WarnBg = Color(0xFFFFEBEE)       // 预警横幅底
    val WarnText = Color(0xFFB71C1C)
    const val RadiusCard = 16            // dp，卡片圆角
}

private val LightColors = lightColorScheme(
    primary = CyanTokens.Primary,
    onPrimary = Color.White,
    secondary = CyanTokens.Primary,
    background = CyanTokens.Background,
    onBackground = CyanTokens.OnBackground,
    surface = CyanTokens.Surface,
    onSurface = CyanTokens.OnBackground,
    surfaceVariant = CyanTokens.SurfaceVariant,
    onSurfaceVariant = CyanTokens.OnSurfaceVariant,
    error = Color(0xFFC62828),
    onError = Color.White
)

// 圆角层级：小=瓷砖/小时卡 12，中=卡片 16，大=对话框/按钮 20
private val CyanShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(20.dp),
    extraLarge = RoundedCornerShape(28.dp)
)

@Composable
fun CyanWeatherTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        shapes = CyanShapes,
        content = content
    )
}
