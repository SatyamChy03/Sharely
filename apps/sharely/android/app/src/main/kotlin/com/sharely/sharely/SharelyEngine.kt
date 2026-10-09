package com.sharely.sharely

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/** Owns the Flutter engine so it can keep running without an activity. */
object SharelyEngine {
    const val ID = "sharely"

    fun ensureRunning(context: Context) {
        val cache = FlutterEngineCache.getInstance()
        if (cache.contains(ID)) return
        val engine = FlutterEngine(context)
        BackgroundTransferChannel.attach(context, engine.dartExecutor.binaryMessenger)
        StorageChannel.attach(engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        cache.put(ID, engine)
    }

    fun shutDown() {
        val cache = FlutterEngineCache.getInstance()
        val engine = cache.get(ID) ?: return
        cache.remove(ID)
        BackgroundTransferChannel.detach()
        StorageChannel.detach()
        engine.destroy()
    }
}
