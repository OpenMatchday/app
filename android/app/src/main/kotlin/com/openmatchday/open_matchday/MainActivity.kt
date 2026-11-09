package com.openmatchday.open_matchday

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    ).setMethodCallHandler { call, result ->
      if (call.method == "ping") {
        result.success(
          mapOf(
            "platform" to "android",
            "stamp" to System.currentTimeMillis().toString(),
          ),
        )
      } else {
        result.notImplemented()
      }
    }
  }

  companion object {
    private const val CHANNEL = "open_matchday/media"
  }
}
