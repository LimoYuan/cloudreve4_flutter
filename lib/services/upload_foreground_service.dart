import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/utils/app_logger.dart';
import '../data/models/upload_task_model.dart';

/// Android 前台服务通知：用于让上传任务在 App 退到后台时继续运行，
/// 并在通知栏展示当前上传文件名、百分比和速度。
///
/// 注意：这不是把上传协议改成 background_downloader；Cloudreve 的上传流程
/// 仍然由 UploadService 执行。这里负责开启前台服务、持有 wake/wifi lock，
/// 并同步通知栏文字。
class UploadForegroundService {
  static const int _serviceId = 46041;
  static const String _channelId = 'cloudreve_upload_service';
  static const String _channelName = 'Cloudreve 上传任务';
  static const String _channelDescription = '显示 Cloudreve 文件上传进度';

  static bool _initialized = false;
  static bool _permissionAsked = false;
  static Timer? _stopTimer;

  static bool get _supportsForegroundService => Platform.isAndroid;

  /// 初始化 communication port，必须在 runApp 前调用。
  static void initCommunicationPort() {
    if (!_supportsForegroundService) return;
    FlutterForegroundTask.initCommunicationPort();
  }

  /// 初始化前台服务配置。
  static Future<void> initialize() async {
    if (!_supportsForegroundService || _initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  /// 根据所有上传任务同步通知状态。
  static Future<void> syncWithTasks(List<UploadTaskModel> tasks) async {
    if (!_supportsForegroundService) return;

    final activeTasks = tasks
        .where(
          (task) =>
              task.status == UploadStatus.waiting ||
              task.status == UploadStatus.uploading ||
              task.status == UploadStatus.paused,
        )
        .toList();

    if (activeTasks.isEmpty) {
      await stop();
      return;
    }

    await initialize();
    await _requestNotificationPermissionIfNeeded();

    _stopTimer?.cancel();
    _stopTimer = null;

    final uploadingTasks = activeTasks
        .where((task) => task.status == UploadStatus.uploading)
        .toList();
    final primaryTask = uploadingTasks.isNotEmpty
        ? uploadingTasks.first
        : activeTasks.first;

    final title = activeTasks.length == 1
        ? 'Cloudreve 正在上传'
        : 'Cloudreve 正在上传 ${activeTasks.length} 个文件';
    final text = _buildNotificationText(primaryTask);

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
          notificationInitialRoute: '/',
          callback: uploadForegroundTaskStartCallback,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('启动/更新上传前台服务失败: $e\n$stackTrace');
    }
  }

  /// 上传结束后展示短暂完成状态，然后关闭前台服务。
  static Future<void> showFinishedThenStop({
    required String title,
    required String text,
  }) async {
    if (!_supportsForegroundService) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {
      // 忽略完成态通知失败；后续仍尝试停止服务。
    }

    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 2), () {
      unawaited(stop());
    });
  }

  static Future<void> stop() async {
    if (!_supportsForegroundService) return;

    _stopTimer?.cancel();
    _stopTimer = null;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      AppLogger.d('停止上传前台服务失败: $e');
    }
  }

  static Future<void> _requestNotificationPermissionIfNeeded() async {
    if (_permissionAsked) return;
    _permissionAsked = true;

    try {
      final permission = await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      AppLogger.d('请求通知权限失败: $e');
    }
  }

  static String _buildNotificationText(UploadTaskModel task) {
    final percent = (task.progress * 100).clamp(0, 100).toStringAsFixed(1);
    final speed = task.speedText.isNotEmpty ? ' · ${task.speedText}' : '';

    switch (task.status) {
      case UploadStatus.waiting:
        return '${task.fileName} · 等待中';
      case UploadStatus.uploading:
        return '${task.fileName} · $percent%$speed';
      case UploadStatus.paused:
        return '${task.fileName} · 已暂停';
      case UploadStatus.completed:
        return '${task.fileName} · 上传完成';
      case UploadStatus.failed:
        return '${task.fileName} · 上传失败';
      case UploadStatus.cancelled:
        return '${task.fileName} · 已取消';
    }
  }
}

/// flutter_foreground_task 要求 callback 必须是顶层函数或静态函数。
@pragma('vm:entry-point')
void uploadForegroundTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_UploadForegroundTaskHandler());
}

class _UploadForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Upload foreground task started: ${starter.name}');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 上传本身仍由主 isolate 的 UploadService 执行；这里保持前台服务存活。
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('Upload foreground task destroyed, isTimeout=$isTimeout');
  }

  @override
  void onReceiveData(Object data) {
    print('Upload foreground task receive data: $data');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}
