package com.sharely.sharely

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

/** The ongoing "Sending…" notification and the one left when it's done. */
object TransferNotifications {
    const val PROGRESS_ID = 1001
    const val FINISHED_ID = 1002
    private const val CHANNEL_ID = "transfers"

    fun progress(context: Context, title: String, text: String, percent: Int?): Notification =
        builder(context, title, text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setProgress(100, percent ?: 0, percent == null)
            .addAction(cancelAction(context))
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                }
            }
            .build()

    fun finished(context: Context, title: String, text: String): Notification =
        builder(context, title, text).setAutoCancel(true).build()

    fun post(context: Context, id: Int, notification: Notification) {
        context.getSystemService(NotificationManager::class.java).notify(id, notification)
    }

    private fun builder(context: Context, title: String, text: String): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createChannel(context)
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_sharely)
            .setColor(context.getColor(R.color.sharely_accent))
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openAppIntent(context))
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.transfer_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = context.getString(R.string.transfer_channel_description) }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun openAppIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        return PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE)
    }

    private fun cancelAction(context: Context): Notification.Action {
        val cancel = PendingIntent.getService(
            context,
            1,
            Intent(context, TransferService::class.java).setAction(TransferService.ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Action.Builder(
            Icon.createWithResource(context, R.drawable.ic_stat_sharely),
            context.getString(R.string.transfer_cancel),
            cancel,
        ).build()
    }
}
