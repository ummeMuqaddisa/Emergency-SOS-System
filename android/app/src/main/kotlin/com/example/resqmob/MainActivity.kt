package com.example.resqmob

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app_widget_channel"
    private var flutterEngine: FlutterEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        this.flutterEngine = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialData") {
                result.success(handleIntent(intent))
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sendDataToFlutter(intent)
    }

    private fun sendDataToFlutter(intent: Intent) {
        handleIntent(intent)?.let { data ->
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onWidgetDataReceived", data)
            }
        }
    }

    private fun handleIntent(intent: Intent?): String? {
        return if (intent?.action == Intent.ACTION_VIEW) {
            intent.data?.getQueryParameter("data")
        } else {
            null
        }
    }
}