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

    // 1. 初始化窗口管理器
    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    // 2. 窗口选项设置
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    // 3. 等待窗口准备就绪后执行居中和显示
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setTitle(AppConfig.appName);
      await windowManager.setMinimumSize(const Size(400, 300));
      await windowManager.setPreventClose(true);

      // 如果设置了 center: true 仍未生效（某些 Linux 环境），可以手动补刀：
      // await windowManager.center();

      await windowManager.show();
      await windowManager.focus();
    });

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
    showWindow();
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
        showWindow();
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

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    try {
      AppLogger.d('DesktopService: Cleaning up before exit...');

      // 彻底解绑
      windowManager.removeListener(this);
      trayManager.removeListener(this);

      // 彻底销毁托盘（防止残留僵尸图标）
      await trayManager.destroy();

      // 允许关闭并销毁窗口
      await windowManager.setPreventClose(false);

      // 给系统一点点时间（50ms）处理最后的事件队列
      await Future.delayed(const Duration(milliseconds: 50));

      await windowManager.destroy();
    } catch (e) {
      AppLogger.e('Exit error: $e');
    } finally {
      exit(0);
    }
  }
}
