import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/storage_keys.dart';
import '../data/models/download_task_model.dart';
import 'file_service.dart';
import 'storage_service.dart';
import '../core/utils/app_logger.dart';

/// 下载服务 - 单例模式
/// 所有平台统一使用 background_downloader
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  DownloadService._internal();

  // 统一映射：外部下载器 task ID → 内部 task ID
  final Map<String, String> _externalTaskIdToInternalId = {};
  final Map<String, String> _internalIdToExternalTaskId = {};

  // 存储 background_downloader 的 DownloadTask 对象，用于暂停/恢复/取消
  final Map<String, bd.DownloadTask> _bdTasks = {};

  // 回调处理器
  static Function(String taskId, DownloadStatus status, int progress)?
      _callbackHandler;

  final FileService _fileService = FileService();
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers =
      {};
  bool _isInitialized = false;

  /// 设置回调处理器
  static void setCallbackHandler(
      Function(String taskId, DownloadStatus status, int progress) handler) {
    _callbackHandler = handler;
  }

  /// 获取下载任务进度流
  Stream<DownloadTaskModel> getProgressStream(String taskId) {
    if (!_progressControllers.containsKey(taskId)) {
      _progressControllers[taskId] =
          StreamController<DownloadTaskModel>.broadcast();
    }
    return _progressControllers[taskId]!.stream;
  }

  /// 获取下载目录
  Future<Directory> getDownloadDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      final status = await Permission.manageExternalStorage.request();

      if (status.isPermanentlyDenied) {
        throw Exception('存储权限被永久拒绝，请在设置中开启');
      }

      if (!status.isGranted) {
        throw Exception('存储权限被拒绝');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${appDocDir.path}/Downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else {
      // Windows/Linux/macOS - 使用系统下载目录
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
      // 回退方案
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final dir = Directory('$userProfile\\Downloads');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory('$home/Downloads');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// 读取 WiFi-only 下载设置
  Future<bool> isWifiOnlyEnabled() async {
    return await StorageService.instance
            .getBool(StorageKeys.downloadWifiOnly) ??
        false;
  }

  /// 初始化下载器
  Future<void> initialize(
      {Function(String taskId, DownloadStatus status, int progress)?
          callbackHandler}) async {
    if (callbackHandler != null) {
      setCallbackHandler(callbackHandler);
      AppLogger.d('回调处理器已更新');
    }

    if (_isInitialized) {
      AppLogger.d('DownloadService 已经初始化');
      return;
    }

    // 配置通知（Android 前台服务需要通知栏显示）
    if (Platform.isAndroid) {
      bd.FileDownloader().configureNotification(
        running: const bd.TaskNotification(
            '正在下载', '文件: {filename} - {progress}'),
        complete:
            const bd.TaskNotification('下载完成', '文件: {filename} 已保存'),
        error: const bd.TaskNotification('下载失败', '文件: {filename} 下载出错'),
        paused: const bd.TaskNotification('已暂停', '文件: {filename} 已暂停'),
        progressBar: true,
        tapOpensFile: true,
      );
      AppLogger.d('background_downloader 通知已配置');
    }

    bd.FileDownloader().registerCallbacks(
      taskStatusCallback: _handleBdStatusUpdate,
      taskProgressCallback: _handleBdProgressUpdate,
    );

    _isInitialized = true;
    AppLogger.d('DownloadService 初始化完成 (background_downloader)');
  }

  /// background_downloader 状态回调
  void _handleBdStatusUpdate(bd.TaskStatusUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    if (internalId == null) {
      AppLogger.d(
          'background_downloader 状态回调: 未找到内部任务ID, taskId=${update.task.taskId}');
      return;
    }

    DownloadStatus status;
    switch (update.status) {
      case bd.TaskStatus.enqueued:
        status = DownloadStatus.waiting;
      case bd.TaskStatus.running:
        status = DownloadStatus.downloading;
      case bd.TaskStatus.complete:
        status = DownloadStatus.completed;
      case bd.TaskStatus.notFound:
      case bd.TaskStatus.failed:
        status = DownloadStatus.failed;
      case bd.TaskStatus.canceled:
        status = DownloadStatus.cancelled;
      case bd.TaskStatus.paused:
        status = DownloadStatus.paused;
      case bd.TaskStatus.waitingToRetry:
        status = DownloadStatus.waiting;
    }

    AppLogger.d(
        'background_downloader 状态更新: taskId=${update.task.taskId}, internalId=$internalId, status=$status');

    final progress = status == DownloadStatus.completed ? 100 : 0;
    _callbackHandler?.call(internalId, status, progress);
  }

  /// background_downloader 进度回调
  void _handleBdProgressUpdate(bd.TaskProgressUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    if (internalId == null) return;

    final progress = (update.progress * 100).toInt().clamp(0, 100);
    _callbackHandler?.call(internalId, DownloadStatus.downloading, progress);
  }

  /// 开始下载
  Future<String?> startDownload(DownloadTaskModel task) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 获取下载 URL
      String url = task.downloadUrl ?? '';
      if (url.isEmpty) {
        final response = await _fileService.getDownloadUrls(
          uris: [task.fileUri],
          download: true,
        );

        final urls = response['urls'] as List<dynamic>? ?? [];
        if (urls.isEmpty) {
          throw Exception('无法获取下载链接');
        }

        final urlData = urls[0] as Map<String, dynamic>;
        url = urlData['url'] as String;
      }

      // 确保保存目录存在
      final file = File(task.savePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 如果文件已存在，删除它
      if (await file.exists()) {
        await file.delete();
      }

      return _startBdDownload(task, url, dir);
    } catch (e) {
      AppLogger.d('下载失败: $e');
      rethrow;
    }
  }

  /// 使用 background_downloader 开始下载
  Future<String?> _startBdDownload(
      DownloadTaskModel task, String url, Directory dir) async {
    final wifiOnly = await isWifiOnlyEnabled();
    final bdTask = bd.DownloadTask(
      url: url,
      filename: task.fileName,
      directory: dir.path,
      baseDirectory: bd.BaseDirectory.root,
      updates: bd.Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
      requiresWiFi: wifiOnly,
      metaData: task.id,
    );

    final success = await bd.FileDownloader().enqueue(bdTask);

    if (!success) {
      throw Exception('创建下载任务失败');
    }

    // 保存映射关系
    _externalTaskIdToInternalId[bdTask.taskId] = task.id;
    _internalIdToExternalTaskId[task.id] = bdTask.taskId;
    _bdTasks[task.id] = bdTask;

    AppLogger.d(
        'background_downloader 任务已添加: taskId=${bdTask.taskId}, internalId=${task.id}, requiresWiFi=$wifiOnly');

    return bdTask.taskId;
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    final bdTask = _bdTasks[taskId];
    if (bdTask != null) {
      await bd.FileDownloader().pause(bdTask);
    }
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    if (!_isInitialized) {
      await initialize();
    }
    final bdTask = _bdTasks[taskId];
    if (bdTask != null) {
      await bd.FileDownloader().resume(bdTask);
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    final bdTask = _bdTasks[taskId];
    if (bdTask != null) {
      await bd.FileDownloader().cancel(bdTask);
    }
  }

  /// 删除下载任务
  void disposeTask(String taskId) {
    final externalId = _internalIdToExternalTaskId[taskId];
    if (externalId != null) {
      _externalTaskIdToInternalId.remove(externalId);
    }
    _internalIdToExternalTaskId.remove(taskId);
    _bdTasks.remove(taskId);

    // 关闭进度流
    final controller = _progressControllers[taskId];
    if (controller != null) {
      controller.close();
      _progressControllers.remove(taskId);
    }
  }

  /// 删除已下载的文件
  Future<void> deleteDownloadedFile(String savePath) async {
    try {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.d('删除文件失败: $e');
    }
  }

  /// 获取可读的文件大小
  static String getReadableFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 清理所有资源
  void dispose() {
    _externalTaskIdToInternalId.clear();
    _internalIdToExternalTaskId.clear();
    _bdTasks.clear();

    // 关闭所有流
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
