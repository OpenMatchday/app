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
        "selectAudioSource" -> {
          // OM-014 / AC-2.4: audio independent of video Program.
          // Measured path: media/preview/run_two_cameras_audio.py
          val args = call.arguments as? Map<*, *>
          val sourceId = args?.get("sourceId")?.toString() ?: "aud-1"
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "sourceId" to sourceId,
              "followsVideo" to false,
              "label" to sourceId,
            ),
          )
        }
        "readAudioMeters" -> {
          // OM-014 / AC-2.5 control stub. Live peak/RMS from media harness.
          val args = call.arguments as? Map<*, *>
          val sourceId = args?.get("sourceId")?.toString() ?: ""
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "sourceId" to sourceId,
              "peakDb" to -18.0,
              "rmsDb" to -24.0,
            ),
          )
        }
        "cutTake" -> {
          // OM-015 / AC-2.2: explicit Cut/Take only. Timing measured in
          // media/preview/run_cut_take.py (G3).
          val args = call.arguments as? Map<*, *>
          val action = args?.get("action")?.toString() ?: ""
          val previewSourceId = args?.get("previewSourceId")?.toString() ?: ""
          val programSourceId = args?.get("programSourceId")?.toString() ?: ""
          val previous = args?.get("previousProgramSourceId")?.toString() ?: ""
          val autoSwitch = args?.get("autoSwitch") == true
          val now = System.currentTimeMillis()
          if (autoSwitch) {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "error" to "Silent auto-switch refused (AC-2.2)",
              ),
            )
          } else if (action != "cut" && action != "take") {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "error" to "action must be cut or take",
              ),
            )
          } else if (previewSourceId.isEmpty() || programSourceId.isEmpty()) {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "error" to "Cut/Take requires preview and program source ids",
              ),
            )
          } else {
            result.success(
              mapOf(
                "ok" to true,
                "platform" to "android",
                "action" to action,
                "previewSourceId" to previewSourceId,
                "programSourceId" to programSourceId,
                "previousProgramSourceId" to previous,
                "issuedAtMs" to now,
                "appliedAtMs" to now,
              ),
            )
          }
        }
        "setTally" -> {
          // OM-015 / AC-2.3: Program camera tally.
          val args = call.arguments as? Map<*, *>
          val sourceId = args?.get("sourceId")?.toString() ?: ""
          val onAir = args?.get("onAir") == true
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "sourceId" to sourceId,
              "onAir" to onAir,
            ),
          )
        }
        "readAvSync" -> {
          // OM-016 / AC-2.6 stub. Live offset from media/preview/run_av_sync.py.
          val now = System.currentTimeMillis()
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "offsetMs" to (stubOffsetMs - stubCorrectionMs),
              "measuredAtMs" to now,
              "correctionMs" to stubCorrectionMs,
            ),
          )
        }
        "applyDriftCorrection" -> {
          // OM-016 / G5 control stub. Correction measured in media harness.
          val args = call.arguments as? Map<*, *>
          val correction = when (val raw = args?.get("correctionMs")) {
            is Number -> raw.toDouble()
            else -> 0.0
          }
          stubCorrectionMs = correction
          val residual = stubOffsetMs - stubCorrectionMs
          val now = System.currentTimeMillis()
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "offsetMs" to residual,
              "measuredAtMs" to now,
              "correctionMs" to stubCorrectionMs,
              "residualMs" to residual,
            ),
          )
        }
        "readSourceHealth" -> {
          // OM-017 / AC-2.8 stub. Live drop tests in media harness.
          val now = System.currentTimeMillis()
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "sources" to listOf(
                mapOf(
                  "sourceId" to "cam-1",
                  "state" to stubHealthCam1,
                  "observedAtMs" to now,
                  "detail" to "",
                ),
                mapOf(
                  "sourceId" to "cam-2",
                  "state" to stubHealthCam2,
                  "observedAtMs" to now,
                  "detail" to "",
                ),
              ),
              "programFallback" to stubProgramFallback,
              "sessionAlive" to stubSessionAlive,
            ),
          )
        }
        "applySourceLossFallback" -> {
          // OM-017 / AC-2.7: Program safe state; session must stay alive.
          val args = call.arguments as? Map<*, *>
          val lostSourceId = args?.get("lostSourceId")?.toString() ?: ""
          val programSourceId = args?.get("programSourceId")?.toString() ?: ""
          var programFallback =
            args?.get("programFallback")?.toString() ?: stubProgramFallback
          val alternateSourceId =
            args?.get("alternateSourceId")?.toString() ?: "cam-2"
          val now = System.currentTimeMillis()
          if (lostSourceId.isEmpty()) {
            result.success(
              mapOf(
                "ok" to false,
                "platform" to "android",
                "error" to "lostSourceId required",
                "sessionAlive" to true,
              ),
            )
            return@setMethodCallHandler
          }
          when (lostSourceId) {
            "cam-1" -> stubHealthCam1 = "lost"
            "cam-2" -> stubHealthCam2 = "lost"
          }
          stubProgramFallback = programFallback
          stubSessionAlive = true
          val nextProgram: String
          val message: String
          when (programFallback) {
            "alternate_source" -> {
              nextProgram = alternateSourceId
              message = "Program switched to alternate source $nextProgram"
            }
            "slate" -> {
              nextProgram = programSourceId
              message = "Program switched to slate"
            }
            else -> {
              programFallback = "last_frame_freeze"
              stubProgramFallback = programFallback
              nextProgram = programSourceId
              message = "Program held on last frame freeze"
            }
          }
          result.success(
            mapOf(
              "ok" to true,
              "platform" to "android",
              "lostSourceId" to lostSourceId,
              "programSafeState" to programFallback,
              "programSourceId" to nextProgram,
              "sessionAlive" to true,
              "observedAtMs" to now,
              "message" to message,
            ),
          )
        }
        else -> result.notImplemented()
      }
    }
  }

  companion object {
    private const val CHANNEL = "open_matchday/media"
    private var stubOffsetMs: Double = 80.0
    private var stubCorrectionMs: Double = 0.0
    private var stubHealthCam1: String = "connected"
    private var stubHealthCam2: String = "connected"
    private var stubProgramFallback: String = "last_frame_freeze"
    private var stubSessionAlive: Boolean = true
  }
}
