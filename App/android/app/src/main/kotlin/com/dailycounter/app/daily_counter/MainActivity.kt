package com.dailycounter.app.daily_counter

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.dailycounter.app/widget"
        private const val UPDATER_CHANNEL = "com.dailycounter.app/updater"
        private var methodChannel: MethodChannel? = null
        private var updaterChannel: MethodChannel? = null

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

            updaterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    try {
                        when (call.method) {
                            "getAppVersion" -> {
                                val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                                } else {
                                    @Suppress("DEPRECATION")
                                    packageManager.getPackageInfo(packageName, 0)
                                }
                                val versionCode = PackageInfoCompat.getLongVersionCode(packageInfo)
                                val versionName = packageInfo.versionName ?: ""
                                result.success(
                                    mapOf(
                                        "versionCode" to versionCode,
                                        "versionName" to versionName,
                                        "packageName" to packageName
                                    )
                                )
                            }
                            "canRequestPackageInstalls" -> {
                                val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    packageManager.canRequestPackageInstalls()
                                } else {
                                    true
                                }
                                result.success(canInstall)
                            }
                            "openInstallPermissionSettings" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    try {
                                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                            data = Uri.parse("package:$packageName")
                                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        }
                                        startActivity(intent)
                                        result.success(true)
                                    } catch (e: Exception) {
                                        try {
                                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                                data = Uri.parse("package:$packageName")
                                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                            }
                                            startActivity(intent)
                                            result.success(true)
                                        } catch (e2: Exception) {
                                            result.error("SETTINGS_ERROR", e2.message, null)
                                        }
                                    }
                                } else {
                                    result.success(true)
                                }
                            }
                            "installApk" -> {
                                val filePath = call.argument<String>("filePath")
                                if (filePath.isNullOrBlank()) {
                                    result.error("INVALID_PATH", "File path cannot be empty", null)
                                    return@setMethodCallHandler
                                }
                                val file = File(filePath)
                                if (!file.exists()) {
                                    result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                                    return@setMethodCallHandler
                                }

                                val contentUri = FileProvider.getUriForFile(
                                    applicationContext,
                                    "${applicationContext.packageName}.fileprovider",
                                    file
                                )

                                val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(contentUri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(installIntent)
                                result.success(true)
                            }
                            else -> {
                                result.notImplemented()
                            }
                        }
                    } catch (t: Throwable) {
                        result.error("UPDATER_ERROR", t.message, null)
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
        updaterChannel = null
        super.onDestroy()
    }
}
