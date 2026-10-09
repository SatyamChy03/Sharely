package com.sharely.sharely

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Picks files and hands Dart an open file descriptor for each one.
 *
 * Generic pickers copy every picked file into the app's cache first, which
 * for a 4 GB video means minutes of waiting and 4 GB of free space. Reading
 * the original through its descriptor skips that copy entirely.
 */
class DocumentPicker(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME).also { it.setMethodCallHandler(this) }
    // Opening a cloud document can download it, so never on the main thread.
    private val opener = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())
    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickFiles") return result.notImplemented()
        if (pendingResult != null) return result.error("busy", "Picker already open", null)
        pendingResult = result
        activity.startActivityForResult(pickIntent(call.argument<Boolean>("mediaOnly") == true), REQUEST_CODE)
    }

    /** Returns false for results that belong to someone else. */
    fun handleResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingResult ?: return true
        pendingResult = null
        val uris = if (resultCode == Activity.RESULT_OK) pickedUris(data) else emptyList()
        opener.execute {
            val files = uris.mapNotNull(::openForReading)
            mainThread.post { result.success(files) }
        }
        return true
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        pendingResult?.success(emptyList<Map<String, Any>>())
        pendingResult = null
        opener.shutdown()
    }

    private fun pickIntent(mediaOnly: Boolean): Intent {
        if (mediaOnly && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return Intent(MediaStore.ACTION_PICK_IMAGES)
                .putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, MediaStore.getPickImagesMaxLimit())
        }
        return Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            .apply {
                if (mediaOnly) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            }
    }

    private fun pickedUris(data: Intent?): List<Uri> {
        val clip = data?.clipData ?: return listOfNotNull(data?.data)
        return (0 until clip.itemCount).map { clip.getItemAt(it).uri }
    }

    /** Name, exact size and a descriptor Dart now owns and must close. */
    private fun openForReading(uri: Uri): Map<String, Any>? {
        return try {
            val name = displayName(uri) ?: uri.lastPathSegment ?: return null
            val descriptor = activity.contentResolver.openFileDescriptor(uri, "r") ?: return null
            val size = descriptor.statSize.takeIf { it >= 0 } ?: reportedSize(uri)
            if (size == null) {
                // Without a size the laptop can't check what arrives.
                descriptor.close()
                Log.w(TAG, "Skipped a picked file with no known size")
                return null
            }
            mapOf("name" to name, "size" to size, "fd" to descriptor.detachFd())
        } catch (error: IOException) {
            Log.w(TAG, "Couldn't open a picked file", error)
            null
        } catch (error: SecurityException) {
            Log.w(TAG, "Not allowed to read a picked file", error)
            null
        }
    }

    private fun displayName(uri: Uri): String? = queryColumn(uri, OpenableColumns.DISPLAY_NAME) {
        cursor, index -> cursor.getString(index)
    }

    private fun reportedSize(uri: Uri): Long? = queryColumn(uri, OpenableColumns.SIZE) {
        cursor, index -> cursor.getLong(index)
    }

    private fun <T> queryColumn(
        uri: Uri,
        column: String,
        read: (android.database.Cursor, Int) -> T,
    ): T? = activity.contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
        val index = cursor.getColumnIndex(column)
        if (index < 0 || !cursor.moveToFirst() || cursor.isNull(index)) null else read(cursor, index)
    }

    private companion object {
        const val NAME = "com.sharely/document_picker"
        const val TAG = "DocumentPicker"
        const val REQUEST_CODE = 0x5a4e
    }
}
