#include "floating_upload_window.h"

#include <shellapi.h>
#include <gdiplus.h>
#include <shlwapi.h>

#ifdef DrawText
#undef DrawText
#endif

#include <memory>
#include <string>
#include <vector>

namespace {

constexpr const wchar_t kFloatingUploadClassName[] =
    L"CloudreveFloatingUploadWindow";
constexpr UINT_PTR kStatusTimerId = 8101;
constexpr int kWindowCornerRadius = 15;

// Compact Material 3 styled floating upload window.
// Use the app seed color (#3B82F6) and the app light surface (#F8FAFC)
// instead of the older high-saturation cyan/glow style.
constexpr int kNormalWidth = 224;
constexpr int kNormalHeight = 50;
constexpr int kStatusHeight = 98;
constexpr int kDragWidth = 272;
constexpr int kDragHeight = 136;

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }

  const int length = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1,
                                         nullptr, 0, nullptr, nullptr);
  if (length <= 0) {
    return std::string();
  }

  std::string result(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), length,
                      nullptr, nullptr);
  if (!result.empty() && result.back() == '\0') {
    result.pop_back();
  }
  return result;
}

void AddRoundedRect(Gdiplus::GraphicsPath& path,
                    const Gdiplus::RectF& rect,
                    float radius) {
  const float diameter = radius * 2.0f;
  path.AddArc(rect.X, rect.Y, diameter, diameter, 180.0f, 90.0f);
  path.AddArc(rect.X + rect.Width - diameter, rect.Y, diameter, diameter,
              270.0f, 90.0f);
  path.AddArc(rect.X + rect.Width - diameter, rect.Y + rect.Height - diameter,
              diameter, diameter, 0.0f, 90.0f);
  path.AddArc(rect.X, rect.Y + rect.Height - diameter, diameter, diameter,
              90.0f, 90.0f);
  path.CloseFigure();
}

void FillRoundedRect(Gdiplus::Graphics& graphics,
                     Gdiplus::Brush& brush,
                     const Gdiplus::RectF& rect,
                     float radius) {
  Gdiplus::GraphicsPath path;
  AddRoundedRect(path, rect, radius);
  graphics.FillPath(&brush, &path);
}

void DrawRoundedRect(Gdiplus::Graphics& graphics,
                     Gdiplus::Pen& pen,
                     const Gdiplus::RectF& rect,
                     float radius) {
  Gdiplus::GraphicsPath path;
  AddRoundedRect(path, rect, radius);
  graphics.DrawPath(&pen, &path);
}

void ApplyRoundedWindowRegion(HWND hwnd, int width, int height) {
  (void)hwnd;
  (void)width;
  (void)height;
  // Keep the layered window fully rectangular at the Win32 region level.
  // Rounded corners are rendered with per-pixel alpha in Render(), which avoids
  // the jagged clipping artifacts caused by CreateRoundRectRgn.
}


void DrawFloatingText(Gdiplus::Graphics& graphics,
                      const wchar_t* text,
                      Gdiplus::Font& font,
                      const Gdiplus::RectF& rect,
                      const Gdiplus::Color& color,
                      Gdiplus::StringAlignment horizontal,
                      Gdiplus::StringAlignment vertical);

void DrawSiteIconOrFallback(Gdiplus::Graphics& graphics,
                            const std::wstring& icon_path,
                            const Gdiplus::RectF& icon_rect,
                            Gdiplus::Font& fallback_font) {
  bool drawn = false;
  if (!icon_path.empty() && PathFileExistsW(icon_path.c_str())) {
    std::unique_ptr<Gdiplus::Bitmap> bitmap(
        Gdiplus::Bitmap::FromFile(icon_path.c_str(), FALSE));
    if (bitmap && bitmap->GetLastStatus() == Gdiplus::Ok &&
        bitmap->GetWidth() > 0 && bitmap->GetHeight() > 0) {
      Gdiplus::RectF image_rect(icon_rect.X + 10.0f, icon_rect.Y + 10.0f,
                                icon_rect.Width - 20.0f,
                                icon_rect.Height - 20.0f);
      graphics.DrawImage(bitmap.get(), image_rect);
      drawn = true;
    }

    if (!drawn) {
      HICON icon = static_cast<HICON>(
          LoadImageW(nullptr, icon_path.c_str(), IMAGE_ICON, 0, 0,
                     LR_LOADFROMFILE | LR_DEFAULTSIZE));
      if (icon != nullptr) {
        std::unique_ptr<Gdiplus::Bitmap> icon_bitmap(
            Gdiplus::Bitmap::FromHICON(icon));
        if (icon_bitmap && icon_bitmap->GetLastStatus() == Gdiplus::Ok &&
            icon_bitmap->GetWidth() > 0 && icon_bitmap->GetHeight() > 0) {
          Gdiplus::RectF image_rect(icon_rect.X + 10.0f, icon_rect.Y + 10.0f,
                                    icon_rect.Width - 20.0f,
                                    icon_rect.Height - 20.0f);
          graphics.DrawImage(icon_bitmap.get(), image_rect);
          drawn = true;
        }
        DestroyIcon(icon);
      }
    }
  }

  if (!drawn) {
    DrawFloatingText(graphics, L"\u2601", fallback_font, icon_rect,
             Gdiplus::Color(255, 255, 255, 255),
             Gdiplus::StringAlignmentCenter,
             Gdiplus::StringAlignmentCenter);
  }
}

