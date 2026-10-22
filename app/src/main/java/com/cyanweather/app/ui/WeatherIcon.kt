package com.cyanweather.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.foundation.Image
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.cyanweather.app.R
import com.cyanweather.shared.data.SkyKind

/** QWeather Icons（MIT）统一天气图标（线条版），VectorDrawable 位于 res/drawable。 */
@Composable
fun WeatherGlyph(kind: SkyKind, modifier: Modifier = Modifier, condition: String = "", night: Boolean = false) {
    val resource = when (kind) {
        // MOON 由数据源（彩云 CLEAR_NIGHT）直接给出，与本地时钟无关，恒用夜图标
        SkyKind.MOON -> R.drawable.weather_clear_night
        SkyKind.SUN -> if (night) R.drawable.weather_clear_night else R.drawable.weather_clear_day
        SkyKind.PARTLY -> if (night) R.drawable.weather_partly_cloudy_night else R.drawable.weather_partly_cloudy_day
        SkyKind.CLOUD, SkyKind.WIND, SkyKind.UNKNOWN -> R.drawable.weather_overcast
        SkyKind.RAIN -> when {
            condition.contains("大雨") || condition.contains("暴雨") -> R.drawable.weather_rain_heavy
            condition.contains("中雨") -> R.drawable.weather_rain_moderate
            else -> R.drawable.weather_rain
        }
        SkyKind.SNOW -> when {
            condition.contains("大雪") || condition.contains("暴雪") -> R.drawable.weather_snow_heavy
            condition.contains("中雪") -> R.drawable.weather_snow_moderate
            else -> R.drawable.weather_snow
        }
        SkyKind.THUNDER -> R.drawable.weather_thunderstorms
        SkyKind.SLEET -> R.drawable.weather_sleet
        SkyKind.FOG -> R.drawable.weather_fog
        SkyKind.HAZE -> R.drawable.weather_haze
    }
    Image(
        painter = painterResource(resource),
        contentDescription = null,
        modifier = modifier,
        contentScale = ContentScale.Fit,
    )
}

