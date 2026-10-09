package com.sharely.sharely

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * Keeps the app's process running at foreground priority while a send is in
 * progress, so Android doesn't freeze it once the user leaves the app.
 *
 * Wi-Fi power saving and CPU sleep would otherwise throttle a long send with
 * the screen off, so the service also holds a Wi-Fi lock and a wake lock.
 */
class TransferService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var isInForeground = false
    private val wifiLocks = mutableListOf<WifiManager.WifiLock>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val text = intent?.getStringExtra(EXTRA_TEXT).orEmpty()
        when (intent?.action) {
            ACTION_START -> startInForeground(title, text)
            ACTION_UPDATE -> if (isInForeground) {
                TransferNotifications.post(
                    this,
                    TransferNotifications.PROGRESS_ID,
                    TransferNotifications.progress(this, title, text, intent.getIntExtra(EXTRA_PERCENT, 0)),
                )
            } else {
                stopSelf()
            }
            ACTION_FINISH -> {
                stopRunning()
                TransferNotifications.post(
                    this,
                    TransferNotifications.FINISHED_ID,
                    TransferNotifications.finished(this, title, text),
                )
            }
            ACTION_CANCEL -> BackgroundTransferChannel.requestCancel()
            else -> stopRunning()
        }
        return START_NOT_STICKY
    }

    // Android 15 caps data-sync services at six hours a day.
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopRunning()
    }

    override fun onDestroy() {
        releaseLocks()
        isRunning = false
        super.onDestroy()
    }

    private fun startInForeground(title: String, text: String) {
        val notification = TransferNotifications.progress(this, title, text, null)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    TransferNotifications.PROGRESS_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(TransferNotifications.PROGRESS_ID, notification)
            }
        } catch (error: IllegalStateException) {
            Log.w(TAG, "Not allowed to run in the foreground", error)
            stopRunning()
            return
        }
        isInForeground = true
        holdLocks()
    }

    private fun stopRunning() {
        isRunning = false
        isInForeground = false
        releaseLocks()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun holdLocks() {
        if (wakeLock == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, LOCK_TAG)
                .apply {
                    setReferenceCounted(false)
                    acquire(MAX_LOCK_MILLIS)
                }
        }
        if (wifiLocks.isNotEmpty()) return
        val wifi = applicationContext.getSystemService(WifiManager::class.java)
        for (mode in wifiLockModes()) {
            wifiLocks += wifi.createWifiLock(mode, LOCK_TAG).apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    // Low latency only applies with the screen on; high-perf covers the rest
    // on the Android versions that still honour it.
    @Suppress("DEPRECATION")
    private fun wifiLockModes(): List<Int> = buildList {
        add(WifiManager.WIFI_MODE_FULL_HIGH_PERF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            add(WifiManager.WIFI_MODE_FULL_LOW_LATENCY)
        }
    }

    private fun releaseLocks() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        wifiLocks.filter { it.isHeld }.forEach { it.release() }
        wifiLocks.clear()
    }

    companion object {
        private const val TAG = "TransferService"
        private const val LOCK_TAG = "sharely:transfer"
        private const val MAX_LOCK_MILLIS = 6 * 60 * 60 * 1000L
        private const val ACTION_START = "com.sharely.transfer.START"
        private const val ACTION_UPDATE = "com.sharely.transfer.UPDATE"
        private const val ACTION_FINISH = "com.sharely.transfer.FINISH"
        private const val ACTION_STOP = "com.sharely.transfer.STOP"
        const val ACTION_CANCEL = "com.sharely.transfer.CANCEL"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PERCENT = "percent"

        /** True from [start] until the send finishes or Android stops it. */
        @Volatile
        var isRunning = false
            private set

        fun start(context: Context, title: String, text: String) {
            isRunning = deliver(context, ACTION_START, title, text, inForeground = true)
        }

        fun update(context: Context, title: String, text: String, percent: Int) {
            if (!isRunning) return
            deliver(context, ACTION_UPDATE, title, text) { putExtra(EXTRA_PERCENT, percent) }
        }

        fun finish(context: Context, title: String, text: String) {
            if (!isRunning) return
            isRunning = false
            deliver(context, ACTION_FINISH, title, text)
        }

        fun stop(context: Context) {
            if (!isRunning) return
            isRunning = false
            deliver(context, ACTION_STOP, "", "")
        }

        private fun deliver(
            context: Context,
            action: String,
            title: String,
            text: String,
            inForeground: Boolean = false,
            extras: Intent.() -> Unit = {},
        ): Boolean {
            val intent = Intent(context, TransferService::class.java)
                .setAction(action)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .apply(extras)
            return try {
                if (inForeground && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (error: IllegalStateException) {
                // Thrown when the app is already in the background; the send
                // still runs for as long as Android lets the process live.
                Log.w(TAG, "Couldn't reach the transfer service", error)
                false
            }
        }
    }
}
