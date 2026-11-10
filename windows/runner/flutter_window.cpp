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
