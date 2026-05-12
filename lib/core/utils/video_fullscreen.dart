import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// 视频全屏状态通知器，用于在 main.dart 中隐藏桌面端标题栏
final videoFullscreenNotifier = ValueNotifier<bool>(false);

/// 进入视频全屏（系统级）
Future<void> enterVideoFullscreen() async {
  videoFullscreenNotifier.value = true;
  if (Platform.isAndroid || Platform.isIOS) {
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      ),
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    ]);
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.setFullScreen(true);
  }
}

/// 退出视频全屏（系统级）
Future<void> exitVideoFullscreen() async {
  videoFullscreenNotifier.value = false;
  if (Platform.isAndroid || Platform.isIOS) {
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    ]);
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.setFullScreen(false);
  }
}
