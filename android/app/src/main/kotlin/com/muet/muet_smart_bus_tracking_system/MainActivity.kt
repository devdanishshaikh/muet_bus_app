package com.muet.muet_smart_bus_tracking_system

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.firebasemessaging.FlutterFirebaseMessagingService

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.muet.muet_smart_bus_tracking_system/notifications"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle notification click when app is launched from terminated state
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent == null) return
        val data = intent.data
        if (data != null && data.toString().contains("eventKey")) {
            // Pass the notification data to Flutter via MethodChannel
            val payload = data.toString()
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("notificationTap", payload)
        }
    }
}