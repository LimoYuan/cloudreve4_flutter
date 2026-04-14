import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';

/// 下载管理Provider
class DownloadManagerProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTaskModel> _tasks = {};
  bool _isInitialized = false;

  /// 获取所有下载任务
  List<DownloadTaskModel> get tasks => _tasks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 获取指定状态的任务
  List<DownloadTaskModel> getTasksByStatus(DownloadStatus status) {
    return tasks.where((task) => task.status == status).toList();
  }

  /// 下载中的任务数
  int get downloadingCount => getTasksByStatus(DownloadStatus.downloading).length;

  /// 初始化下载服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _downloadService.initialize(callbackHandler: _handleDownloadCallback);

    _isInitialized = true;
    debugPrint('DownloadManagerProvider 初始化完成');
  }

  /// 添加下载任务
  Future<DownloadTaskModel?> addDownloadTask({
    required String fileName,
    required String fileUri,
    required int fileSize,
    String? savePath,
  }) async {
    // 如果已存在相同文件的任务，返回null
    DownloadTaskModel? existingTask;
    for (final task in _tasks.values) {
      if (task.fileUri == fileUri) {
        existingTask = task;
        break;
      }
    }

    if (existingTask != null) {
      return null;
    }

    // 确保下载服务已初始化
    await initialize();

    // 获取保存路径
    if (savePath == null) {
      final dir = await _downloadService.getDownloadDirectory();
      savePath = '${dir.path}/$fileName';
    }

    // 创建任务ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final task = DownloadTaskModel(
      id: id,
      fileName: fileName,
      fileUri: fileUri,
      fileSize: fileSize,
      savePath: savePath,
      status: DownloadStatus.waiting,
    );

    _tasks[id] = task;
    notifyListeners();

    // 开始下载
    debugPrint('准备开始下载任务: ${task.id}, 文件: ${task.fileName}, 下载状态: ${task.status}');
    final flutterTaskId = await _downloadService.startDownload(task);
    debugPrint('startDownload 返回: flutterTaskId=$flutterTaskId');

    if (flutterTaskId == null) {
      // 下载失败，更新任务状态
      _tasks[id] = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: '无法创建下载任务',
      );
      notifyListeners();
      return null;
    }

    return task;
  }

  /// 批量添加下载任务
  Future<void> addBatchDownloadTasks(List<Map<String, dynamic>> files) async {
    await initialize();
    final dir = await _downloadService.getDownloadDirectory();

    for (final file in files) {
      final fileName = file['name'] as String;
      final fileUri = file['path'] as String;
      final fileSize = file['size'] as int? ?? 0;

      await addDownloadTask(
        fileName: fileName,
        fileUri: fileUri,
        fileSize: fileSize,
        savePath: '${dir.path}/$fileName',
      );
    }
  }

  /// 处理 flutter_downloader 的回调
  void _handleDownloadCallback(String flutterTaskId, int status, int progress) {
    debugPrint('DownloadManagerProvider._handleDownloadCallback 被调用: flutterTaskId=$flutterTaskId, status=$status, progress=$progress');
    debugPrint('当前任务数量: ${_tasks.length}');

    // 查找对应的内部任务 ID
    final internalId = _downloadService.getInternalTaskId(flutterTaskId);
    debugPrint('对应的内部任务 ID: $internalId');

    if (internalId == null) {
      debugPrint('未找到对应的任务: flutterTaskId=$flutterTaskId');
      return;
    }

    // 获取当前任务
    final task = _tasks[internalId];
    if (task == null) {
      debugPrint('任务不存在: internalId=$internalId');
      return;
    }

    // 根据 flutter_downloader 的状态映射到我们的状态
    DownloadStatus downloadStatus;
    switch (status) {
      case 1: // DownloadTaskStatus.running
        downloadStatus = DownloadStatus.downloading;
        break;
      case 2: // DownloadTaskStatus.paused
        downloadStatus = DownloadStatus.paused;
        break;
      case 3: // DownloadTaskStatus.complete
        downloadStatus = DownloadStatus.completed;
        break;
      case 4: // DownloadTaskStatus.canceled
        downloadStatus = DownloadStatus.cancelled;
        break;
      case 5: // DownloadTaskStatus.failed
        downloadStatus = DownloadStatus.failed;
        break;
      default:
        debugPrint('未知状态: $status');
        return;
    }

    debugPrint('更新任务: internalId=$internalId, status=$downloadStatus, progress=$progress');

    // 更新任务
    final updatedTask = task.copyWith(
      status: downloadStatus,
      downloadedBytes: (task.fileSize * progress / 100).toInt(),
    );

    // 如果下载完成，设置完成时间
    if (downloadStatus == DownloadStatus.completed) {
      _tasks[internalId] = updatedTask.copyWith(
        completedAt: DateTime.now(),
      );
    } else {
      _tasks[internalId] = updatedTask;
    }

    debugPrint('任务已更新: ${_tasks[internalId]!.status}');
    notifyListeners();
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      await _downloadService.resumeDownload(taskId);
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    await _downloadService.pauseDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        _tasks[taskId] = task.copyWith(status: DownloadStatus.paused);
        notifyListeners();
      }
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    await _downloadService.cancelDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(status: DownloadStatus.cancelled);
      notifyListeners();

      // 延迟移除任务
      Future.delayed(const Duration(seconds: 2), () {
        _tasks.remove(taskId);
        _downloadService.disposeTask(taskId);
        notifyListeners();
      });
    }
  }

  /// 删除下载任务（包括文件）
  Future<void> deleteDownloadTask(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      // 删除已下载的文件
      if (task.status == DownloadStatus.completed) {
        await _downloadService.deleteDownloadedFile(task.savePath);
      }

      // 移除任务
      _tasks.remove(taskId);
      _downloadService.disposeTask(taskId);
      notifyListeners();
    }
  }

  /// 重新下载
  Future<void> retryDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      // 删除已下载的部分文件
      await _downloadService.deleteDownloadedFile(task.savePath);

      // 重置任务状态
      _tasks[taskId] = task.copyWith(
        downloadedBytes: 0,
        status: DownloadStatus.waiting,
        errorMessage: null,
        completedAt: null,
      );
      notifyListeners();

      // 重新开始下载
      await _downloadService.startDownload(_tasks[taskId]!);
    }
  }

  /// 清空所有已完成的任务
  Future<void> clearCompletedTasks() async {
    final completedTasks = getTasksByStatus(DownloadStatus.completed);
    for (final task in completedTasks) {
      await deleteDownloadTask(task.id);
    }
  }

  /// 清空所有失败的任务
  void clearFailedTasks() {
    final failedTasks = getTasksByStatus(DownloadStatus.failed);
    for (final task in failedTasks) {
      _tasks.remove(task.id);
      _downloadService.disposeTask(task.id);
    }
    notifyListeners();
  }

  /// 获取任务
  DownloadTaskModel? getTask(String taskId) {
    return _tasks[taskId];
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