void DrawFloatingText(Gdiplus::Graphics& graphics,
              const wchar_t* text,
              Gdiplus::Font& font,
              const Gdiplus::RectF& rect,
              const Gdiplus::Color& color,
              Gdiplus::StringAlignment horizontal =
                  Gdiplus::StringAlignmentNear,
              Gdiplus::StringAlignment vertical =
                  Gdiplus::StringAlignmentCenter) {
  Gdiplus::SolidBrush brush(color);
  Gdiplus::StringFormat format;
  format.SetAlignment(horizontal);
  format.SetLineAlignment(vertical);
  format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
  format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
  graphics.DrawString(text, -1, &font, rect, &format, &brush);
}

void DrawMainPill(Gdiplus::Graphics& graphics,
                  float width,
                  const std::wstring& site_icon_path,
                  Gdiplus::Font& title_font,
                  Gdiplus::Font& cloud_font) {
  constexpr float main_height = static_cast<float>(kNormalHeight);

  // A very small transparent shadow gives separation without the previous glow.
  Gdiplus::RectF shadow_rect(3.0f, 4.0f, width - 6.0f, main_height - 7.0f);
  for (int i = 3; i >= 1; --i) {
    const BYTE alpha = static_cast<BYTE>(9 * i);
    Gdiplus::Pen shadow_pen(Gdiplus::Color(alpha, 15, 23, 42),
                            static_cast<Gdiplus::REAL>(i));
    DrawRoundedRect(graphics, shadow_pen, shadow_rect, 14.0f);
  }

  // Main app surface: close to ThemeProvider.lightScaffoldBg (#F8FAFC),
  // with a restrained blue border from the Material 3 seed color (#3B82F6).
  Gdiplus::RectF outer(2.0f, 1.8f, width - 4.0f, main_height - 4.0f);
  Gdiplus::LinearGradientBrush outer_brush(
      outer, Gdiplus::Color(255, 255, 255, 255),
      Gdiplus::Color(255, 241, 247, 255),
      Gdiplus::LinearGradientModeVertical);
  Gdiplus::Pen outer_pen(Gdiplus::Color(235, 59, 130, 246), 1.15f);
  Gdiplus::Pen inner_pen(Gdiplus::Color(170, 255, 255, 255), 0.75f);
  FillRoundedRect(graphics, outer_brush, outer, 14.0f);
  DrawRoundedRect(graphics, outer_pen, outer, 14.0f);

  Gdiplus::RectF inner(3.4f, 3.1f, width - 6.8f, main_height - 6.6f);
  DrawRoundedRect(graphics, inner_pen, inner, 12.8f);

  // Compact primary block. It deliberately uses the app blue palette instead of
  // the old bright cyan, making the floating window match the main UI.
  Gdiplus::RectF icon_block(4.2f, 4.0f, 43.0f, main_height - 8.0f);
  Gdiplus::LinearGradientBrush icon_brush(
      icon_block, Gdiplus::Color(255, 59, 130, 246),
      Gdiplus::Color(255, 37, 99, 235),
      Gdiplus::LinearGradientModeVertical);
  FillRoundedRect(graphics, icon_brush, icon_block, 11.0f);

  Gdiplus::Pen icon_inner_pen(Gdiplus::Color(80, 255, 255, 255), 0.75f);
  Gdiplus::RectF icon_inner(icon_block.X + 1.0f, icon_block.Y + 1.0f,
                            icon_block.Width - 2.0f,
                            icon_block.Height - 2.0f);
  DrawRoundedRect(graphics, icon_inner_pen, icon_inner, 10.0f);

  DrawSiteIconOrFallback(graphics, site_icon_path, icon_block, cloud_font);

  Gdiplus::Pen divider_pen(Gdiplus::Color(95, 147, 197, 253), 0.8f);
  graphics.DrawLine(&divider_pen, 55.0f, 12.0f, 55.0f, main_height - 12.0f);

  Gdiplus::RectF title_rect(63.0f, 0.0f, width - 70.0f, main_height);
  DrawFloatingText(graphics, L"\u62D6\u62FD\u6B64\u5904\u4E0A\u4F20", title_font,
           title_rect, Gdiplus::Color(255, 29, 78, 216));
}

