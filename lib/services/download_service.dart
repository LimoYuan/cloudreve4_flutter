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
  static Function(String taskId, DownloadStatus status, double? progressPercent)?
      _callbackHandler;

  final FileService _fileService = FileService();
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers =
      {};
  bool _isInitialized = false;

  /// 设置回调处理器
  static void setCallbackHandler(
      Function(String taskId, DownloadStatus status, double? progressPercent)
          handler) {
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

  /// 读取重试次数设置
  Future<int> getRetries() async {
    return await StorageService.instance
            .getInt(StorageKeys.downloadRetries) ??
        3;
  }

  /// 初始化下载器
  Future<void> initialize(
      {Function(String taskId, DownloadStatus status, double? progressPercent)?
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

    // 启动任务追踪和恢复
    await bd.FileDownloader().start(
      doTrackTasks: true,
      markDownloadedComplete: true,
      doRescheduleKilledTasks: true,
    );

    _isInitialized = true;
    AppLogger.d('DownloadService 初始化完成 (background_downloader)');
  }

  /// background_downloader 状态回调
  void _handleBdStatusUpdate(bd.TaskStatusUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    // 如果映射不存在，尝试从 metaData 恢复
    if (internalId == null && update.task.metaData.isNotEmpty) {
      final metaInternalId = update.task.metaData;
      _externalTaskIdToInternalId[update.task.taskId] = metaInternalId;
      _internalIdToExternalTaskId[metaInternalId] = update.task.taskId;
      _bdTasks[metaInternalId] = update.task as bd.DownloadTask;
      AppLogger.d(
          '从 metaData 恢复映射: bdTaskId=${update.task.taskId}, internalId=$metaInternalId');
    }

    final resolvedInternalId =
        _externalTaskIdToInternalId[update.task.taskId];
    if (resolvedInternalId == null) {
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
        'background_downloader 状态更新: taskId=${update.task.taskId}, internalId=$resolvedInternalId, status=$status');

    // 状态回调不应该把进度重置为 0。
    // 之前 running/enqueued/paused/failed 都传 progress=0，导致任务页进度条一段段跳动、
    // 甚至从已有进度回退到 0。只有完成状态明确传 100，其它状态保持现有进度。
    final progressPercent = status == DownloadStatus.completed ? 100.0 : null;
    _callbackHandler?.call(resolvedInternalId, status, progressPercent);
  }

  /// background_downloader 进度回调
  void _handleBdProgressUpdate(bd.TaskProgressUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    if (internalId == null) return;

    final rawProgress = update.progress;

    // background_downloader 在部分状态下可能返回负数或非正常进度。
    // 这些不是有效进度，不能用来刷新 UI。
    if (rawProgress.isNaN || rawProgress < 0) {
      return;
    }

    final progressPercent = (rawProgress * 100).clamp(0.0, 100.0).toDouble();
    _callbackHandler?.call(
      internalId,
      DownloadStatus.downloading,
      progressPercent,
    );
  }

  /// 开始下载（新任务）
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

      // 新任务：如果完整文件已存在，删除它
      if (await file.exists() && task.downloadedBytes == 0) {
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
    final retries = await getRetries();
    final bdTask = bd.DownloadTask(
      url: url,
      filename: task.fileName,
      directory: dir.path,
      baseDirectory: bd.BaseDirectory.root,
      updates: bd.Updates.statusAndProgress,
      allowPause: true,
      retries: retries,
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

    // 保存 backgroundTaskId 到任务模型（持久化，用于重启后恢复映射）
    task.backgroundTaskId = bdTask.taskId;

    AppLogger.d(
        'background_downloader 任务已添加: taskId=${bdTask.taskId}, internalId=${task.id}, requiresWiFi=$wifiOnly, retries=$retries');

    return bdTask.taskId;
  }

  /// 恢复下载（用于重启后恢复暂停的任务）
  Future<String?> resumeDownloadAfterRestart(
      DownloadTaskModel task) async {
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

      final file = File(task.savePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 恢复任务：不删除部分文件，使用 resume 方式重建 bdTask
      final wifiOnly = await isWifiOnlyEnabled();
      final retries = await getRetries();
      final bdTask = bd.DownloadTask(
        url: url,
        filename: task.fileName,
        directory: dir.path,
        baseDirectory: bd.BaseDirectory.root,
        updates: bd.Updates.statusAndProgress,
        allowPause: true,
        retries: retries,
        requiresWiFi: wifiOnly,
        metaData: task.id,
      );

      // 恢复映射关系
      _externalTaskIdToInternalId[bdTask.taskId] = task.id;
      _internalIdToExternalTaskId[task.id] = bdTask.taskId;
      _bdTasks[task.id] = bdTask;
      task.backgroundTaskId = bdTask.taskId;

      // 如果有已下载的部分，尝试 resume；否则 enqueue
      final partialFile =
          File('${dir.path}/${task.fileName}.part');
      if (task.downloadedBytes > 0 && await partialFile.exists()) {
        AppLogger.d(
            '断点续传: ${task.fileName}, 已下载 ${task.downloadedBytes} bytes');
        await bd.FileDownloader().resume(bdTask);
      } else {
        AppLogger.d('重新下载: ${task.fileName}');
        final success = await bd.FileDownloader().enqueue(bdTask);
        if (!success) {
          throw Exception('创建下载任务失败');
        }
      }

      return bdTask.taskId;
    } catch (e) {
      AppLogger.d('恢复下载失败: $e');
      rethrow;
    }
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
      // 同时删除部分文件
      final partialFile = File('$savePath.part');
      if (await partialFile.exists()) {
        await partialFile.delete();
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
