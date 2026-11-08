package com.dailycounter.app.daily_counter

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.dailycounter.app/widget"
        private var methodChannel: MethodChannel? = null

        fun notifyFlutterWidgetUpdated() {
            try {
                Handler(Looper.getMainLooper()).post {
                    try {
                        methodChannel?.invokeMethod("onWidgetIncremented", null)
                    } catch (t: Throwable) {
                        t.printStackTrace()
                    }
                }
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }

        fun notifyFlutterWidgetRefreshed() {
            try {
                Handler(Looper.getMainLooper()).post {
                    try {
                        methodChannel?.invokeMethod("onWidgetRefresh", null)
                    } catch (t: Throwable) {
                        t.printStackTrace()
                    }
                }
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    try {
                        when (call.method) {
                            "updateWidget" -> {
                                WidgetUpdateManager.updateAll(applicationContext)
                                result.success(true)
                            }
                            else -> {
                                result.notImplemented()
                            }
                        }
                    } catch (t: Throwable) {
                        result.error("ERROR", t.message, null)
                    }
                }
            }
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            // Refresh widget state when app returns to foreground
            WidgetUpdateManager.updateAll(applicationContext)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
