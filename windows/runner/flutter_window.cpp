#include "flutter_window.h"

#include <optional>
#include <string>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring Utf8ToWideForFloatingUpload(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  int length = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }

  std::wstring result(static_cast<size_t>(length - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, result.data(), length);
  return result;
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

  floating_upload_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "cloudreve4_flutter/floating_upload",
          &flutter::StandardMethodCodec::GetInstance());
  floating_upload_window_ =
      std::make_unique<FloatingUploadWindow>(floating_upload_channel_.get());

  floating_upload_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* arguments = call.arguments();
        if (call.method_name() == "setEnabled") {
          bool enabled = false;
          if (arguments) {
            if (const auto* value = std::get_if<bool>(arguments)) {
              enabled = *value;
            }
          }
          if (floating_upload_window_) {
            floating_upload_window_->SetEnabled(enabled);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "setSiteIconPath") {
          std::wstring path = L"";
          if (arguments) {
            if (const auto* text = std::get_if<std::string>(arguments)) {
              path = Utf8ToWideForFloatingUpload(*text);
            }
          }
          if (floating_upload_window_) {
            floating_upload_window_->SetSiteIconPath(path);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "showStatus") {
          std::wstring message = L"";
          bool is_error = false;

          if (arguments) {
            if (const auto* map =
                    std::get_if<flutter::EncodableMap>(arguments)) {
              auto message_it = map->find(flutter::EncodableValue("message"));
              if (message_it != map->end()) {
                if (const auto* text =
                        std::get_if<std::string>(&message_it->second)) {
                  message = Utf8ToWideForFloatingUpload(*text);
                }
              }

              auto error_it = map->find(flutter::EncodableValue("error"));
              if (error_it != map->end()) {
                if (const auto* value = std::get_if<bool>(&error_it->second)) {
                  is_error = *value;
                }
              }
            }
          }

          if (floating_upload_window_) {
            floating_upload_window_->ShowStatus(message, is_error);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        result->NotImplemented();
      });

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