void DrawWindowContent(Gdiplus::Graphics& graphics,
                       float width,
                       float height,
                       bool drag_active,
                       const std::wstring& status_message,
                       bool status_is_error,
                       const std::wstring& site_icon_path) {
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
  graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
  graphics.SetCompositingQuality(Gdiplus::CompositingQualityHighQuality);
  graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));

  Gdiplus::FontFamily yahei(L"Microsoft YaHei UI");
  Gdiplus::FontFamily segoe(L"Segoe UI Symbol");
  Gdiplus::Font title_font(&yahei, 18.0f, Gdiplus::FontStyleBold,
                           Gdiplus::UnitPixel);
  Gdiplus::Font cloud_font(&segoe, 25.0f, Gdiplus::FontStyleBold,
                           Gdiplus::UnitPixel);
  Gdiplus::Font drag_font(&yahei, 17.0f, Gdiplus::FontStyleBold,
                          Gdiplus::UnitPixel);
  Gdiplus::Font status_font(&yahei, 12.5f, Gdiplus::FontStyleBold,
                            Gdiplus::UnitPixel);

  DrawMainPill(graphics, width, site_icon_path, title_font, cloud_font);

  if (drag_active) {
    const float panel_top = static_cast<float>(kNormalHeight) + 6.0f;
    Gdiplus::RectF drag_rect(8.0f, panel_top, width - 16.0f,
                             height - panel_top - 8.0f);
    Gdiplus::SolidBrush drag_fill(Gdiplus::Color(248, 248, 250, 252));
    Gdiplus::Pen drag_pen(Gdiplus::Color(210, 59, 130, 246), 1.25f);
    drag_pen.SetDashStyle(Gdiplus::DashStyleDash);
    FillRoundedRect(graphics, drag_fill, drag_rect, 13.0f);
    DrawRoundedRect(graphics, drag_pen, drag_rect, 13.0f);

    Gdiplus::RectF drag_icon(20.0f, panel_top + 15.0f, 34.0f, 34.0f);
    Gdiplus::LinearGradientBrush drag_icon_brush(
        drag_icon, Gdiplus::Color(255, 59, 130, 246),
        Gdiplus::Color(255, 37, 99, 235),
        Gdiplus::LinearGradientModeVertical);
    FillRoundedRect(graphics, drag_icon_brush, drag_icon, 9.0f);
    DrawFloatingText(graphics, L"\u21E3", cloud_font, drag_icon,
             Gdiplus::Color(255, 255, 255, 255),
             Gdiplus::StringAlignmentCenter);

    Gdiplus::RectF drag_text(66.0f, panel_top + 11.0f, width - 78.0f, 42.0f);
    DrawFloatingText(graphics, L"\u677E\u5F00\u4E0A\u4F20\u6587\u4EF6", drag_font,
             drag_text, Gdiplus::Color(255, 29, 78, 216));
  } else if (!status_message.empty()) {
    const float panel_top = static_cast<float>(kNormalHeight) + 5.0f;
    Gdiplus::RectF status_rect(8.0f, panel_top, width - 16.0f,
                               height - panel_top - 7.0f);
    Gdiplus::SolidBrush status_fill(
        status_is_error ? Gdiplus::Color(248, 255, 241, 242)
                        : Gdiplus::Color(248, 239, 246, 255));
    Gdiplus::Pen status_pen(
        status_is_error ? Gdiplus::Color(210, 248, 113, 113)
                        : Gdiplus::Color(210, 59, 130, 246),
        1.0f);
    FillRoundedRect(graphics, status_fill, status_rect, 12.0f);
    DrawRoundedRect(graphics, status_pen, status_rect, 12.0f);

    Gdiplus::RectF status_text(16.0f, panel_top + 1.0f, width - 32.0f,
                               height - panel_top - 10.0f);
    DrawFloatingText(graphics, status_message.c_str(), status_font, status_text,
             status_is_error ? Gdiplus::Color(255, 185, 28, 28)
                             : Gdiplus::Color(255, 37, 99, 235));
  }
}

}  // namespace

