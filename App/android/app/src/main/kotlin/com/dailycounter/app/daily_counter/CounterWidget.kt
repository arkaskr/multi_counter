package com.dailycounter.app.daily_counter

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class CounterWidget : GlanceAppWidget() {

    companion object {
        private val SMALL_SIZE = DpSize(100.dp, 60.dp)
        private val MEDIUM_SIZE = DpSize(200.dp, 80.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL_SIZE, MEDIUM_SIZE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val data = withContext(Dispatchers.IO) {
            try {
                CounterDatabaseHelper(context.applicationContext).getWidgetDisplayData()
            } catch (t: Throwable) {
                WidgetDisplayData(
                    date = "",
                    displayDate = "Today",
                    count = 0,
                    dailyLimit = 2,
                    totalAmount = 0.0,
                    totalMeals = 0,
                    currencySymbol = "₹",
                    selectedTheme = "midnight_dark",
                    isCompleted = false
                )
            }
        }
        val theme = CounterWidgetTheme.getTheme(data.selectedTheme)

        provideContent {
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(theme.background)
                    .cornerRadius(26.dp)
                    .padding(14.dp)
                    .clickable(actionStartActivity<MainActivity>())
            ) {
                WidgetModernContent(data, theme)
            }
        }
    }

    @Composable
    private fun WidgetModernContent(data: WidgetDisplayData, theme: WidgetColorTheme) {
        val amountStr = if (data.totalAmount % 1.0 == 0.0) {
            "${data.currencySymbol}${data.totalAmount.toInt()}"
        } else {
            "${data.currencySymbol}${String.format("%.2f", data.totalAmount)}"
        }

        val mealsStr = "${data.totalMeals} ${if (data.totalMeals == 1) "Meal" else "Meals"}"

        Column(
            modifier = GlanceModifier.fillMaxSize()
        ) {
            // Upper Section (Row): Left + button, Right divided column (Refresh on top, Meals below)
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .defaultWeight(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Top-Left: Large Squircle + Button
                Box(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .fillMaxHeight()
                        .background(if (data.isCompleted) theme.accent.copy(alpha = 0.85f) else theme.accent)
                        .cornerRadius(22.dp)
                        .clickable(actionRunCallback<CounterWidgetAction>()),
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        provider = ImageProvider(if (data.isCompleted) R.drawable.ic_check else R.drawable.ic_add),
                        contentDescription = if (data.isCompleted) "Completed" else "Add",
                        modifier = GlanceModifier
                            .width(32.dp)
                            .height(32.dp)
                    )
                }

                Spacer(modifier = GlanceModifier.width(10.dp))

                // Top-Right: Divided into Refresh button (top) and Meals count (below)
                Column(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .fillMaxHeight()
                ) {
                    // Top: Refresh Button
                    Box(
                        modifier = GlanceModifier
                            .fillMaxWidth()
                            .defaultWeight()
                            .background(theme.cardBackground)
                            .cornerRadius(16.dp)
                            .clickable(actionRunCallback<CounterWidgetRefreshAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Image(
                            provider = ImageProvider(R.drawable.ic_refresh),
                            contentDescription = "Refresh",
                            modifier = GlanceModifier
                                .width(22.dp)
                                .height(22.dp)
                        )
                    }

                    Spacer(modifier = GlanceModifier.height(8.dp))

                    // Below: Meals Pill
                    Box(
                        modifier = GlanceModifier
                            .fillMaxWidth()
                            .defaultWeight()
                            .background(theme.cardBackground)
                            .cornerRadius(16.dp)
                            .clickable(actionStartActivity<MainActivity>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = mealsStr,
                            style = TextStyle(
                                color = ColorProvider(theme.accent),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            // Bottom Section: Total amount card (no "Total" text label)
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .background(theme.cardBackground)
                    .cornerRadius(20.dp)
                    .clickable(actionStartActivity<MainActivity>()),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = amountStr,
                    style = TextStyle(
                        color = ColorProvider(if (theme.isDark) Color.White else theme.text),
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
            }
        }
    }
}

