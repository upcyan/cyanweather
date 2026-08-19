package com.cyanweather.app.ui

import androidx.compose.material3.LocalTextStyle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

val LocalFontScale = compositionLocalOf { 1.3f }

@Composable
fun fs(size: Int): TextUnit = (size * LocalFontScale.current).sp

@Composable
fun fst(size: Int, weight: FontWeight? = null, color: Color? = null, align: TextAlign? = null): TextStyle {
    val s = size * LocalFontScale.current
    return LocalTextStyle.current.copy(
        fontSize = s.sp,
        lineHeight = (s * 1.45f).sp,
        fontWeight = weight,
        color = color ?: Color.Unspecified,
        textAlign = align ?: TextAlign.Unspecified
    )
}