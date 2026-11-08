package com.dailycounter.app.daily_counter

import androidx.compose.ui.graphics.Color

data class WidgetColorTheme(
    val background: Color,
    val surface: Color,
    val accent: Color,
    val text: Color,
    val secondaryText: Color,
    val isDark: Boolean,
    val cardBackground: Color
)

object CounterWidgetTheme {
    val softLight = WidgetColorTheme(
        background = Color(0xFFE8EDF4),
        surface = Color(0xFFE8EDF4),
        accent = Color(0xFF6C8EFF),
        text = Color(0xFF30394D),
        secondaryText = Color(0xFF8490A5),
        isDark = false,
        cardBackground = Color(0xFFDCE2EE)
    )

    val pureWhite = WidgetColorTheme(
        background = Color(0xFFF7F8FA),
        surface = Color(0xFFFFFFFF),
        accent = Color(0xFF5277E8),
        text = Color(0xFF252B38),
        secondaryText = Color(0xFF9299A7),
        isDark = false,
        cardBackground = Color(0xFFECEFF4)
    )

    val midnightDark = WidgetColorTheme(
        background = Color(0xFF1B1E28),
        surface = Color(0xFF252A39),
        accent = Color(0xFF7E97FF),
        text = Color(0xFFFFFFFF),
        secondaryText = Color(0xFF929BB1),
        isDark = true,
        cardBackground = Color(0xFF252A39)
    )

    val lavender = WidgetColorTheme(
        background = Color(0xFFEFECF8),
        surface = Color(0xFFEFECF8),
        accent = Color(0xFF9679DC),
        text = Color(0xFF38334D),
        secondaryText = Color(0xFF9690AA),
        isDark = false,
        cardBackground = Color(0xFFE3DFEF)
    )

    val mint = WidgetColorTheme(
        background = Color(0xFFE8F3EF),
        surface = Color(0xFFE8F3EF),
        accent = Color(0xFF45A98B),
        text = Color(0xFF29443D),
        secondaryText = Color(0xFF849E94),
        isDark = false,
        cardBackground = Color(0xFFDAE7E2)
    )

    val warmSand = WidgetColorTheme(
        background = Color(0xFFF2EDE5),
        surface = Color(0xFFF2EDE5),
        accent = Color(0xFFD58D58),
        text = Color(0xFF483B32),
        secondaryText = Color(0xFFA29487),
        isDark = false,
        cardBackground = Color(0xFFE6DED3)
    )


    fun getTheme(id: String): WidgetColorTheme {
        return when (id) {
            "pure_white" -> pureWhite
            "midnight_dark" -> midnightDark
            "lavender" -> lavender
            "mint" -> mint
            "warm_sand" -> warmSand
            else -> softLight
        }
    }
}
