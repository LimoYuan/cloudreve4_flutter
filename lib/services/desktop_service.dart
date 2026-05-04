import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import '../config/app_config.dart';
import '../core/utils/app_logger.dart';

/// 桌面端服务（窗口管理 + 系统托盘）
class DesktopService with TrayListener, WindowListener {
  static DesktopService? _instance;
  DesktopService._();

  static DesktopService get instance {
    _instance ??= DesktopService._();
    return _instance!;
  }

  static bool get isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux;

  bool _initialized = false;

  /// 初始化桌面端服务，必须在 runApp 之前调用
  Future<void> initialize() async {
    if (!isDesktopPlatform || _initialized) return;

    // 窗口管理器
    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    await windowManager.setSize(const Size(1280, 720));
    await windowManager.setMinimumSize(const Size(400, 300));
    await windowManager.setTitle(AppConfig.appName);
    await windowManager.setPreventClose(true);

    // 托盘管理器
    trayManager.addListener(this);

    final iconPath = await _getTrayIconPath();
    AppLogger.d('DesktopService: tray icon path: $iconPath');
    await trayManager.setIcon(iconPath);
    
    try {
      await trayManager.setToolTip(AppConfig.appName);
    } catch (e) {
      AppLogger.e('DesktopService: tray icon error: $e');
    }

    final menu = Menu(items: [
      MenuItem(key: 'show', label: '显示主窗口'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]);
    await trayManager.setContextMenu(menu);

    _initialized = true;
    AppLogger.d('DesktopService initialized');
  }

  Future<String> _getTrayIconPath() async {
    if (Platform.isWindows) {
      // 获取当前可执行文件 (.exe) 所在的目录
      String exePath = Platform.resolvedExecutable;
      String exeDir = p.dirname(exePath);

      // 拼接 Windows 下 Flutter Assets 的标准物理路径
      // 注意：这里的路径必须与打包后的文件夹结构一致
      return p.join(exeDir, 'data', 'flutter_assets', 'assets/icons/tray_icon.ico');
    } else if (Platform.isLinux) {
      return '/opt/cloudreve4/data/flutter_assets/assets/icons/tray_icon.png';
    }
    // 调试模式下通常直接用 assets 路径
    return 'assets/icons/tray_icon.png';
  }

  // ========== TrayListener ==========

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'quit':
        _quitApp();
        break;
    }
  }

  // ========== WindowListener ==========

  @override
  void onWindowClose() async {
    AppLogger.d('DesktopService: onWindowClose -> hiding to tray');
    await windowManager.hide();
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  // ========== Private ==========

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    AppLogger.d('DesktopService: quitting app');
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await windowManager.destroy();
  }
}
