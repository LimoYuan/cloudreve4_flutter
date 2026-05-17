import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../core/utils/app_logger.dart';

/// Android 13+ 兼容初始化。
///
/// 当前项目的文件选择主要走系统文件选择器，因此不在启动时主动申请
/// READ_MEDIA_* 权限，避免用户无感授权弹窗。通知权限必须提前申请，
/// 否则 Android 13+ 上上传/下载进度通知可能不会显示在通知栏。
class AndroidCompatService {
  AndroidCompatService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    _initialized = true;

    await _requestNotificationPermission();
  }

  static Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        AppLogger.d('Android notification permission already granted');
        return;
      }

      if (status.isPermanentlyDenied) {
        AppLogger.d('Android notification permission permanently denied');
        return;
      }

      final result = await Permission.notification.request();
      AppLogger.d('Android notification permission result: $result');
    } catch (e) {
      AppLogger.d('Request Android notification permission failed: $e');
    }
  }

  /// 下载到公共 Download 目录时使用。此权限会跳转到系统设置页，
  /// 因此不要在启动时主动请求；只在用户发起下载时调用。
  static Future<bool> ensureManageExternalStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;

      final result = await Permission.manageExternalStorage.request();
      AppLogger.d('MANAGE_EXTERNAL_STORAGE permission result: $result');
      return result.isGranted;
    } catch (e) {
      AppLogger.d('Request MANAGE_EXTERNAL_STORAGE failed: $e');
      return false;
    }
  }
}
