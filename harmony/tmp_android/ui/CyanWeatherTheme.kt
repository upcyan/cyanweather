package com.cyanweather.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF0B6BCB),
    onPrimary = Color.White,
    secondary = Color(0xFF0B6BCB),
    background = Color(0xFFF5F9FF),
    onBackground = Color(0xFF111111),
    surface = Color.White,
    onSurface = Color(0xFF111111),
    surfaceVariant = Color(0xFFE3EDF9),
    onSurfaceVariant = Color(0xFF333333),
    error = Color(0xFFC62828),
    onError = Color.White
)

@Composable
fun CyanWeatherTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        content = content
    )
}