FloatingUploadWindow::FloatingUploadWindow(
    flutter::MethodChannel<flutter::EncodableValue>* channel)
    : channel_(channel) {
  Gdiplus::GdiplusStartupInput gdiplus_input;
  Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplus_input, nullptr);

  HRESULT hr = OleInitialize(nullptr);
  ole_initialized_ = SUCCEEDED(hr);
}

FloatingUploadWindow::~FloatingUploadWindow() {
  DestroyNativeWindow();
  if (ole_initialized_) {
    OleUninitialize();
    ole_initialized_ = false;
  }
  if (gdiplus_token_ != 0) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_token_ = 0;
  }
}

void FloatingUploadWindow::SetEnabled(bool enabled) {
  enabled_ = enabled;
  if (!enabled_) {
    if (hwnd_ != nullptr) {
      ShowWindow(hwnd_, SW_HIDE);
    }
    return;
  }

  CreateNativeWindow();
  if (hwnd_ != nullptr) {
    PositionWindow();
    Render();
    ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    DragAcceptFiles(hwnd_, TRUE);
    ChangeWindowMessageFilterEx(hwnd_, WM_DROPFILES, MSGFLT_ALLOW, nullptr);
    ChangeWindowMessageFilterEx(hwnd_, WM_COPYDATA, MSGFLT_ALLOW, nullptr);
    ChangeWindowMessageFilterEx(hwnd_, 0x0049, MSGFLT_ALLOW, nullptr);
    if (ole_initialized_ && !drop_registered_) {
      HRESULT hr = RegisterDragDrop(hwnd_, this);
      drop_registered_ = SUCCEEDED(hr);
    }
    SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
}

void FloatingUploadWindow::ShowStatus(const std::wstring& message,
                                      bool is_error) {
  if (!enabled_) {
    return;
  }

  CreateNativeWindow();
  status_message_ = message;
  status_is_error_ = is_error;
  PositionWindow(true);
  Render();
  SetTimer(hwnd_, kStatusTimerId, 4200, nullptr);

  ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
  SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void FloatingUploadWindow::SetSiteIconPath(const std::wstring& path) {
  site_icon_path_ = path;
  if (hwnd_ != nullptr) {
    Render();
  }
}


HRESULT FloatingUploadWindow::QueryInterface(REFIID riid, void** object) {
  if (object == nullptr) {
    return E_POINTER;
  }

  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *object = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }

  *object = nullptr;
  return E_NOINTERFACE;
}

ULONG FloatingUploadWindow::AddRef() {
  return InterlockedIncrement(reinterpret_cast<volatile LONG*>(&ref_count_));
}

ULONG FloatingUploadWindow::Release() {
  return InterlockedDecrement(reinterpret_cast<volatile LONG*>(&ref_count_));
}

HRESULT FloatingUploadWindow::DragEnter(IDataObject* data_object,
                                        DWORD key_state,
                                        POINTL point,
                                        DWORD* effect) {
  (void)data_object;
  (void)key_state;
  (void)point;
  SetDragActive(true);
  if (effect != nullptr) {
    *effect = DROPEFFECT_COPY;
  }
  return S_OK;
}

HRESULT FloatingUploadWindow::DragOver(DWORD key_state,
                                       POINTL point,
                                       DWORD* effect) {
  (void)key_state;
  (void)point;
  if (effect != nullptr) {
    *effect = DROPEFFECT_COPY;
  }
  return S_OK;
}

HRESULT FloatingUploadWindow::DragLeave() {
  SetDragActive(false);
  return S_OK;
}

HRESULT FloatingUploadWindow::Drop(IDataObject* data_object,
                                   DWORD key_state,
                                   POINTL point,
                                   DWORD* effect) {
  (void)key_state;
  (void)point;

  std::vector<std::wstring> files = ExtractFiles(data_object);
  SetDragActive(false);
  if (effect != nullptr) {
    *effect = DROPEFFECT_COPY;
  }
  NotifyFilesDropped(files);
  if (!files.empty()) {
    ShowStatus(L"已接收文件，正在上传", false);
  }
  return S_OK;
}

void FloatingUploadWindow::CreateNativeWindow() {
  if (hwnd_ != nullptr) {
    return;
  }

  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kFloatingUploadClassName;
  window_class.lpfnWndProc = FloatingUploadWindow::WindowProc;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.hbrBackground = nullptr;
  RegisterClassExW(&window_class);

  hwnd_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_ACCEPTFILES,
      kFloatingUploadClassName, L"", WS_POPUP, CW_USEDEFAULT, CW_USEDEFAULT,
      CurrentWidth(), CurrentHeight(), nullptr, nullptr, GetModuleHandle(nullptr),
      this);

  if (hwnd_ == nullptr) {
    return;
  }

  DragAcceptFiles(hwnd_, TRUE);
  ChangeWindowMessageFilterEx(hwnd_, WM_DROPFILES, MSGFLT_ALLOW, nullptr);
  ChangeWindowMessageFilterEx(hwnd_, WM_COPYDATA, MSGFLT_ALLOW, nullptr);
  ChangeWindowMessageFilterEx(hwnd_, 0x0049, MSGFLT_ALLOW, nullptr);
  PositionWindow();
  Render();

  if (ole_initialized_) {
    HRESULT hr = RegisterDragDrop(hwnd_, this);
    drop_registered_ = SUCCEEDED(hr);
  }
}

