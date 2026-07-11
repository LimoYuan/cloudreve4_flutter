import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../core/constants/storage_keys.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';
import '../../services/storage_service.dart';
import '../../services/task_database.dart';
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
  DateTime? _lastProgressPersistTime;
  Timer? _activeDownloadSampler;
  bool _isSamplingLocalProgress = false;

  /// 进度更新节流写库缓冲。
  ///
  /// 下载进度回调很密集，每次都写库会过度触发 IO。
  /// 这里缓冲 500ms 批量写一次（downloadedBytes/speed/updatedAt）。
  /// 状态变更（completed/failed/paused/cancelled）走 _persistTask 立即写库。
  final Map<String, DownloadTaskModel> _runtimeTaskBuffer = {};
  Timer? _throttleWriteTimer;


  /// 暂停/恢复后的基准字节数。
  ///
  /// background_downloader 在 pause/resume 后，某些情况下 progress 会从
  /// 本次 resume 的 0% 重新报，而不是全文件累计进度。
  /// 如果直接用 fileSize * progress，会小于已有 downloadedBytes，
  /// 旧逻辑为了避免倒退会一直卡住，直到本次进度超过旧累计百分比。
  final Map<String, int> _resumeBaseBytes = {};

  /// 获取所有下载任务
  List<DownloadTaskModel> get tasks =>
      _tasks.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 获取指定状态的任务
  List<DownloadTaskModel> getTasksByStatus(DownloadStatus status) {
    return tasks.where((task) => task.status == status).toList();
  }

  /// 下载中的任务数
  int get downloadingCount => tasks
      .where(
        (t) =>
            t.status == DownloadStatus.archiving ||
            t.status == DownloadStatus.downloading,
      )
      .length;

  /// 活跃任务数（打包中 + 下载中 + 等待中 + 暂停）
  int get activeTaskCount => tasks
      .where(
        (t) =>
            t.status == DownloadStatus.archiving ||
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.waiting ||
            t.status == DownloadStatus.paused,
      )
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

    _ensureActiveDownloadSampler();

    _isInitialized = true;
    AppLogger.d('DownloadManagerProvider 初始化完成');
  }

  /// 更新 WiFi-only 设置，并同步等待中的任务
  Future<void> setWifiOnlyEnabled(bool value) async {
    _isWifiOnlyEnabled = value;
    await StorageService.instance.setBool(StorageKeys.downloadWifiOnly, value);

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
          await _persistTask(_tasks[task.id]!);
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
    String? downloadUrl,
    DownloadStatus initialStatus = DownloadStatus.waiting,
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
      downloadUrl: downloadUrl,
      status: initialStatus,
    );

    _tasks[id] = task;
    await _persistTask(task);
    notifyListeners();
    _ensureActiveDownloadSampler();

    // 开始下载
    AppLogger.d(
      '准备开始下载任务: ${task.id}, 文件: ${task.fileName}, 下载状态: ${task.status}',
    );
    final bdTaskId = await _downloadService.startDownload(task);
    AppLogger.d('startDownload 返回: bdTaskId=$bdTaskId');

    if (bdTaskId == null) {
      // 下载失败，更新任务状态
      _tasks[id] = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: '无法创建下载任务',
      );
      await _persistTask(_tasks[id]!);
      notifyListeners();
      return null;
    }

    final startedTask = _tasks[id];
    if (startedTask != null && startedTask.status == DownloadStatus.waiting) {
      _tasks[id] = startedTask.copyWith(
        status: DownloadStatus.downloading,
        backgroundTaskId: bdTaskId.startsWith('dio:') ? startedTask.backgroundTaskId : bdTaskId,
        waitingForWifi: false,
      );
      await _persistTask(_tasks[id]!);
      notifyListeners();
    }

    return _tasks[id] ?? task;
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
  ///
  /// [progressPercent] 为 null 表示这是纯状态更新，不应该重置已有进度。
  /// [downloadedBytes] 用于 background_downloader 在未知总大小时上报的真实已下载字节数。
  void _handleDownloadCallback(
    String taskId,
    DownloadStatus status,
    double? progressPercent, {
    int? downloadedBytes,
  }) async {
    final isProgressUpdate =
        status == DownloadStatus.downloading &&
        (progressPercent != null || downloadedBytes != null);
    final logProgressCallback = isProgressUpdate ? AppLogger.t : AppLogger.d;
    logProgressCallback(
      'DownloadManagerProvider._handleDownloadCallback: '
      'taskId=$taskId, status=$status, progressPercent=$progressPercent, downloadedBytes=$downloadedBytes',
    );

    final task = _tasks[taskId];
    if (task == null) {
      AppLogger.d('任务不存在: taskId=$taskId');
      return;
    }

    var effectiveStatus = status;
    final hasProgress = progressPercent != null && progressPercent.isFinite;

    // background_downloader may emit a non-progress enqueued/waiting status after
    // an earlier running/progress callback. Treat that as a transient scheduler
    // callback instead of downgrading the visible row back to "waiting".
    if (effectiveStatus == DownloadStatus.waiting &&
        task.status == DownloadStatus.downloading &&
        !task.waitingForWifi &&
        progressPercent == null &&
        downloadedBytes == null &&
        task.downloadedBytes > 0) {
      effectiveStatus = DownloadStatus.downloading;
    }

    var currentDownloadedBytes = task.downloadedBytes;

    if (downloadedBytes != null) {
      currentDownloadedBytes = downloadedBytes.clamp(0, 1 << 62);
    } else if (effectiveStatus == DownloadStatus.completed) {
      currentDownloadedBytes = task.fileSize > 0
          ? task.fileSize
          : _completedFileSize(task) ?? task.downloadedBytes;
      _resumeBaseBytes.remove(taskId);
    } else if (hasProgress && task.fileSize > 0) {
      final normalized = progressPercent.clamp(0.0, 100.0);
      final calculatedWholeBytes = (task.fileSize * normalized / 100.0)
          .round()
          .clamp(0, task.fileSize);

      final resumeBase = _resumeBaseBytes[taskId];

      if (resumeBase != null &&
          resumeBase > 0 &&
          calculatedWholeBytes < resumeBase) {
        final remainingBytes = (task.fileSize - resumeBase).clamp(
          0,
          task.fileSize,
        );
        final resumedBytes = (resumeBase + remainingBytes * normalized / 100.0)
            .round()
            .clamp(0, task.fileSize);

        if (resumedBytes >= currentDownloadedBytes ||
            currentDownloadedBytes == 0) {
          currentDownloadedBytes = resumedBytes;
        }
      } else {
        if (calculatedWholeBytes >= currentDownloadedBytes ||
            currentDownloadedBytes == 0) {
          currentDownloadedBytes = calculatedWholeBytes;
        }

        if (resumeBase != null && calculatedWholeBytes >= resumeBase) {
          _resumeBaseBytes.remove(taskId);
        }
      }
    }

    var speed = task.speed;
    final now = DateTime.now();

    if (effectiveStatus == DownloadStatus.downloading &&
        (hasProgress || downloadedBytes != null)) {
      final lastTime = _lastProgressTime[taskId];
      final lastBytes = _lastProgressBytes[taskId];

      if (lastTime != null && lastBytes != null) {
        final elapsedMs = now.difference(lastTime).inMilliseconds;
        final bytesDelta = currentDownloadedBytes - lastBytes;

        if (elapsedMs >= 300 && bytesDelta >= 0) {
          speed = (bytesDelta * 1000 / elapsedMs).round();
        }
      }

      _lastProgressTime[taskId] = now;
      _lastProgressBytes[taskId] = currentDownloadedBytes;
    } else if (effectiveStatus == DownloadStatus.downloading && !hasProgress) {
      speed = task.speed;
    } else {
      speed = 0;
      _lastProgressTime.remove(taskId);
      _lastProgressBytes.remove(taskId);
    }

    final waitingForWifi =
        effectiveStatus == DownloadStatus.waiting &&
        (_isWifiOnlyEnabled || task.waitingForWifi);

    final updatedTask = task.copyWith(
      status: effectiveStatus,
      fileSize: effectiveStatus == DownloadStatus.completed && task.fileSize <= 0
          ? currentDownloadedBytes
          : task.fileSize,
      downloadedBytes: currentDownloadedBytes,
      speed: speed,
      waitingForWifi: waitingForWifi,
      completedAt: effectiveStatus == DownloadStatus.completed
          ? DateTime.now()
          : task.completedAt,
    );

    _tasks[taskId] = updatedTask;

    final logTaskUpdate = isProgressUpdate ? AppLogger.t : AppLogger.d;
    logTaskUpdate(
      '下载任务更新: ${updatedTask.fileName}, '
      'status=${updatedTask.status}, '
      'bytes=${updatedTask.downloadedBytes}/${updatedTask.fileSize}, '
      'progress=${updatedTask.progressText}, '
      'speed=${updatedTask.speedText}',
    );

    final shouldPersistNow =
        effectiveStatus != DownloadStatus.downloading ||
        _shouldPersistProgress(now, updatedTask);

    if (shouldPersistNow) {
      // 非下载中（终态/暂停/重置）整行写库；下载中走节流字段更新
      if (effectiveStatus == DownloadStatus.downloading) {
        _scheduleThrottleWrite(updatedTask);
      } else {
        await _persistTask(updatedTask);
      }
      _lastProgressPersistTime = now;
    } else {
      // 节流窗口内的进度更新也走节流写库
      if (effectiveStatus == DownloadStatus.downloading) {
        _scheduleThrottleWrite(updatedTask);
      }
    }

    notifyListeners();
  }

  int? _completedFileSize(DownloadTaskModel task) {
    try {
      final file = File(task.savePath);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (_) {}
    return null;
  }

  bool _shouldPersistProgress(DateTime now, DownloadTaskModel task) {
    final last = _lastProgressPersistTime;
    if (last == null) return true;

    final isArchiveDownload = task.downloadUrl?.contains('/archive/') == true;
    final interval = isArchiveDownload ? 30 : 2;
    return now.difference(last).inSeconds >= interval;
  }

  void _ensureActiveDownloadSampler() {
    _activeDownloadSampler ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sampleLocalActiveDownloadProgress(),
    );
  }

  Future<void> _sampleLocalActiveDownloadProgress() async {
    if (_isSamplingLocalProgress) return;
    _isSamplingLocalProgress = true;

    try {
      final now = DateTime.now();
      var changed = false;
      var shouldPersist = false;

      for (final entry in _tasks.entries.toList()) {
        final taskId = entry.key;
        final task = entry.value;
        final isActive = task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.archiving ||
            task.status == DownloadStatus.waiting;

        if (!isActive) continue;

        final localBytes = await _readLocalDownloadedBytes(task);
        if (localBytes == null || localBytes <= task.downloadedBytes) {
          continue;
        }

        final lastTime = _lastProgressTime[taskId];
        final lastBytes = _lastProgressBytes[taskId] ?? task.downloadedBytes;
        var speed = task.speed;

        if (lastTime != null) {
          final elapsedMs = now.difference(lastTime).inMilliseconds;
          final bytesDelta = localBytes - lastBytes;
          if (elapsedMs >= 300 && bytesDelta > 0) {
            speed = (bytesDelta * 1000 / elapsedMs).round();
          }
        }

        _lastProgressTime[taskId] = now;
        _lastProgressBytes[taskId] = localBytes;

        var nextStatus = task.status;
        if (task.status == DownloadStatus.waiting && !task.waitingForWifi) {
          nextStatus = DownloadStatus.downloading;
        }

        _tasks[taskId] = task.copyWith(
          status: nextStatus,
          downloadedBytes: task.fileSize > 0 && localBytes > task.fileSize
              ? task.fileSize
              : localBytes,
          speed: speed,
          waitingForWifi: false,
        );

        changed = true;
        shouldPersist = shouldPersist || _shouldPersistProgress(now, _tasks[taskId]!);
      }

      if (changed) {
        if (shouldPersist) {
          // 批量节流写库：把所有 changed 的活跃任务加入缓冲
          for (final entry in _tasks.entries) {
            if (entry.value.status == DownloadStatus.downloading ||
                entry.value.status == DownloadStatus.archiving ||
                entry.value.status == DownloadStatus.waiting) {
              _runtimeTaskBuffer[entry.key] = entry.value;
            }
          }
          _throttleWriteTimer?.cancel();
          await _flushRuntimeTaskBuffer();
          _lastProgressPersistTime = now;
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.d('本地采样下载进度失败: $e');
    } finally {
      _isSamplingLocalProgress = false;
    }
  }

  Future<int?> _readLocalDownloadedBytes(DownloadTaskModel task) async {
    final candidates = <String>{
      task.savePath,
      '${task.savePath}.part',
      '${task.savePath}.tmp',
      '${task.savePath}.download',
    };

    final file = File(task.savePath);
    final dir = file.parent;
    final name = file.path.split(Platform.pathSeparator).last;

    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final entityName = entity.path.split(Platform.pathSeparator).last;
          if (entityName == name ||
              entityName == '$name.part' ||
              entityName == '$name.tmp' ||
              entityName.startsWith('$name.')) {
            candidates.add(entity.path);
          }
        }
      }
    } catch (_) {}

    var best = 0;
    for (final path in candidates) {
      try {
        final f = File(path);
        if (await f.exists()) {
          final length = await f.length();
          if (length > best) best = length;
        }
      } catch (_) {}
    }

    return best > 0 ? best : null;
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      _resumeBaseBytes[taskId] = task.downloadedBytes;
      _lastProgressTime[taskId] = DateTime.now();
      _lastProgressBytes[taskId] = task.downloadedBytes;

      _tasks[taskId] = task.copyWith(
        status: DownloadStatus.waiting,
        speed: 0,
        waitingForWifi: false,
      );
      await _persistTask(_tasks[taskId]!);
      notifyListeners();

      await _downloadService.resumeDownload(taskId);
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    await _downloadService.pauseDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        _resumeBaseBytes[taskId] = task.downloadedBytes;
        _tasks[taskId] = task.copyWith(
          status: DownloadStatus.paused,
          speed: 0,
          waitingForWifi: false,
        );
        _lastProgressTime.remove(taskId);
        _lastProgressBytes.remove(taskId);
        await _persistTask(_tasks[taskId]!);
        notifyListeners();
      }
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    await _downloadService.cancelDownload(taskId);

    final task = _tasks[taskId];
    if (task != null) {
      _resumeBaseBytes.remove(taskId);
      _tasks[taskId] = task.copyWith(
        status: DownloadStatus.cancelled,
        waitingForWifi: false,
      );
      await _persistTask(_tasks[taskId]!);
      notifyListeners();

      // 延迟移除任务，同时从数据库删除
      Future.delayed(const Duration(seconds: 2), () {
        _tasks.remove(taskId);
        _runtimeTaskBuffer.remove(taskId);
        _downloadService.disposeTask(taskId);
        _deleteTask(taskId);
        notifyListeners();
      });
    }
  }

  /// 删除下载任务
  Future<void> deleteDownloadTask(
    String taskId, {
    bool deleteLocalFile = false,
  }) async {
    final task = _tasks[taskId];
    if (task != null) {
      if (deleteLocalFile) {
        await _downloadService.deleteDownloadedFile(task.savePath);
      }

      _resumeBaseBytes.remove(taskId);
      _tasks.remove(taskId);
      _runtimeTaskBuffer.remove(taskId);
      _downloadService.disposeTask(taskId);
      await _deleteTask(taskId);
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
      _resumeBaseBytes.remove(taskId);
      _lastProgressTime.remove(taskId);
      _lastProgressBytes.remove(taskId);
      await _persistTask(_tasks[taskId]!);
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
      _resumeBaseBytes.remove(task.id);
      _runtimeTaskBuffer.remove(task.id);
      _tasks.remove(task.id);
      _downloadService.disposeTask(task.id);
      await _deleteTask(task.id);
    }
    notifyListeners();
  }

  /// 获取任务
  DownloadTaskModel? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// 从数据库加载未完成的下载任务（启动恢复）
  ///
  /// 只加载 waiting/downloading/paused/archiving 状态的任务。
  /// completed/failed/cancelled 任务保留在数据库中，UI 通过 StreamBuilder 分页按需加载。
  Future<void> _loadTasks() async {
    try {
      final entries = await TaskDatabase.instance.queryActiveDownloadTasks();
      final loadedTasks = <DownloadTaskModel>[];

      final now = DateTime.now();
      for (final entry in entries) {
        try {
          final task = DownloadTaskModel.fromEntry(entry);
          // 过滤掉已取消的任务（与原逻辑一致）
          if (task.status == DownloadStatus.cancelled) {
            continue;
          }

          // 如果任务已完成，只保留配置天数内的记录
          if (task.status == DownloadStatus.completed) {
            if (task.completedAt == null) continue;
            final retentionDays =
                await StorageService.instance.getInt(
                  StorageKeys.taskRetentionDays,
                ) ??
                7;
            if (retentionDays > 0) {
              final daysSinceCompletion = now
                  .difference(task.completedAt!)
                  .inDays;
              if (daysSinceCompletion > retentionDays) {
                AppLogger.d('跳过超过$retentionDays天的已完成任务: ${task.fileName}');
                continue;
              }
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

      AppLogger.d('从数据库加载了 ${loadedTasks.length} 个下载任务');

      // 通知 UI 更新
      if (loadedTasks.isNotEmpty) {
        notifyListeners();
      }

      // 恢复未完成的任务
      for (final task in loadedTasks) {
        if (task.status == DownloadStatus.archiving ||
            task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.waiting) {
          AppLogger.d('恢复下载任务: ${task.fileName}');
          _resumeBaseBytes[task.id] = task.downloadedBytes;
          _lastProgressTime[task.id] = DateTime.now();
          _lastProgressBytes[task.id] = task.downloadedBytes;
          // 使用 resumeDownloadAfterRestart 支持断点续传
          await _downloadService.resumeDownloadAfterRestart(task);
        } else if (task.status == DownloadStatus.paused) {
          // 暂停的任务需要重建 bdTasks 映射，以便继续下载
          AppLogger.d('重建暂停任务映射: ${task.fileName}');
          _resumeBaseBytes[task.id] = task.downloadedBytes;
          await _downloadService.resumeDownloadAfterRestart(task);
          // 重建映射后立即暂停，保持任务在暂停状态
          await _downloadService.pauseDownload(task.id);
        }
      }
    } catch (e) {
      AppLogger.d('加载下载任务失败: $e');
    }
  }

  /// 整行持久化任务（用于新增/状态变更/移除）
  Future<void> _persistTask(DownloadTaskModel task) async {
    try {
      await TaskDatabase.instance.upsertDownloadTask(task.toCompanion());
    } catch (e) {
      AppLogger.d('持久化下载任务失败: $e');
    }
  }

  /// 删除任务记录
  Future<void> _deleteTask(String taskId) async {
    try {
      await TaskDatabase.instance.deleteDownloadTask(taskId);
    } catch (e) {
      AppLogger.d('删除下载任务记录失败: $e');
    }
  }

  /// 节流写库：更新进度字段（downloadedBytes/speed/updatedAt）
  void _scheduleThrottleWrite(DownloadTaskModel task) {
    _runtimeTaskBuffer[task.id] = task;
    _throttleWriteTimer?.cancel();
    _throttleWriteTimer = Timer(const Duration(milliseconds: 500), () {
      _flushRuntimeTaskBuffer();
    });
  }

  Future<void> _flushRuntimeTaskBuffer() async {
    if (_runtimeTaskBuffer.isEmpty) return;
    _throttleWriteTimer?.cancel();
    _throttleWriteTimer = null;
    final buffer = Map<String, DownloadTaskModel>.from(_runtimeTaskBuffer);
    _runtimeTaskBuffer.clear();
    final now = DateTime.now().toIso8601String();
    for (final task in buffer.values) {
      try {
        await TaskDatabase.instance.updateDownloadTaskFields(
          task.id,
          downloadedBytes: task.downloadedBytes,
          speed: task.speed,
          fileSize: task.fileSize,
          updatedAt: now,
        );
      } catch (e) {
        AppLogger.d('节流写库失败 task=${task.id}: $e');
      }
    }
  }

  @override
  void dispose() {
    _activeDownloadSampler?.cancel();
    _activeDownloadSampler = null;
    _throttleWriteTimer?.cancel();
    _throttleWriteTimer = null;
    _runtimeTaskBuffer.clear();
    _lastProgressTime.clear();
    _lastProgressBytes.clear();
    _downloadService.dispose();
    super.dispose();
  }
}
