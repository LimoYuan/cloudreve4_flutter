import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/file_manager_provider.dart';
import 'exit_hint_overlay.dart';

/// 手势处理 Mixin
mixin GestureHandlerMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastSwipeTime;
  final ExitHintOverlay _exitHintOverlay = ExitHintOverlay();

  /// 处理左滑手势
  void handleSwipe(
    BuildContext context,
    FileManagerProvider fileManager,
    DragEndDetails details,
  ) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < 0) {
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
      SystemNavigator.pop();
    } else {
      _lastSwipeTime = now;
      _exitHintOverlay.show(context);
      Future.delayed(const Duration(seconds: 2), () {
        _exitHintOverlay.remove();
      });
    }
  }
}
