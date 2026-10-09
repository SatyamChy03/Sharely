package com.sharely.sharely

import android.os.Build
import android.os.Environment
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Tells Dart where the shared Downloads folder is, for files from the laptop. */
object StorageChannel {
    private const val NAME = "com.sharely/storage"

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, NAME).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "sharedDownloads") {
                    result.success(sharedDownloads())
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun sharedDownloads(): Map<String, Any> {
        // Deprecated for reading other apps' files, but still how an app
        // names the folder it adds its own files to by path.
        @Suppress("DEPRECATION")
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        return mapOf(
            "path" to downloads.absolutePath,
            // From Android 11 an app may add files here without a permission.
            "needsPermission" to (Build.VERSION.SDK_INT < Build.VERSION_CODES.R),
        )
    }
}
