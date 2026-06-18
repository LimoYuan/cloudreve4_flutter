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
constexpr int kWindowCornerRadius = 15;

// Compact Material 3 styled floating upload window.
constexpr int kNormalWidth = 224;
constexpr int kNormalHeight = 50;
constexpr int kStatusHeight = 98;
constexpr int kDragWidth = 272;
constexpr int kDragHeight = 136;
constexpr int kShrunkSize = 42;

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
}

void DrawFloatingText(Gdiplus::Graphics& graphics,
                      const wchar_t* text,
                      Gdiplus::Font& font,
                      const Gdiplus::RectF& rect,
                      const Gdiplus::Color& color,
                      Gdiplus::StringAlignment horizontal,
                      Gdiplus::StringAlignment vertical);

struct IconBrightness {
  bool valid = false;
  bool is_bright = false;
};

IconBrightness AnalyzeIconBrightness(Gdiplus::Bitmap* bitmap) {
  IconBrightness stats;
  if (!bitmap) return stats;
  const UINT w = bitmap->GetWidth();
  const UINT h = bitmap->GetHeight();
  if (w == 0 || h == 0) return stats;

  Gdiplus::Rect rect(0, 0, static_cast<INT>(w), static_cast<INT>(h));
  Gdiplus::BitmapData data{};
  if (bitmap->LockBits(&rect, Gdiplus::ImageLockModeRead,
                       PixelFormat32bppARGB, &data) != Gdiplus::Ok) {
    return stats;
  }

  uint64_t lum_sum = 0;
  uint32_t opaque_count = 0;
  uint8_t* base = static_cast<uint8_t*>(data.Scan0);
  for (UINT y = 0; y < h; ++y) {
    uint8_t* row = base + static_cast<INT>(y) * data.Stride;
    for (UINT x = 0; x < w; ++x) {
      uint8_t* px = row + x * 4;
      uint8_t b = px[0], g = px[1], r = px[2], a = px[3];
      if (a < 128) continue;
      uint32_t lum = (static_cast<uint32_t>(r) * 299 +
                     static_cast<uint32_t>(g) * 587 +
                     static_cast<uint32_t>(b) * 114) /
                     1000;
      lum_sum += lum;
      ++opaque_count;
    }
  }
  bitmap->UnlockBits(&data);

  if (opaque_count == 0) return stats;
  stats.valid = true;
  uint32_t avg_lum = static_cast<uint32_t>(lum_sum / opaque_count);
  stats.is_bright = avg_lum > 220;
  return stats;
}