void FloatingUploadWindow::DestroyNativeWindow() {
  if (hwnd_ != nullptr) {
    DragAcceptFiles(hwnd_, FALSE);
    if (drop_registered_) {
      RevokeDragDrop(hwnd_);
      drop_registered_ = false;
    }
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }
}

void FloatingUploadWindow::PositionWindow(bool resize_only) {
  if (hwnd_ == nullptr) {
    return;
  }

  const int width = CurrentWidth();
  const int height = CurrentHeight();

  if (resize_only) {
    SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, width, height,
                 SWP_NOMOVE | SWP_NOACTIVATE);
    ApplyRoundedWindowRegion(hwnd_, width, height);
    return;
  }

  RECT work_area{};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);

  const int x = work_area.right - width - 42;
  const int y = work_area.top + 118;
  SetWindowPos(hwnd_, HWND_TOPMOST, x, y, width, height, SWP_NOACTIVATE);
  ApplyRoundedWindowRegion(hwnd_, width, height);
}

int FloatingUploadWindow::CurrentWidth() const {
  return drag_active_ ? kDragWidth : kNormalWidth;
}

int FloatingUploadWindow::CurrentHeight() const {
  if (drag_active_) {
    return kDragHeight;
  }
  return status_message_.empty() ? kNormalHeight : kStatusHeight;
}

void FloatingUploadWindow::SetDragActive(bool active) {
  if (drag_active_ == active) {
    return;
  }

  drag_active_ = active;
  PositionWindow(true);
  Render();
}

std::vector<std::wstring> FloatingUploadWindow::ExtractFiles(
    IDataObject* data_object) {
  std::vector<std::wstring> files;
  if (data_object == nullptr) {
    return files;
  }

  FORMATETC format{};
  format.cfFormat = CF_HDROP;
  format.ptd = nullptr;
  format.dwAspect = DVASPECT_CONTENT;
  format.lindex = -1;
  format.tymed = TYMED_HGLOBAL;

  STGMEDIUM medium{};
  HRESULT hr = data_object->GetData(&format, &medium);
  if (FAILED(hr)) {
    return files;
  }

  HDROP drop = static_cast<HDROP>(GlobalLock(medium.hGlobal));
  if (drop != nullptr) {
    UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    for (UINT i = 0; i < count; ++i) {
      UINT length = DragQueryFileW(drop, i, nullptr, 0);
      std::wstring path(length, L'\0');
      if (DragQueryFileW(drop, i, path.data(), length + 1) > 0) {
        files.push_back(path);
      }
    }
    GlobalUnlock(medium.hGlobal);
  }

  ReleaseStgMedium(&medium);
  return files;
}

void FloatingUploadWindow::NotifyFilesDropped(
    const std::vector<std::wstring>& paths) {
  if (channel_ == nullptr || paths.empty()) {
    return;
  }

  flutter::EncodableList list;
  for (const auto& path : paths) {
    list.emplace_back(WideToUtf8(path));
  }

  channel_->InvokeMethod("onFilesDropped",
                         std::make_unique<flutter::EncodableValue>(list));
}

