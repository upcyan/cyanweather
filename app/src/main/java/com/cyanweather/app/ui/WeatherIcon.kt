package com.cyanweather.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import com.cyanweather.app.data.SkyKind
import kotlin.math.cos
import kotlin.math.sin

private val SunColor = Color(0xFFF6A821)
private val CloudColor = Color(0xFF7C97AB)
private val RainColor = Color(0xFF3FA3F0)
private val BoltColor = Color(0xFFF2A93B)
private val SnowColor = Color(0xFF90CAF9)
private val FogColor = Color(0xFFB0BEC5)

@Composable
fun WeatherGlyph(kind: SkyKind, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val norm = when (kind) {
            SkyKind.SUN -> 0.80f
            SkyKind.PARTLY -> 0.68f
            SkyKind.MOON -> 1.08f
            SkyKind.CLOUD -> 0.98f
            SkyKind.RAIN -> 1.06f
            SkyKind.SNOW -> 1.06f
            SkyKind.THUNDER -> 0.94f
            SkyKind.SLEET -> 1.06f
            SkyKind.FOG, SkyKind.HAZE -> 1.22f
            SkyKind.WIND -> 0.98f
            SkyKind.UNKNOWN -> 1.10f
        }
        val s = minOf(w, h) * norm
        val cx = w / 2f
        val cy = h / 2f

        fun drawCloudBody(cx: Float, cy: Float, s: Float) {
            drawCircle(CloudColor, s * 0.27f, Offset(cx - s * 0.30f, cy - s * 0.15f))
            drawCircle(CloudColor, s * 0.34f, Offset(cx, cy - s * 0.30f))
            drawCircle(CloudColor, s * 0.27f, Offset(cx + s * 0.32f, cy - s * 0.13f))
            drawRoundRect(
                color = CloudColor,
                topLeft = Offset(cx - s * 0.50f, cy - s * 0.08f),
                size = Size(s * 1.0f, s * 0.40f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(s * 0.20f, s * 0.20f)
            )
        }

        when (kind) {
            SkyKind.SUN -> {
                drawCircle(SunColor, s * 0.30f, Offset(cx, cy))
                val r1 = s * 0.42f
                val r2 = s * 0.60f
                for (i in 0 until 8) {
                    val ang = (i * 45.0) * Math.PI / 180.0
                    val dx = cos(ang).toFloat()
                    val dy = sin(ang).toFloat()
                    drawLine(
                        SunColor,
                        Offset(cx + dx * r1, cy + dy * r1),
                        Offset(cx + dx * r2, cy + dy * r2),
                        strokeWidth = s * 0.09f, cap = StrokeCap.Round
                    )
                }
            }
            SkyKind.MOON -> {
                drawCircle(SunColor, s * 0.36f, Offset(cx - s * 0.08f, cy))
                drawCircle(SunColor, s * 0.30f, Offset(cx + s * 0.12f, cy - s * 0.12f), blendMode = BlendMode.Clear)
            }
            SkyKind.CLOUD -> drawCloudBody(cx, cy + s * 0.08f, s * 0.72f)
            SkyKind.PARTLY -> {
                drawCircle(SunColor, s * 0.20f, Offset(cx - s * 0.30f, cy - s * 0.30f))
                val r1 = s * 0.27f
                val r2 = s * 0.40f
                for (i in 0 until 8) {
                    val ang = (i * 45.0) * Math.PI / 180.0
                    val dx = cos(ang).toFloat()
                    val dy = sin(ang).toFloat()
                    drawLine(
                        SunColor,
                        Offset(cx - s * 0.30f + dx * r1, cy - s * 0.30f + dy * r1),
                        Offset(cx - s * 0.30f + dx * r2, cy - s * 0.30f + dy * r2),
                        strokeWidth = s * 0.07f, cap = StrokeCap.Round
                    )
                }
                drawCloudBody(cx + s * 0.16f, cy + s * 0.22f, s * 0.58f)
            }
            SkyKind.RAIN -> {
                drawCloudBody(cx, cy - s * 0.16f, s * 0.66f)
                val xs = floatArrayOf(-s * 0.22f, 0f, s * 0.22f)
                for (x in xs) {
                    drawLine(
                        RainColor,
                        Offset(cx + x - s * 0.03f, cy + s * 0.18f),
                        Offset(cx + x + s * 0.03f, cy + s * 0.40f),
                        strokeWidth = s * 0.10f, cap = StrokeCap.Round
                    )
                }
            }
            SkyKind.SNOW -> {
                drawCloudBody(cx, cy - s * 0.16f, s * 0.66f)
                val xs = floatArrayOf(-s * 0.24f, 0f, s * 0.24f)
                for (x in xs) {
                    drawSnowflake(Offset(cx + x, cy + s * 0.28f), s * 0.10f, s * 0.03f)
                }
            }
            SkyKind.THUNDER -> {
                drawCloudBody(cx, cy - s * 0.22f, s * 0.64f)
                val bolt = Path().apply {
                    moveTo(cx - s * 0.06f, cy + s * 0.08f)
                    lineTo(cx + s * 0.12f, cy + s * 0.08f)
                    lineTo(cx - s * 0.02f, cy + s * 0.28f)
                    lineTo(cx + s * 0.12f, cy + s * 0.28f)
                    lineTo(cx - s * 0.14f, cy + s * 0.50f)
                    lineTo(cx - s * 0.04f, cy + s * 0.30f)
                    lineTo(cx - s * 0.12f, cy + s * 0.30f)
                    close()
                }
                drawPath(bolt, BoltColor)
            }
            SkyKind.FOG -> {
                drawCloudBody(cx, cy - s * 0.20f, s * 0.52f)
                for (i in 0 until 3) {
                    val y = cy + s * (0.05f + i * 0.16f)
                    val half = s * (0.34f - i * 0.05f)
                    drawLine(
                        FogColor,
                        Offset(cx - half, y), Offset(cx + half, y),
                        strokeWidth = s * 0.10f, cap = StrokeCap.Round
                    )
                }
            }
            SkyKind.HAZE -> {
                drawCloudBody(cx, cy - s * 0.20f, s * 0.52f)
                for (i in 0 until 3) {
                    val y = cy + s * (0.05f + i * 0.16f)
                    val half = s * (0.34f - i * 0.05f)
                    drawLine(
                        FogColor,
                        Offset(cx - half, y), Offset(cx + half, y),
                        strokeWidth = s * 0.10f, cap = StrokeCap.Round
                    )
                }
            }
            SkyKind.WIND -> {
                drawLine(
                    CloudColor, Offset(cx - s * 0.38f, cy - s * 0.18f), Offset(cx + s * 0.38f, cy - s * 0.18f),
                    strokeWidth = s * 0.10f, cap = StrokeCap.Round
                )
                drawArc(
                    CloudColor, 180f, 90f, false,
                    Offset(cx - s * 0.38f, cy - s * 0.02f),
                    Size(s * 0.30f, s * 0.30f),
                    style = Stroke(width = s * 0.10f, cap = StrokeCap.Round)
                )
                drawArc(
                    CloudColor, 40f, 100f, false,
                    Offset(cx - s * 0.02f, cy + s * 0.14f),
                    Size(s * 0.30f, s * 0.34f),
                    style = Stroke(width = s * 0.10f, cap = StrokeCap.Round)
                )
            }
            SkyKind.SLEET -> {
                drawCloudBody(cx, cy - s * 0.16f, s * 0.66f)
                drawLine(
                    RainColor, Offset(cx - s * 0.18f, cy + s * 0.18f), Offset(cx - s * 0.12f, cy + s * 0.36f),
                    strokeWidth = s * 0.09f, cap = StrokeCap.Round
                )
                drawLine(
                    RainColor, Offset(cx + s * 0.18f, cy + s * 0.18f), Offset(cx + s * 0.24f, cy + s * 0.36f),
                    strokeWidth = s * 0.09f, cap = StrokeCap.Round
                )
                drawSnowflake(Offset(cx, cy + s * 0.34f), s * 0.09f, s * 0.025f)
            }
            SkyKind.UNKNOWN -> drawCloudBody(cx, cy + s * 0.06f, s * 0.60f)
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawSnowflake(
    center: Offset,
    r: Float,
    strokeW: Float
) {
    for (i in 0 until 3) {
        val ang = i * Math.PI / 3.0
        val dx = cos(ang).toFloat()
        val dy = sin(ang).toFloat()
        drawLine(
            SnowColor,
            Offset(center.x + dx * r, center.y + dy * r),
            Offset(center.x - dx * r, center.y - dy * r),
            strokeWidth = strokeW, cap = StrokeCap.Round
        )
    }
    drawCircle(SnowColor, r * 0.22f, center)
}
