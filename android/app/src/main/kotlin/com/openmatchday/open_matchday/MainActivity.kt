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
      when (call.method) {
        "ping" -> {
          result.success(
            mapOf(
              "platform" to "android",
              "stamp" to System.currentTimeMillis().toString(),
            ),
          )
        }
        "startMedia" -> {
          // AC-1.3: media Wi-Fi/Ethernet only. Mirror media/gates/media_medium.py.
          // Transport detection: NetworkCapabilities.hasTransport
          // (TRANSPORT_WIFI / TRANSPORT_ETHERNET / TRANSPORT_CELLULAR /
          // TRANSPORT_BLUETOOTH) — https://developer.android.com/reference/android/net/NetworkCapabilities
          val args = call.arguments as? Map<*, *>
          val medium = args?.get("medium")?.toString()
          if (medium == "wifi" || medium == "ethernet") {
            result.success(
              mapOf(
                "ok" to true,
                "platform" to "android",
                "medium" to medium,
              ),
            )
          } else {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "medium" to (medium ?: ""),
                "error" to "Media streams use Wi-Fi or Ethernet only; refused medium=\"$medium\"",
              ),
            )
          }
        }
        "startPreview" -> {
          // OM-013 Preview path control stub. Capture/encode/SRT measured in
          // sibling media/preview/run_one_camera.py (G1/G2 start).
          val args = call.arguments as? Map<*, *>
          val medium = args?.get("medium")?.toString() ?: ""
          val sourceId = args?.get("sourceId")?.toString() ?: "cam-1"
          if (medium == "wifi" || medium == "ethernet") {
            result.success(
              mapOf(
                "ok" to true,
                "platform" to "android",
                "medium" to medium,
                "sourceId" to sourceId,
                "bus" to "preview",
                "message" to
                  "Preview receiving on $medium (native control stub; frames measured via media preview harness)",
                "snapshotPath" to "preview/out/director_preview.jpg",
              ),
            )
          } else {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "medium" to medium,
                "sourceId" to sourceId,
                "error" to
                  "Media streams use Wi-Fi or Ethernet only; refused medium=\"$medium\"",
              ),
            )
          }
        }
        "stopPreview" -> {
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
            ),
          )
        }
        else -> result.notImplemented()
      }
    }
  }

  companion object {
    private const val CHANNEL = "open_matchday/media"
  }
}