void FloatingUploadWindow::Render() {
  if (hwnd_ == nullptr) {
    return;
  }

  const int width = CurrentWidth();
  const int height = CurrentHeight();

  HDC screen_dc = GetDC(nullptr);
  if (screen_dc == nullptr) {
    InvalidateRect(hwnd_, nullptr, TRUE);
    UpdateWindow(hwnd_);
    return;
  }

  HDC memory_dc = CreateCompatibleDC(screen_dc);
  if (memory_dc == nullptr) {
    ReleaseDC(nullptr, screen_dc);
    InvalidateRect(hwnd_, nullptr, TRUE);
    UpdateWindow(hwnd_);
    return;
  }

  BITMAPINFO bitmap_info{};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP bitmap = CreateDIBSection(screen_dc, &bitmap_info, DIB_RGB_COLORS,
                                    &bits, nullptr, 0);
  if (bitmap == nullptr) {
    DeleteDC(memory_dc);
    ReleaseDC(nullptr, screen_dc);
    InvalidateRect(hwnd_, nullptr, TRUE);
    UpdateWindow(hwnd_);
    return;
  }

  HGDIOBJ old_bitmap = SelectObject(memory_dc, bitmap);
  {
    Gdiplus::Graphics graphics(memory_dc);
    DrawWindowContent(graphics, static_cast<float>(width),
                      static_cast<float>(height), drag_active_,
                      status_message_, status_is_error_, site_icon_path_);
  }

  RECT window_rect{};
  GetWindowRect(hwnd_, &window_rect);
  POINT dst_point{window_rect.left, window_rect.top};
  POINT src_point{0, 0};
  SIZE size{width, height};
  BLENDFUNCTION blend{};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;

  UpdateLayeredWindow(hwnd_, screen_dc, &dst_point, &size, memory_dc,
                      &src_point, 0, &blend, ULW_ALPHA);

  SelectObject(memory_dc, old_bitmap);
  DeleteObject(bitmap);
  DeleteDC(memory_dc);
  ReleaseDC(nullptr, screen_dc);
}

void FloatingUploadWindow::Paint() {
  PAINTSTRUCT ps{};
  HDC hdc = BeginPaint(hwnd_, &ps);
  if (hdc == nullptr) {
    return;
  }

  RECT client{};
  GetClientRect(hwnd_, &client);
  const float width = static_cast<float>(client.right - client.left);
  const float height = static_cast<float>(client.bottom - client.top);

  Gdiplus::Graphics graphics(hdc);
  DrawWindowContent(graphics, width, height, drag_active_, status_message_,
                    status_is_error_, site_icon_path_);

  EndPaint(hwnd_, &ps);
}

LRESULT CALLBACK FloatingUploadWindow::WindowProc(HWND hwnd,
                                                  UINT message,
                                                  WPARAM wparam,
                                                  LPARAM lparam) {
  FloatingUploadWindow* self =
      reinterpret_cast<FloatingUploadWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

  if (message == WM_NCCREATE) {
    CREATESTRUCTW* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
    self = reinterpret_cast<FloatingUploadWindow*>(create_struct->lpCreateParams);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  }

  switch (message) {
    case WM_PAINT:
      if (self != nullptr) {
        self->Paint();
        return 0;
      }
      break;
    case WM_LBUTTONDOWN:
      ReleaseCapture();
      SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
      return 0;
    case WM_DROPFILES:
      if (self != nullptr) {
        HDROP drop = reinterpret_cast<HDROP>(wparam);
        std::vector<std::wstring> files;
        const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
        for (UINT i = 0; i < count; ++i) {
          const UINT length = DragQueryFileW(drop, i, nullptr, 0);
          std::wstring path(length, L'\0');
          if (DragQueryFileW(drop, i, path.data(), length + 1) > 0) {
            files.push_back(path);
          }
        }
        DragFinish(drop);
        self->SetDragActive(false);
        self->NotifyFilesDropped(files);
        if (!files.empty()) {
          self->ShowStatus(L"已接收文件，正在上传", false);
        }
        return 0;
      }
      break;
    case WM_TIMER:
      if (self != nullptr && wparam == kStatusTimerId) {
        KillTimer(hwnd, kStatusTimerId);
        self->status_message_.clear();
        self->PositionWindow(true);
        self->Render();
        return 0;
      }
      break;
    case WM_ERASEBKGND:
      return 1;
    default:
      break;
  }

  return DefWindowProcW(hwnd, message, wparam, lparam);
}
