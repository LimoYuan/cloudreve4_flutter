import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';

/// 下载管理Provider
class DownloadManagerProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTaskModel> _tasks = {};

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
    await _downloadService.initialize();
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
    );

    _tasks[id] = task;
    notifyListeners();

    // 开始下载
    _startDownload(task);

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

  /// 开始下载
  void _startDownload(DownloadTaskModel task) {
    // 监听进度
    StreamSubscription<DownloadTaskModel>? subscription;
    subscription = _downloadService
        .getProgressStream(task.id)
        .listen((updatedTask) {
      _tasks[task.id] = updatedTask;
      notifyListeners();

      // 如果下载完成或失败，关闭流
      if (updatedTask.status == DownloadStatus.completed ||
          updatedTask.status == DownloadStatus.failed ||
          updatedTask.status == DownloadStatus.cancelled) {
        subscription?.cancel();
        _downloadService.disposeTask(task.id);
      }
    });

    // 启动下载
    _downloadService.startDownload(task).catchError((e) {
      debugPrint('下载错误: $e');

      // 如果是权限错误，将任务状态设置为失败并显示错误信息
      final errorMessage = e.toString();
      if (errorMessage.contains('存储权限被永久拒绝')) {
        _tasks[task.id] = task.copyWith(
          status: DownloadStatus.failed,
          errorMessage: errorMessage,
        );
        notifyListeners();
      }
    });
  }

  /// 恢复下载
  void resumeDownload(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      _startDownload(task);
    }
  }

  /// 暂停下载
  void pauseDownload(String taskId) {
    _downloadService.pauseDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        _tasks[taskId] = task.copyWith(status: DownloadStatus.paused);
        notifyListeners();
      }
    }
  }

  /// 取消下载
  void cancelDownload(String taskId) {
    _downloadService.cancelDownload(taskId);

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
      _startDownload(_tasks[taskId]!);
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
