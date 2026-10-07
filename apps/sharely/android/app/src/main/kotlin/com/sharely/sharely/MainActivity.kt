package com.sharely.sharely

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var documentPicker: DocumentPicker? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        SharelyEngine.ensureRunning(applicationContext)
        super.onCreate(savedInstanceState)
    }

    // The engine outlives this screen, so a send keeps going after the user
    // leaves the app or swipes it away from Recents.
    override fun getCachedEngineId(): String = SharelyEngine.ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        documentPicker = DocumentPicker(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        documentPicker?.detach()
        documentPicker = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("FlutterActivity still routes plugin results through this")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (documentPicker?.handleResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        // With nothing sending, closing the app should stop Dart as it used to.
        val isLeavingIdle = isFinishing && !TransferService.isRunning
        super.onDestroy()
        if (isLeavingIdle) SharelyEngine.shutDown()
    }
}
