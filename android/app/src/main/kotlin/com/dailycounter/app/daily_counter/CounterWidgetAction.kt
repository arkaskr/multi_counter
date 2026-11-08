package com.dailycounter.app.daily_counter

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class CounterWidgetAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        try {
            val appContext = context.applicationContext ?: context
            val dbHelper = CounterDatabaseHelper(appContext)

            // 1. Transactionally increment in SQLite
            val updated = withContext(Dispatchers.IO) {
                dbHelper.incrementToday()
            }

            // 2. Immediately update the tapped widget instance synchronously so changes reflect instantly
            CounterWidget().update(context, glanceId)

            // 3. Update any other widget instances
            WidgetUpdateManager.updateAll(appContext)

            // 4. Notify active Flutter instance if running
            if (updated) {
                MainActivity.notifyFlutterWidgetUpdated()
            }
        } catch (t: Throwable) {
            Log.e("CounterWidgetAction", "Error processing widget action", t)
        }
    }
}

class CounterWidgetRefreshAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        try {
            val appContext = context.applicationContext ?: context
            // 1. Immediately update the tapped widget instance
            CounterWidget().update(context, glanceId)

            // 2. Update any other widget instances
            WidgetUpdateManager.updateAll(appContext)

            // 3. Notify Flutter instance
            MainActivity.notifyFlutterWidgetRefreshed()
        } catch (t: Throwable) {
            Log.e("CounterWidgetRefreshAction", "Error processing refresh action", t)
        }
    }
}

