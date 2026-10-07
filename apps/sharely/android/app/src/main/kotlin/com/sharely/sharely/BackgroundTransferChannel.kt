package com.sharely.sharely

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Lets Dart keep the process alive, with a notification, while it sends. */
object BackgroundTransferChannel : MethodChannel.MethodCallHandler {
    private const val NAME = "com.sharely/background_transfer"

    private var channel: MethodChannel? = null
    private var context: Context? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        this.context = context.applicationContext
        channel = MethodChannel(messenger, NAME).also { it.setMethodCallHandler(this) }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    /** The notification's Cancel button; Dart decides what cancelling means. */
    fun requestCancel() {
        channel?.invokeMethod("cancelRequested", null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context ?: return result.error("detached", null, null)
        val title = call.argument<String>("title").orEmpty()
        val text = call.argument<String>("text").orEmpty()
        when (call.method) {
            "start" -> TransferService.start(context, title, text)
            "update" -> TransferService.update(
                context,
                title,
                text,
                call.argument<Int>("percent") ?: 0,
            )
            "finish" -> TransferService.finish(context, title, text)
            "stop" -> TransferService.stop(context)
            else -> return result.notImplemented()
        }
        result.success(null)
    }
}
