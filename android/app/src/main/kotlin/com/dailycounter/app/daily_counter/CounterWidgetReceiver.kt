package com.dailycounter.app.daily_counter

import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

class CounterWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CounterWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val action = intent.action
            if (action == Intent.ACTION_DATE_CHANGED ||
                action == Intent.ACTION_TIME_CHANGED ||
                action == Intent.ACTION_TIMEZONE_CHANGED ||
                action == Intent.ACTION_BOOT_COMPLETED
            ) {
                WidgetUpdateManager.updateAll(context)
            }
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }
}
