#ifndef RUNNER_FLOATING_UPLOAD_WINDOW_H_
#define RUNNER_FLOATING_UPLOAD_WINDOW_H_

#include <windows.h>
#include <objidl.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

class FloatingUploadWindow : public IDropTarget {
 public:
  explicit FloatingUploadWindow(
      flutter::MethodChannel<flutter::EncodableValue>* channel);
  ~FloatingUploadWindow();

  FloatingUploadWindow(const FloatingUploadWindow&) = delete;
  FloatingUploadWindow& operator=(const FloatingUploadWindow&) = delete;

  void SetEnabled(bool enabled);
  void ShowStatus(const std::wstring& message, bool is_error);
  void SetSiteIconPath(const std::wstring& path);

  // IUnknown / IDropTarget
  HRESULT __stdcall QueryInterface(REFIID riid, void** object) override;
  ULONG __stdcall AddRef() override;
  ULONG __stdcall Release() override;
  HRESULT __stdcall DragEnter(IDataObject* data_object,
                              DWORD key_state,
                              POINTL point,
                              DWORD* effect) override;
  HRESULT __stdcall DragOver(DWORD key_state,
                             POINTL point,
                             DWORD* effect) override;
  HRESULT __stdcall DragLeave() override;
  HRESULT __stdcall Drop(IDataObject* data_object,
                         DWORD key_state,
                         POINTL point,
                         DWORD* effect) override;

 private:
  static LRESULT CALLBACK WindowProc(HWND hwnd,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam);

  void CreateNativeWindow();
  void DestroyNativeWindow();
  void PositionWindow(bool resize_only = false);
  void Paint();
  void Render();
  void SetDragActive(bool active);
  void NotifyFilesDropped(const std::vector<std::wstring>& paths);
  std::vector<std::wstring> ExtractFiles(IDataObject* data_object);
  int CurrentWidth() const;
  int CurrentHeight() const;

  flutter::MethodChannel<flutter::EncodableValue>* channel_ = nullptr;
  HWND hwnd_ = nullptr;
  ULONG ref_count_ = 1;
  bool enabled_ = false;
  bool drag_active_ = false;
  bool ole_initialized_ = false;
  bool drop_registered_ = false;
  bool status_is_error_ = false;
  std::wstring status_message_;
  std::wstring site_icon_path_;
  ULONG_PTR gdiplus_token_ = 0;
};

#endif  // RUNNER_FLOATING_UPLOAD_WINDOW_H_