void DrawSiteIconOrFallback(Gdiplus::Graphics& graphics,
                            const std::wstring& icon_path,
                            const Gdiplus::RectF& icon_rect,
                            Gdiplus::Font& fallback_font) {
  std::unique_ptr<Gdiplus::Bitmap> bitmap;
  if (!icon_path.empty() && PathFileExistsW(icon_path.c_str())) {
    std::unique_ptr<Gdiplus::Bitmap> from_file(
        Gdiplus::Bitmap::FromFile(icon_path.c_str(), FALSE));
    if (from_file && from_file->GetLastStatus() == Gdiplus::Ok &&
        from_file->GetWidth() > 0 && from_file->GetHeight() > 0) {
      bitmap = std::move(from_file);
    } else {
      HICON icon = static_cast<HICON>(
          LoadImageW(nullptr, icon_path.c_str(), IMAGE_ICON, 0, 0,
                     LR_LOADFROMFILE | LR_DEFAULTSIZE));
      if (icon != nullptr) {
        std::unique_ptr<Gdiplus::Bitmap> icon_bitmap(
            Gdiplus::Bitmap::FromHICON(icon));
        if (icon_bitmap && icon_bitmap->GetLastStatus() == Gdiplus::Ok &&
            icon_bitmap->GetWidth() > 0 && icon_bitmap->GetHeight() > 0) {
          bitmap = std::move(icon_bitmap);
        }
        DestroyIcon(icon);
      }
    }
  }

  if (!bitmap) {
    Gdiplus::LinearGradientBrush fallback_bg(
        icon_rect,
        Gdiplus::Color(255, 59, 130, 246),
        Gdiplus::Color(255, 29, 78, 216),
        Gdiplus::LinearGradientModeVertical);
    const float fallback_radius =
        (std::min)(icon_rect.Width, icon_rect.Height) / 2.0f;
    FillRoundedRect(graphics, fallback_bg, icon_rect, fallback_radius);
    DrawFloatingText(graphics, L"\u2601", fallback_font, icon_rect,
                     Gdiplus::Color(255, 255, 255, 255),
                     Gdiplus::StringAlignmentCenter,
                     Gdiplus::StringAlignmentCenter);
    return;
  }

  const auto stats = AnalyzeIconBrightness(bitmap.get());
  const Gdiplus::Color card_color = stats.is_bright
      ? Gdiplus::Color(255, 71, 85, 105)
      : Gdiplus::Color(255, 255, 255, 255);

  const float card_inset = 1.5f;
  Gdiplus::RectF card_rect(icon_rect.X + card_inset,
                           icon_rect.Y + card_inset,
                           icon_rect.Width - card_inset * 2.0f,
                           icon_rect.Height - card_inset * 2.0f);
  const float card_radius = card_rect.Width * 0.30f;

  Gdiplus::SolidBrush card_brush(card_color);
  FillRoundedRect(graphics, card_brush, card_rect, card_radius);

  Gdiplus::LinearGradientBrush border_brush(
      card_rect,
      Gdiplus::Color(255, 59, 130, 246),
      Gdiplus::Color(255, 29, 78, 216),
      Gdiplus::LinearGradientModeVertical);
  Gdiplus::Pen border_pen(&border_brush, 1.4f);
  DrawRoundedRect(graphics, border_pen, card_rect, card_radius);

  Gdiplus::RectF image_rect(icon_rect.X + 5.0f, icon_rect.Y + 5.0f,
                            icon_rect.Width - 10.0f,
                            icon_rect.Height - 10.0f);
  graphics.DrawImage(bitmap.get(), image_rect);
}

void DrawFloatingText(Gdiplus::Graphics& graphics,
              const wchar_t* text,
              Gdiplus::Font& font,
              const Gdiplus::RectF& rect,
              const Gdiplus::Color& color,
              Gdiplus::StringAlignment horizontal,
              Gdiplus::StringAlignment vertical) {
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

  for (int i = 5; i >= 1; --i) {
    float offset = static_cast<float>(i) * 0.8f;
    Gdiplus::RectF shadow_rect(2.0f, 2.0f + offset, width - 4.0f, main_height - 4.0f);
    BYTE alpha = static_cast<BYTE>(2 + i * 2);
    Gdiplus::SolidBrush shadow_brush(Gdiplus::Color(alpha, 15, 23, 42));
    FillRoundedRect(graphics, shadow_brush, shadow_rect, 15.0f);
  }

  Gdiplus::RectF outer(2.0f, 2.0f, width - 4.0f, main_height - 4.0f);
  Gdiplus::SolidBrush bg_brush(Gdiplus::Color(240, 248, 250, 252));
  FillRoundedRect(graphics, bg_brush, outer, 15.0f);

  Gdiplus::LinearGradientBrush border_brush(
      outer,
      Gdiplus::Color(140, 59, 130, 246),
      Gdiplus::Color(35, 37, 99, 235),
      Gdiplus::LinearGradientModeVertical);
  Gdiplus::Pen border_pen(&border_brush, 1.0f);
  DrawRoundedRect(graphics, border_pen, outer, 15.0f);

  float icon_sz = main_height - 14.0f;
  Gdiplus::RectF icon_block(9.0f, 7.0f, icon_sz, icon_sz);

  DrawSiteIconOrFallback(graphics, site_icon_path, icon_block, cloud_font);

  Gdiplus::RectF title_rect(15.0f + icon_sz + 10.0f, 0.0f, width - (15.0f + icon_sz + 20.0f), main_height);
  DrawFloatingText(graphics, L"\u62D6\u62FD\u6B64\u5904\u4E0A\u4F20", title_font,
                   title_rect, Gdiplus::Color(255, 30, 41, 59),
                   Gdiplus::StringAlignmentNear, Gdiplus::StringAlignmentCenter);
}

