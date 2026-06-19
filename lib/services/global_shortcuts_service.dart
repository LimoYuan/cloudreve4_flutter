import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/utils/app_logger.dart';

/// 全局快捷键服务（仅 Windows / Linux 桌面端）。
///
/// 进程级生效，注册一次后整个应用生命周期都能响应：
/// - F11：切换全屏
class GlobalShortcutsService {
  GlobalShortcutsService._();
  static final GlobalShortcutsService instance = GlobalShortcutsService._();

  bool _initialized = false;
  bool _toggling = false;

  void init() {
    if (_initialized) return;
    if (!(Platform.isWindows || Platform.isLinux)) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _initialized = true;
    AppLogger.i('[GlobalShortcuts] F11 全屏快捷键已注册');
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      // 用 microtask 让事件链先派发完，再切换全屏；避免在 keyboard handler 内
      // 同步触发原生窗口操作导致的状态错乱（用户反馈 F10→F11 序列下 F11 失效）
      Future.microtask(_toggleFullScreen);
      return true;
    }
    return false;
  }

  Future<void> _toggleFullScreen() async {
    if (_toggling) return;
    _toggling = true;
    try {
      // 不缓存 _isFullScreen，每次直接读窗口真实状态，避免与系统/用户其他途径
      // 切换全屏时失去同步
      final cur = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!cur);
    } catch (e) {
      AppLogger.d('[GlobalShortcuts] setFullScreen failed: $e');
    } finally {
      _toggling = false;
    }
  }
}
