package com.dailycounter.app.daily_counter

import android.content.Context
import android.util.Log
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

object WidgetUpdateManager {
    private const val TAG = "WidgetUpdateManager"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun updateAll(context: Context?) {
        if (context == null) return
        val appContext = context.applicationContext ?: context
        scope.launch {
            try {
                CounterWidget().updateAll(appContext)
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to update widget: ${t.message}")
            }
        }
    }
}
