package com.cyanweather.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import com.cyanweather.shared.data.SkyKind

/** Meteocons Fill（MIT）统一天气图标。SVG 位于 assets/meteocons。 */
@Composable
fun WeatherGlyph(kind: SkyKind, modifier: Modifier = Modifier) {
    val slug = when (kind) {
        SkyKind.SUN, SkyKind.MOON -> "clear-day"
        SkyKind.PARTLY -> "partly-cloudy-day"
        SkyKind.CLOUD, SkyKind.WIND, SkyKind.UNKNOWN -> "overcast"
        SkyKind.RAIN -> "rain"
        SkyKind.SNOW -> "snow"
        SkyKind.THUNDER -> "thunderstorms"
        SkyKind.SLEET -> "sleet"
        SkyKind.FOG, SkyKind.HAZE -> "fog"
    }
    AsyncImage(
        model = "file:///android_asset/meteocons/$slug.svg",
        contentDescription = null,
        modifier = modifier,
        contentScale = ContentScale.Fit,
    )
}
