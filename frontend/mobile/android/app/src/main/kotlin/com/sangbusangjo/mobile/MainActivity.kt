package com.sangbusangjo.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sangsang/reminder")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pending" -> result.success(EventReminderReceiver.pending(this))
                        "allowed" -> result.success(EventReminderReceiver.allowed(this))
                        "requestPermission" -> {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                PackageManager.PERMISSION_GRANTED
                            ) {
                                if (permissionResult != null) {
                                    result.error("busy", null, null)
                                } else {
                                    permissionResult = result
                                    try {
                                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 734)
                                    } catch (e: Exception) {
                                        permissionResult = null
                                        throw e
                                    }
                                }
                            } else result.success(EventReminderReceiver.allowed(this))
                        }
                        "settings" -> {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(null)
                        }
                        "schedule" -> {
                            val whenMs = (call.arguments as? Number)?.toLong()
                            if (whenMs == null || whenMs <= System.currentTimeMillis() ||
                                !EventReminderReceiver.allowed(this)
                            ) result.error("invalid", null, null)
                            else {
                                EventReminderReceiver.schedule(this, whenMs)
                                result.success(null)
                            }
                        }
                        "cancel" -> {
                            EventReminderReceiver.cancel(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("reminder_failed", null, null)
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 734) {
            val callback = permissionResult
            permissionResult = null
            callback?.success(EventReminderReceiver.allowed(this))
        }
    }
}
