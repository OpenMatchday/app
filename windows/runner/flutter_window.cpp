#include "flutter_window.h"

#include <chrono>
#include <memory>
#include <optional>
#include <string>
#include <variant>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kMediaChannel[] = "open_matchday/media";

// OM-016 stub A/V offset state (control plane). Live numbers from media G5.
double g_av_stub_offset_ms = 80.0;
double g_av_stub_correction_ms = 0.0;

void RegisterMediaChannel(flutter::FlutterEngine* engine) {
  // Keep channel for process lifetime so the handler stays registered.
  static auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), kMediaChannel,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "ping") {
          const auto now_ms =
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  std::chrono::system_clock::now().time_since_epoch())
                  .count();
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("stamp")] =
              flutter::EncodableValue(std::to_string(now_ms));
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "startMedia") {
          // AC-1.3: media Wi-Fi/Ethernet only. Mirror media/gates/media_medium.py.
          // Host network profile APIs (not yet wired for live detect):
          // NetworkInformation::GetInternetConnectionProfile —
          // https://learn.microsoft.com/en-us/uwp/api/windows.networking.connectivity.networkinformation.getinternetconnectionprofile
          std::string medium;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto it = map->find(flutter::EncodableValue("medium"));
            if (it != map->end()) {
              if (const auto* value = std::get_if<std::string>(&it->second)) {
                medium = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("medium")] =
              flutter::EncodableValue(medium);
          const bool allowed = medium == "wifi" || medium == "ethernet";
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(allowed);
          if (!allowed) {
            payload[flutter::EncodableValue("error")] = flutter::EncodableValue(
                "Media streams use Wi-Fi or Ethernet only; refused medium=\"" +
                medium + "\"");
          }
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "startPreview") {
          // OM-013 Preview path control stub. Capture/encode/SRT measured in
          // sibling media/preview/run_one_camera.py (G1/G2 start).
          std::string medium;
          std::string source_id = "cam-1";
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto medium_it = map->find(flutter::EncodableValue("medium"));
            if (medium_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&medium_it->second)) {
                medium = *value;
              }
            }
            const auto source_it =
                map->find(flutter::EncodableValue("sourceId"));
            if (source_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&source_it->second)) {
                source_id = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("medium")] =
              flutter::EncodableValue(medium);
          payload[flutter::EncodableValue("sourceId")] =
              flutter::EncodableValue(source_id);
          payload[flutter::EncodableValue("bus")] =
              flutter::EncodableValue("preview");
          const bool allowed = medium == "wifi" || medium == "ethernet";
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(allowed);
          if (allowed) {
            payload[flutter::EncodableValue("message")] =
                flutter::EncodableValue(
                    "Preview receiving on " + medium + " (native control stub; "
                    "frames measured via media preview harness)");
            payload[flutter::EncodableValue("snapshotPath")] =
                flutter::EncodableValue("preview/out/director_preview.jpg");
          } else {
            payload[flutter::EncodableValue("error")] = flutter::EncodableValue(
                "Media streams use Wi-Fi or Ethernet only; refused medium=\"" +
                medium + "\"");
          }
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "stopPreview") {
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "selectAudioSource") {
          // OM-014 / AC-2.4: audio independent of video Program.
          // Measured path: media/preview/run_two_cameras_audio.py
          std::string source_id = "aud-1";
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto source_it =
                map->find(flutter::EncodableValue("sourceId"));
            if (source_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&source_it->second)) {
                source_id = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("sourceId")] =
              flutter::EncodableValue(source_id);
          payload[flutter::EncodableValue("followsVideo")] =
              flutter::EncodableValue(false);
          payload[flutter::EncodableValue("label")] =
              flutter::EncodableValue(source_id);
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "readAudioMeters") {
          // OM-014 / AC-2.5 control stub. Live peak/RMS from media harness.
          std::string source_id;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto source_it =
                map->find(flutter::EncodableValue("sourceId"));
            if (source_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&source_it->second)) {
                source_id = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("sourceId")] =
              flutter::EncodableValue(source_id);
          // Stub levels so UI meters render; harness records real dB.
          payload[flutter::EncodableValue("peakDb")] =
              flutter::EncodableValue(-18.0);
          payload[flutter::EncodableValue("rmsDb")] =
              flutter::EncodableValue(-24.0);
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "cutTake") {
          // OM-015 / AC-2.2: explicit Cut/Take only. Timing in
          // media/preview/run_cut_take.py (G3).
          std::string action;
          std::string preview_source_id;
          std::string program_source_id;
          std::string previous;
          bool auto_switch = false;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto action_it = map->find(flutter::EncodableValue("action"));
            if (action_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&action_it->second)) {
                action = *value;
              }
            }
            const auto preview_it =
                map->find(flutter::EncodableValue("previewSourceId"));
            if (preview_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&preview_it->second)) {
                preview_source_id = *value;
              }
            }
            const auto program_it =
                map->find(flutter::EncodableValue("programSourceId"));
            if (program_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&program_it->second)) {
                program_source_id = *value;
              }
            }
            const auto previous_it =
                map->find(flutter::EncodableValue("previousProgramSourceId"));
            if (previous_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&previous_it->second)) {
                previous = *value;
              }
            }
            const auto auto_it =
                map->find(flutter::EncodableValue("autoSwitch"));
            if (auto_it != map->end()) {
              if (const auto* value = std::get_if<bool>(&auto_it->second)) {
                auto_switch = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          const auto now_ms = static_cast<int64_t>(
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  std::chrono::system_clock::now().time_since_epoch())
                  .count());
          if (auto_switch) {
            payload[flutter::EncodableValue("ok")] =
                flutter::EncodableValue(false);
            payload[flutter::EncodableValue("error")] = flutter::EncodableValue(
                "Silent auto-switch refused (AC-2.2)");
          } else if (action != "cut" && action != "take") {
            payload[flutter::EncodableValue("ok")] =
                flutter::EncodableValue(false);
            payload[flutter::EncodableValue("error")] =
                flutter::EncodableValue("action must be cut or take");
          } else if (preview_source_id.empty() || program_source_id.empty()) {
            payload[flutter::EncodableValue("ok")] =
                flutter::EncodableValue(false);
            payload[flutter::EncodableValue("error")] = flutter::EncodableValue(
                "Cut/Take requires preview and program source ids");
          } else {
            payload[flutter::EncodableValue("ok")] =
                flutter::EncodableValue(true);
            payload[flutter::EncodableValue("action")] =
                flutter::EncodableValue(action);
            payload[flutter::EncodableValue("previewSourceId")] =
                flutter::EncodableValue(preview_source_id);
            payload[flutter::EncodableValue("programSourceId")] =
                flutter::EncodableValue(program_source_id);
            payload[flutter::EncodableValue("previousProgramSourceId")] =
                flutter::EncodableValue(previous);
            payload[flutter::EncodableValue("issuedAtMs")] =
                flutter::EncodableValue(now_ms);
            payload[flutter::EncodableValue("appliedAtMs")] =
                flutter::EncodableValue(now_ms);
          }
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "setTally") {
          // OM-015 / AC-2.3: Program camera tally.
          std::string source_id;
          bool on_air = false;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto source_it =
                map->find(flutter::EncodableValue("sourceId"));
            if (source_it != map->end()) {
              if (const auto* value =
                      std::get_if<std::string>(&source_it->second)) {
                source_id = *value;
              }
            }
            const auto on_air_it = map->find(flutter::EncodableValue("onAir"));
            if (on_air_it != map->end()) {
              if (const auto* value = std::get_if<bool>(&on_air_it->second)) {
                on_air = *value;
              }
            }
          }
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("sourceId")] =
              flutter::EncodableValue(source_id);
          payload[flutter::EncodableValue("onAir")] =
              flutter::EncodableValue(on_air);
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "readAvSync") {
          // OM-016 / AC-2.6 stub. Live offset from media/preview/run_av_sync.py.
          const auto now_ms = static_cast<int64_t>(
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  std::chrono::system_clock::now().time_since_epoch())
                  .count());
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("offsetMs")] =
              flutter::EncodableValue(g_av_stub_offset_ms -
                                      g_av_stub_correction_ms);
          payload[flutter::EncodableValue("measuredAtMs")] =
              flutter::EncodableValue(now_ms);
          payload[flutter::EncodableValue("correctionMs")] =
              flutter::EncodableValue(g_av_stub_correction_ms);
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        if (call.method_name() == "applyDriftCorrection") {
          // OM-016 / G5 control stub. Correction measured in media harness.
          double correction_ms = 0.0;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto corr_it =
                map->find(flutter::EncodableValue("correctionMs"));
            if (corr_it != map->end()) {
              if (const auto* as_double =
                      std::get_if<double>(&corr_it->second)) {
                correction_ms = *as_double;
              } else if (const auto* as_i32 =
                             std::get_if<int32_t>(&corr_it->second)) {
                correction_ms = static_cast<double>(*as_i32);
              } else if (const auto* as_i64 =
                             std::get_if<int64_t>(&corr_it->second)) {
                correction_ms = static_cast<double>(*as_i64);
              }
            }
          }
          g_av_stub_correction_ms = correction_ms;
          const double residual =
              g_av_stub_offset_ms - g_av_stub_correction_ms;
          const auto now_ms = static_cast<int64_t>(
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  std::chrono::system_clock::now().time_since_epoch())
                  .count());
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("ok")] =
              flutter::EncodableValue(true);
          payload[flutter::EncodableValue("platform")] =
              flutter::EncodableValue("windows");
          payload[flutter::EncodableValue("offsetMs")] =
              flutter::EncodableValue(residual);
          payload[flutter::EncodableValue("measuredAtMs")] =
              flutter::EncodableValue(now_ms);
          payload[flutter::EncodableValue("correctionMs")] =
              flutter::EncodableValue(g_av_stub_correction_ms);
          payload[flutter::EncodableValue("residualMs")] =
              flutter::EncodableValue(residual);
          result->Success(flutter::EncodableValue(payload));
          return;
        }
        result->NotImplemented();
      });
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterMediaChannel(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
