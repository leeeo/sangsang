package com.sangbusangjo.mobile

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException

class EventReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val time = pending(context) ?: return
        val now = System.currentTimeMillis()
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (time > now) arm(context, time) else storage(context).delete()
            }
            fire -> {
                if (time != intent.getLongExtra("time", 0) || time > now) return
                storage(context).delete()
                if (!allowed(context)) return
                val manager = context.getSystemService(NotificationManager::class.java)
                val open = PendingIntent.getActivity(
                    context, notificationId, Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                val builder = if (Build.VERSION.SDK_INT >= 26) {
                    Notification.Builder(context, channelId)
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(context)
                }
                try {
                    manager.notify(notificationId, builder
                        .setSmallIcon(android.R.drawable.ic_popup_reminder)
                        .setContentTitle("상부상조")
                        .setContentText("챙길 경조사 일정이 있어요.")
                        .setVisibility(Notification.VISIBILITY_PRIVATE)
                        .setContentIntent(open)
                        .setAutoCancel(true)
                        .build())
                } catch (_: SecurityException) {
                    // Permission can change between the check and delivery.
                }
            }
        }
    }

    companion object {
        private const val notificationId = 742
        private const val channelId = "event_reminders"
        private const val fire = "com.sangbusangjo.mobile.EVENT_REMINDER"
        private fun storage(context: Context) =
            AtomicFile(File(context.noBackupFilesDir, "event_reminder"))

        fun pending(context: Context): Long? = try {
            storage(context).readFully().decodeToString().toLongOrNull()
        } catch (_: FileNotFoundException) {
            null
        }

        fun allowed(context: Context): Boolean {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(
                    channelId, "경조사 알림", NotificationManager.IMPORTANCE_DEFAULT,
                ))
                if (manager.getNotificationChannel(channelId)?.importance ==
                    NotificationManager.IMPORTANCE_NONE) return false
            }
            return Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled()
        }

        private fun alarmIntent(context: Context, time: Long) =
            PendingIntent.getBroadcast(
                context, notificationId,
                Intent(context, EventReminderReceiver::class.java)
                    .setAction(fire).putExtra("time", time),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

        private fun arm(context: Context, time: Long) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarmIntent(context, time))
        }

        fun schedule(context: Context, time: Long) {
            val file = storage(context)
            val old = pending(context)
            val stream = file.startWrite()
            try {
                stream.write(time.toString().encodeToByteArray())
                arm(context, time)
                file.finishWrite(stream)
            } catch (e: Exception) {
                file.failWrite(stream)
                if (old != null) arm(context, old)
                throw e
            }
        }

        fun cancel(context: Context) {
            val alarms = context.getSystemService(AlarmManager::class.java)
            alarms.cancel(alarmIntent(context, 0))
            storage(context).delete()
        }
    }
}
