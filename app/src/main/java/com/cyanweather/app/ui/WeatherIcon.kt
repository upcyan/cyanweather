package com.cyanweather.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.foundation.Image
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.cyanweather.app.R
import com.cyanweather.shared.data.SkyKind

/** Meteocons Fill（MIT）统一天气图标。SVG 位于 assets/meteocons。 */
@Composable
fun WeatherGlyph(kind: SkyKind, modifier: Modifier = Modifier) {
    val resource = when (kind) {
        SkyKind.SUN, SkyKind.MOON -> R.drawable.weather_clear_day
        SkyKind.PARTLY -> R.drawable.weather_partly_cloudy_day
        SkyKind.CLOUD, SkyKind.WIND, SkyKind.UNKNOWN -> R.drawable.weather_overcast
        SkyKind.RAIN -> R.drawable.weather_rain
        SkyKind.SNOW -> R.drawable.weather_snow
        SkyKind.THUNDER -> R.drawable.weather_thunderstorms
        SkyKind.SLEET -> R.drawable.weather_sleet
        SkyKind.FOG, SkyKind.HAZE -> R.drawable.weather_fog
    }
    Image(
        painter = painterResource(resource),
        contentDescription = null,
        modifier = modifier,
        contentScale = ContentScale.Fit,
    )
}
