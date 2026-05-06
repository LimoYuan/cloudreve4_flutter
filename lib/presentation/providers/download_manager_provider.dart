import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../core/constants/storage_keys.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/app_logger.dart';

/// 下载管理Provider
class DownloadManagerProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final Map<String, DownloadTaskModel> _tasks = {};
  bool _isInitialized = false;
  bool _isWifiOnlyEnabled = false;

  // 速度追踪：记录每个任务的上次进度更新时间和字节数
  final Map<String, DateTime> _lastProgressTime = {};
  final Map<String, int> _lastProgressBytes = {};

  /// 获取所有下载任务
  List<DownloadTaskModel> get tasks => _tasks.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 获取指定状态的任务
  List<DownloadTaskModel> getTasksByStatus(DownloadStatus status) {
    return tasks.where((task) => task.status == status).toList();
  }

  /// 下载中的任务数
  int get downloadingCount =>
      getTasksByStatus(DownloadStatus.downloading).length;

  /// 活跃任务数（下载中 + 等待中 + 暂停）
  int get activeTaskCount => tasks
      .where((t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.waiting ||
          t.status == DownloadStatus.paused)
      .length;

  /// WiFi-only 设置
  bool get isWifiOnlyEnabled => _isWifiOnlyEnabled;

  /// 初始化下载服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _downloadService.initialize(callbackHandler: _handleDownloadCallback);

    // 加载 WiFi-only 设置
    _isWifiOnlyEnabled =
        await StorageService.instance.getBool(StorageKeys.downloadWifiOnly) ??
            false;

    // 从本地存储加载已保存的下载任务
    await _loadTasks();

    _isInitialized = true;
    AppLogger.d('DownloadManagerProvider 初始化完成');
  }

  /// 更新 WiFi-only 设置，并同步等待中的任务
  Future<void> setWifiOnlyEnabled(bool value) async {
    _isWifiOnlyEnabled = value;
    await StorageService.instance
        .setBool(StorageKeys.downloadWifiOnly, value);

    // 如果关闭了WiFi-only，需要将等待WiFi的任务重新入队
    if (!value) {
      for (final task in _tasks.values.toList()) {
        if (task.waitingForWifi) {
          // 取消当前等待WiFi的任务，重新入队（不需要WiFi）
          await _downloadService.cancelDownload(task.id);
          _tasks[task.id] = task.copyWith(
            status: DownloadStatus.waiting,
            waitingForWifi: false,
          );
          await _saveTasks();
          // 重新开始下载
          await _downloadService.startDownload(_tasks[task.id]!);
        }
      }
    }

    notifyListeners();
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
    await _saveTasks();
    notifyListeners();

    // 开始下载
    AppLogger.d(
        '准备开始下载任务: ${task.id}, 文件: ${task.fileName}, 下载状态: ${task.status}');
    final bdTaskId = await _downloadService.startDownload(task);
    AppLogger.d('startDownload 返回: bdTaskId=$bdTaskId');

    if (bdTaskId == null) {
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

  /// 处理下载回调
  void _handleDownloadCallback(
      String taskId, DownloadStatus status, int progress) async {
    AppLogger.d(
        'DownloadManagerProvider._handleDownloadCallback: taskId=$taskId, status=$status, progress=$progress');

    // 获取当前任务
    final task = _tasks[taskId];
    if (task == null) {
      AppLogger.d('任务不存在: taskId=$taskId');
      return;
    }

    // 计算下载字节数和速度
    final downloadedBytes = (task.fileSize * progress / 100).toInt();
    int speed = 0;
    final now = DateTime.now();
    final lastTime = _lastProgressTime[taskId];
    final lastBytes = _lastProgressBytes[taskId] ?? 0;

    if (status == DownloadStatus.downloading && lastTime != null) {
      final elapsed = now.difference(lastTime).inMilliseconds;
      if (elapsed > 0) {
        speed = ((downloadedBytes - lastBytes) * 1000 / elapsed).round();
      }
    }

    if (status == DownloadStatus.downloading) {
      _lastProgressTime[taskId] = now;
      _lastProgressBytes[taskId] = downloadedBytes;
    } else {
      _lastProgressTime.remove(taskId);
      _lastProgressBytes.remove(taskId);
    }

    // 判断是否在等待WiFi
    final waitingForWifi =
        status == DownloadStatus.waiting && _isWifiOnlyEnabled;

    // 更新任务
    final updatedTask = task.copyWith(
      status: status,
      downloadedBytes: downloadedBytes,
      speed: speed,
      waitingForWifi: waitingForWifi,
    );

    // 如果下载完成，设置完成时间
    if (status == DownloadStatus.completed) {
      _tasks[taskId] = updatedTask.copyWith(
        completedAt: DateTime.now(),
        speed: 0,
      );
    } else {
      _tasks[taskId] = updatedTask;
    }

    AppLogger.d('任务已更新: ${_tasks[taskId]!.status}');
    await _saveTasks();
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
        _tasks[taskId] = task.copyWith(
            status: DownloadStatus.paused, speed: 0, waitingForWifi: false);
        _lastProgressTime.remove(taskId);
        _lastProgressBytes.remove(taskId);
        await _saveTasks();
        notifyListeners();
      }
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    await _downloadService.cancelDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      _tasks[taskId] = task.copyWith(
          status: DownloadStatus.cancelled, waitingForWifi: false);
      await _saveTasks();
      notifyListeners();

      // 延迟移除任务，同时从存储中删除
      Future.delayed(const Duration(seconds: 2), () {
        _tasks.remove(taskId);
        _downloadService.disposeTask(taskId);
        _saveTasks();
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
      await _saveTasks();
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
        speed: 0,
        status: DownloadStatus.waiting,
        errorMessage: null,
        completedAt: null,
        waitingForWifi: false,
      );
      _lastProgressTime.remove(taskId);
      _lastProgressBytes.remove(taskId);
      await _saveTasks();
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
  Future<void> clearFailedTasks() async {
    final failedTasks = getTasksByStatus(DownloadStatus.failed);
    for (final task in failedTasks) {
      _tasks.remove(task.id);
      _downloadService.disposeTask(task.id);
    }
    await _saveTasks();
    notifyListeners();
  }

  /// 获取任务
  DownloadTaskModel? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// 从本地存储加载下载任务
  Future<void> _loadTasks() async {
    try {
      final tasksJson =
          await StorageService.instance.getString(StorageKeys.downloadTasks);
      if (tasksJson == null || tasksJson.isEmpty) {
        AppLogger.d('没有保存的下载任务');
        return;
      }

      final tasksList = jsonDecode(tasksJson) as List<dynamic>;
      final loadedTasks = <DownloadTaskModel>[];

      final now = DateTime.now();
      for (final taskJson in tasksList) {
        try {
          final task =
              DownloadTaskModel.fromJson(taskJson as Map<String, dynamic>);
          // 过滤掉已取消的任务（修复4：已取消任务不恢复）
          if (task.status == DownloadStatus.cancelled) {
            continue;
          }

          // 如果任务已完成，只保留最近7天内的记录
          if (task.status == DownloadStatus.completed) {
            if (task.completedAt == null) {
              continue;
            }
            final daysSinceCompletion =
                now.difference(task.completedAt!).inDays;
            if (daysSinceCompletion > 7) {
              AppLogger.d('跳过超过7天的已完成任务: ${task.fileName}');
              continue;
            }
          }

          loadedTasks.add(task);
        } catch (e) {
          AppLogger.d('解析下载任务失败: $e');
        }
      }

      // 将加载的任务添加到当前任务列表
      for (final task in loadedTasks) {
        _tasks[task.id] = task;
      }

      AppLogger.d('从存储加载了 ${loadedTasks.length} 个下载任务');

      // 通知 UI 更新
      if (loadedTasks.isNotEmpty) {
        notifyListeners();
      }

      // 恢复未完成的任务
      for (final task in loadedTasks) {
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.waiting) {
          AppLogger.d('恢复下载任务: ${task.fileName}');
          // 使用 resumeDownloadAfterRestart 支持断点续传
          await _downloadService.resumeDownloadAfterRestart(task);
        } else if (task.status == DownloadStatus.paused) {
          // 修复5：暂停的任务需要重建 bdTasks 映射，以便继续下载
          AppLogger.d('重建暂停任务映射: ${task.fileName}');
          await _downloadService.resumeDownloadAfterRestart(task);
          // 重建映射后立即暂停，保持任务在暂停状态
          await _downloadService.pauseDownload(task.id);
        }
      }
    } catch (e) {
      AppLogger.d('加载下载任务失败: $e');
    }
  }

  /// 保存下载任务到本地存储
  Future<void> _saveTasks() async {
    try {
      final tasksList = _tasks.values.map((task) => task.toJson()).toList();
      final tasksJson = jsonEncode(tasksList);
      await StorageService.instance
          .setString(StorageKeys.downloadTasks, tasksJson);
      AppLogger.d('已保存 ${_tasks.length} 个下载任务到存储');
    } catch (e) {
      AppLogger.d('保存下载任务失败: $e');
    }
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
