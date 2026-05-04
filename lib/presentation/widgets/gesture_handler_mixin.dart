import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/file_manager_provider.dart';
import 'exit_hint_overlay.dart';
import '../../core/utils/app_logger.dart';
import '../../services/desktop_service.dart';

/// 手势处理 Mixin
mixin GestureHandlerMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastSwipeTime;
  final ExitHintOverlay _exitHintOverlay = ExitHintOverlay();

  /// 子类需要提供 Scaffold 的 key
  GlobalKey<ScaffoldState>? get scaffoldKey => null;

  /// 处理滑动手势
  void handleSwipe(
    BuildContext context,
    FileManagerProvider fileManager,
    DragEndDetails details,
  ) {
    if (details.primaryVelocity == null) {
      AppLogger.d('Swipe velocity is null');
      return;
    }

    // 调试输出
    AppLogger.d('Swipe primaryVelocity: ${details.primaryVelocity}');

    // primaryVelocity > 0: 从左往右滑 → 打开侧边栏
    // primaryVelocity < 0: 从右往左滑 → 返回或退出

    // 从左往右滑（velocity > 0）：打开侧边栏
    if (details.primaryVelocity! > 0) {
      AppLogger.d('Right swipe detected (velocity > 0), opening drawer');
      scaffoldKey?.currentState?.openDrawer();
    }
    // 从右往左滑（velocity < 0）：返回或退出
    else if (details.primaryVelocity! < 0) {
      AppLogger.d('Left swipe detected (velocity < 0)');
      if (fileManager.currentPath == '/') {
        checkExitApp(context);
      } else {
        navigateBack(context, fileManager);
      }
    }
  }

  /// 处理返回键
  Future<void> handleBackPress(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    if (fileManager.currentPath == '/') {
      await checkExitApp(context);
    } else {
      await navigateBack(context, fileManager);
    }
  }

  /// 返回上一级
  Future<void> navigateBack(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    await fileManager.goBack();
  }

  /// 检查退出应用
  Future<void> checkExitApp(BuildContext context) async {
    final now = DateTime.now();
    if (_lastSwipeTime != null && now.difference(_lastSwipeTime!).inSeconds < 2) {
      _exitHintOverlay.remove();
      if (DesktopService.isDesktopPlatform) {
        await windowManager.hide();
      } else {
        SystemNavigator.pop();
      }
    } else {
      _lastSwipeTime = now;
      _exitHintOverlay.show(context);
      Future.delayed(const Duration(seconds: 2), () {
        _exitHintOverlay.remove();
      });
    }
  }
}