void DrawWindowContent(Gdiplus::Graphics& graphics,
                       float width,
                       float height,
                       float drag_progress,
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
  Gdiplus::Font title_font(&yahei, 14.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::Font cloud_font(&segoe, 18.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::Font drag_font(&yahei, 15.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::Font status_font(&yahei, 12.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);

  // Independent rendering logic for the shrunk icon state
  if (width <= 45.0f) {
    Gdiplus::RectF icon_block(2.0f, 2.0f, width - 4.0f, height - 4.0f);
    DrawSiteIconOrFallback(graphics, site_icon_path, icon_block, cloud_font);
    return;
  }

  DrawMainPill(graphics, width, site_icon_path, title_font, cloud_font);

  if (drag_progress > 0.0f) {
    const float panel_top = static_cast<float>(kNormalHeight) + 6.0f;
    Gdiplus::RectF drag_rect(8.0f, panel_top, width - 16.0f, height - panel_top - 8.0f);

    BYTE bg_alpha = static_cast<BYTE>(248 * drag_progress);
    BYTE border_alpha = static_cast<BYTE>(210 * drag_progress);
    BYTE text_alpha = static_cast<BYTE>(255 * drag_progress);

    Gdiplus::SolidBrush drag_fill(Gdiplus::Color(bg_alpha, 248, 248, 252));
    Gdiplus::Pen drag_pen(Gdiplus::Color(border_alpha, 59, 130, 246), 1.25f);
    drag_pen.SetDashStyle(Gdiplus::DashStyleDash);
    FillRoundedRect(graphics, drag_fill, drag_rect, 13.0f);
    DrawRoundedRect(graphics, drag_pen, drag_rect, 13.0f);

    Gdiplus::RectF drag_icon(20.0f, panel_top + 15.0f, 34.0f, 34.0f);
    Gdiplus::LinearGradientBrush drag_icon_brush(
        drag_icon, Gdiplus::Color(text_alpha, 59, 130, 246),
        Gdiplus::Color(text_alpha, 37, 99, 235),
        Gdiplus::LinearGradientModeVertical);
    FillRoundedRect(graphics, drag_icon_brush, drag_icon, 9.0f);
    DrawFloatingText(graphics, L"\u21E3", cloud_font, drag_icon,
             Gdiplus::Color(text_alpha, 255, 255, 255),
             Gdiplus::StringAlignmentCenter, Gdiplus::StringAlignmentCenter);

    Gdiplus::RectF drag_text(66.0f, panel_top + 11.0f, width - 78.0f, 42.0f);
    DrawFloatingText(graphics, L"\u677E\u5F00\u4E0A\u4F20\u6587\u4EF6", drag_font,
             drag_text, Gdiplus::Color(text_alpha, 29, 78, 216),
             Gdiplus::StringAlignmentNear, Gdiplus::StringAlignmentCenter);
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
                             : Gdiplus::Color(255, 37, 99, 235),
             Gdiplus::StringAlignmentNear, Gdiplus::StringAlignmentCenter);
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
  if (is_shrunk_) {
    return kShrunkSize;
  }
  return drag_active_ ? kDragWidth : kNormalWidth;
}

int FloatingUploadWindow::CurrentHeight() const {
  if (is_shrunk_) {
    return kShrunkSize;
  }
  int start_h = status_message_.empty() ? kNormalHeight : kStatusHeight;
  int end_h = kDragHeight;
  return start_h + static_cast<int>((end_h - start_h) * drag_alpha_progress_);
}

void FloatingUploadWindow::SetDragActive(bool active) {
  if (is_shrunk_) {
    return; // Don't animate expand states when shrunk
  }
  if (drag_active_ == active) {
    return;
  }
  drag_active_ = active;
  SetTimer(hwnd_, kAnimTimerId, 16, nullptr);
}

void FloatingUploadWindow::UpdateAnimation() {
  constexpr float kSpeed = 0.12f;
  bool anim_done = false;

  if (drag_active_) {
    drag_alpha_progress_ += kSpeed;
    if (drag_alpha_progress_ >= 1.0f) {
      drag_alpha_progress_ = 1.0f;
      anim_done = true;
    }
  } else {
    drag_alpha_progress_ -= kSpeed;
    if (drag_alpha_progress_ <= 0.0f) {
      drag_alpha_progress_ = 0.0f;
      anim_done = true;
    }
  }

  if (anim_done) {
    KillTimer(hwnd_, kAnimTimerId);
  }

  PositionWindow(true);
  Render();
}

void FloatingUploadWindow::ShowContextMenu(HWND hwnd, int x, int y) {
  HMENU hMenu = CreatePopupMenu();
  if (hMenu) {
    InsertMenuW(hMenu, 0, MF_BYPOSITION | MF_STRING, 1001, L"隐藏悬浮窗");
    SetForegroundWindow(hwnd);
    TrackPopupMenu(hMenu, TPM_LEFTALIGN | TPM_RIGHTBUTTON, x, y, 0, hwnd, nullptr);
    DestroyMenu(hMenu);
  }
}

void FloatingUploadWindow::CheckScreenEdges() {
  if (hwnd_ == nullptr) return;

  RECT win_rect;
  GetWindowRect(hwnd_, &win_rect);

  HMONITOR monitor = MonitorFromWindow(hwnd_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfoW(monitor, &monitor_info);
  RECT work_area = monitor_info.rcWork;

  constexpr int kEdgeThreshold = 35;
  bool should_shrink = false;
  int new_x = win_rect.left;
  int new_y = win_rect.top;

  if (win_rect.left - work_area.left < kEdgeThreshold) {
    new_x = work_area.left;
    should_shrink = true;
  }
  else if (work_area.right - win_rect.right < kEdgeThreshold) {
    new_x = work_area.right - kShrunkSize;
    should_shrink = true;
  }

  if (win_rect.top - work_area.top < kEdgeThreshold) {
    new_y = work_area.top;
    should_shrink = true;
  }
  else if (work_area.bottom - win_rect.bottom < kEdgeThreshold) {
    new_y = work_area.bottom - kShrunkSize;
    should_shrink = true;
  }

  if (should_shrink) {
    if (!is_shrunk_) {
      pre_shrink_x_ = win_rect.left;
      pre_shrink_y_ = win_rect.top;
      is_shrunk_ = true;
    }
    SetWindowPos(hwnd_, HWND_TOPMOST, new_x, new_y, kShrunkSize, kShrunkSize, SWP_NOACTIVATE);
    Render();
  }
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
                      static_cast<float>(height), drag_alpha_progress_,
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
  DrawWindowContent(graphics, width, height, drag_alpha_progress_, status_message_,
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
    case WM_EXITSIZEMOVE:
      if (self != nullptr) {
        self->CheckScreenEdges();
      }
      break;
    case WM_PAINT:
      if (self != nullptr) {
        self->Paint();
        return 0;
      }
      break;
    case WM_LBUTTONDOWN:
      if (self != nullptr) {
        if (self->is_shrunk_) {
          self->is_shrunk_ = false;

          HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
          MONITORINFO mi{};
          mi.cbSize = sizeof(MONITORINFO);
          GetMonitorInfoW(monitor, &mi);

          int restored_x = self->pre_shrink_x_;
          int restored_y = self->pre_shrink_y_;
          int normal_w = self->CurrentWidth();

          if (restored_x + normal_w > mi.rcWork.right) {
            restored_x = mi.rcWork.right - normal_w - 10;
          }
          if (restored_x < mi.rcWork.left) {
            restored_x = mi.rcWork.left + 10;
          }

          SetWindowPos(hwnd, HWND_TOPMOST, restored_x, restored_y,
                       normal_w, self->CurrentHeight(), SWP_NOACTIVATE);
          self->Render();
          return 0;
        }

        ReleaseCapture();
        SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
        self->CheckScreenEdges();
      }
      return 0;
    case WM_RBUTTONUP:
      if (self != nullptr) {
        POINT pt;
        GetCursorPos(&pt);
        self->ShowContextMenu(hwnd, pt.x, pt.y);
        return 0;
      }
      break;
    case WM_COMMAND:
      if (self != nullptr && LOWORD(wparam) == 1001) {
        self->SetEnabled(false);
        return 0;
      }
      break;
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
      if (self != nullptr) {
        if (wparam == kStatusTimerId) {
          KillTimer(hwnd, kStatusTimerId);
          self->status_message_.clear();
          self->PositionWindow(true);
          self->Render();
          return 0;
        } else if (wparam == kAnimTimerId) {
          self->UpdateAnimation();
          return 0;
        }
      }
      break;
    case WM_ERASEBKGND:
      return 1;
    default:
      break;
  }

  return DefWindowProcW(hwnd, message, wparam, lparam);
}