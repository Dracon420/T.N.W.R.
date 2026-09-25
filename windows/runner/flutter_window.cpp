#include "flutter_window.h"

#include <endpointvolume.h>
#include <flutter/standard_method_codec.h>
#include <mmdeviceapi.h>
#include <mmsystem.h>

#include <algorithm>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "winmm.lib")

namespace {

std::wstring Utf8ToWide(const std::string& s) {
  int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
  std::wstring out(len > 0 ? len - 1 : 0, L'\0');
  if (len > 0) {
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, out.data(), len);
  }
  return out;
}

// Loops a WAV file with the OS player: no extra threads, nothing to crash.
void HandleSoundCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "loop") {
    const auto* path = std::get_if<std::string>(call.arguments());
    if (!path) {
      result->Error("BAD_ARGS", "Expected a file path");
      return;
    }
    if (!PlaySoundW(Utf8ToWide(*path).c_str(), nullptr,
                    SND_FILENAME | SND_ASYNC | SND_LOOP | SND_NODEFAULT)) {
      result->Error("PLAY_FAILED", "Could not play " + *path);
      return;
    }
    result->Success();
  } else if (call.method_name() == "stop") {
    PlaySoundW(nullptr, nullptr, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

// Returns the volume control of the default playback device, or nullptr.
// Caller must Release() it. COM is initialized by main.cpp.
IAudioEndpointVolume* GetEndpointVolume() {
  IMMDeviceEnumerator* enumerator = nullptr;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                              reinterpret_cast<void**>(&enumerator)))) {
    return nullptr;
  }
  IMMDevice* device = nullptr;
  HRESULT hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  enumerator->Release();
  if (FAILED(hr)) {
    return nullptr;
  }
  IAudioEndpointVolume* volume = nullptr;
  hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void**>(&volume));
  device->Release();
  return SUCCEEDED(hr) ? volume : nullptr;
}

void HandleVolumeCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  IAudioEndpointVolume* volume = GetEndpointVolume();
  if (!volume) {
    result->Error("NO_DEVICE", "No default audio output device");
    return;
  }
  const std::string& method = call.method_name();
  if (method == "get") {
    // Muted counts as 0 so the alarm always unmutes by raising the volume.
    float level = 0;
    BOOL muted = FALSE;
    volume->GetMasterVolumeLevelScalar(&level);
    volume->GetMute(&muted);
    result->Success(flutter::EncodableValue(muted ? 0.0 : double{level}));
  } else if (method == "set") {
    const auto* level = std::get_if<double>(call.arguments());
    if (!level) {
      result->Error("BAD_ARGS", "Expected a double between 0 and 1");
    } else {
      volume->SetMute(FALSE, nullptr);
      volume->SetMasterVolumeLevelScalar(
          static_cast<float>(std::clamp(*level, 0.0, 1.0)), nullptr);
      result->Success();
    }
  } else {
    result->NotImplemented();
  }
  volume->Release();
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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  volume_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "nag_alarm/volume",
          &flutter::StandardMethodCodec::GetInstance());
  volume_channel_->SetMethodCallHandler(HandleVolumeCall);

  sound_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "nag_alarm/sound",
          &flutter::StandardMethodCodec::GetInstance());
  sound_channel_->SetMethodCallHandler(HandleSoundCall);

  // No Show() here: window_manager shows the window from Dart, so the app can
  // start hidden in the tray when launched at login.

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  volume_channel_ = nullptr;
  sound_channel_ = nullptr;
  PlaySoundW(nullptr, nullptr, 0);
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
