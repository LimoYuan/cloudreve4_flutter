import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../core/constants/storage_keys.dart';
import '../core/utils/app_logger.dart';
import '../data/models/upload_task_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'upload_foreground_service.dart';
import 'native_content_reader.dart';

/// 上传服务 - 单例模式
///
/// 重点修复：
/// 1. OneDrive / SharePoint 上传不再走 remote slave 的 ?chunk= 逻辑；
/// 2. OneDrive 使用 upload_urls[0] + PUT + Content-Range；
/// 3. OneDrive 上传完成后通知 Cloudreve callback；
/// 4. 保留 local / relay / remote slave 原有上传路径；
/// 5. 增加真实 Dio 响应日志，便于继续定位 400。
class UploadService extends ChangeNotifier {
  UploadService._internal() : super();

  factory UploadService() => instance;

  static UploadService? _instance;
  static UploadService get instance {
    _instance ??= UploadService._internal();
    return _instance!;
  }

  final Map<String, UploadTaskModel> _tasks = {};

  /// 上传完成回调：参数为 (目标路径, 文件名)
  void Function(String targetPath, String fileName)? onUploadCompleted;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, _SpeedTracker> _speedTrackers = {};

  /// 用户请求“暂停”的任务。
  ///
  /// 暂停不同于取消：不能立即 cancel 当前 PUT 请求，否则 OneDrive 会丢弃当前
  /// fragment，恢复时就会回退到上一个已提交分片，看起来像“从头/低进度重来”。
  ///
  /// 所以暂停采用“安全暂停”：当前分片传完后，在下一个分片前停住。
  final Set<String> _pauseRequestedTaskIds = <String>{};

  /// 添加任务
  void addTask(UploadTaskModel task) {
    _tasks[task.id] = task;
    if (!_progressControllers.containsKey(task.id)) {
      _progressControllers[task.id] = StreamController<double>.broadcast();
    }
    AppLogger.d('UploadTaskModel -> addTask > ${task.toJson()}');
    _saveTasks();
    notifyListeners();
    _syncForegroundNotification();
  }

  /// 更新任务
  void updateTask(UploadTaskModel task) {
    if (_tasks.containsKey(task.id)) {
      _tasks[task.id] = task;
      _saveTasks();
      notifyListeners();
      _syncForegroundNotification();
    }
  }

  /// 仅更新运行时进度，不频繁写入本地存储。
  void _updateRuntimeTask(UploadTaskModel task) {
    if (_tasks.containsKey(task.id)) {
      _tasks[task.id] = task;
      notifyListeners();
      _syncForegroundNotification();
    }
  }

  void _syncForegroundNotification() {
    unawaited(UploadForegroundService.syncWithTasks(_tasks.values.toList()));
  }

  /// 获取任务
  UploadTaskModel? getTask(String id) => _tasks[id];

  /// 获取所有任务
  List<UploadTaskModel> get allTasks => _tasks.values.toList();

  /// 获取进行中的任务
  List<UploadTaskModel> get activeTasks => _tasks.values
      .where(
        (t) =>
            t.status == UploadStatus.uploading ||
            t.status == UploadStatus.waiting ||
            t.status == UploadStatus.paused,
      )
      .toList();

  /// 移除任务
  void removeTask(String id) {
    final task = _tasks[id];

    // 失败/取消/未完成的上传任务如果已经创建了 Cloudreve 上传会话，
    // 需要显式删除会话释放 Cloudreve 侧的上传锁，否则文件列表中可能残留
    // 正在上传的占位文件，删除时出现 Lock conflict (code: 40073)。
    if (task != null && task.session != null && task.status != UploadStatus.completed) {
      unawaited(_deleteUploadSessionForTask(task));
    }

    _tasks.remove(id);
    _pauseRequestedTaskIds.remove(id);
    _cancelTokens.remove(id);
    final controller = _progressControllers.remove(id);
    controller?.close();
    _speedTrackers.remove(id);
    _saveTasks();
    notifyListeners();
    _syncForegroundNotification();
  }

  /// 获取上传进度流
  Stream<double> getProgressStream(String taskId) {
    if (!_progressControllers.containsKey(taskId)) {
      _progressControllers[taskId] = StreamController<double>.broadcast();
    }
    return _progressControllers[taskId]!.stream;
  }

  /// 清除所有任务
  void clearAllTasks() {
    for (final task in _tasks.values) {
      if (task.session != null && task.status != UploadStatus.completed) {
        unawaited(_deleteUploadSessionForTask(task));
      }
    }

    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _tasks.clear();
    _pauseRequestedTaskIds.clear();
    _cancelTokens.clear();
    _progressControllers.clear();
    _speedTrackers.clear();
    _saveTasks();
    notifyListeners();
    _syncForegroundNotification();
  }

  /// 清除已完成的任务
  void clearCompletedTasks() {
    final completedIds = _tasks.values
        .where(
          (t) =>
              t.status == UploadStatus.completed ||
              t.status == UploadStatus.cancelled,
        )
        .map((t) => t.id)
        .toList();

    for (final id in completedIds) {
      removeTask(id);
    }
    _saveTasks();
  }

  /// 清除失败的任务
  void clearFailedTasks() {
    final failedIds = _tasks.values
        .where((t) => t.status == UploadStatus.failed)
        .map((t) => t.id)
        .toList();

    for (final id in failedIds) {
      removeTask(id);
    }
    _saveTasks();
  }

  /// 初始化上传服务
  Future<void> initialize() async {
    await _loadTasks();
  }

  /// 从本地存储加载上传任务
  Future<void> _loadTasks() async {
    try {
      final tasksJson = await StorageService.instance.getString(
        StorageKeys.uploadTasks,
      );
      if (tasksJson == null || tasksJson.isEmpty) {
        AppLogger.d('没有保存的上传任务');
        return;
      }

      final tasksList = jsonDecode(tasksJson) as List<dynamic>;
      final loadedTasks = <UploadTaskModel>[];

      final now = DateTime.now();
      for (final taskJson in tasksList) {
        try {
          final task = UploadTaskModel.fromJson(
            taskJson as Map<String, dynamic>,
          );

          // 检查文件是否存在。
          // Android content:// 来源不依赖本地 File 路径，不能用 File.exists() 判断。
          if (!task.usesContentUri && !await task.file.exists()) {
            AppLogger.d('上传任务文件不存在，跳过: ${task.fileName}');
            continue;
          }

          // 过滤掉已取消的任务
          if (task.status == UploadStatus.cancelled) {
            continue;
          }

          // 如果任务已完成，只保留配置天数内的记录
          if (task.status == UploadStatus.completed) {
            if (task.completedAt == null) {
              continue;
            }
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

          // 对于未完成的任务，重置状态为等待（因为应用关闭后上传已停止）
          if (task.status == UploadStatus.uploading ||
              task.status == UploadStatus.waiting) {
            loadedTasks.add(
              task.copyWith(
                status: UploadStatus.waiting,
                uploadedBytes: 0,
                progress: 0,
                uploadedChunks: 0,
                errorMessage: null,
                speed: 0,
              ),
            );
          } else {
            loadedTasks.add(task);
          }
        } catch (e) {
          AppLogger.d('解析上传任务失败: $e');
        }
      }

      // 将加载的任务添加到当前任务列表
      for (final task in loadedTasks) {
        _tasks[task.id] = task;
        if (!_progressControllers.containsKey(task.id)) {
          _progressControllers[task.id] = StreamController<double>.broadcast();
        }
      }

      AppLogger.d('从存储加载了 ${loadedTasks.length} 个上传任务');

      // 通知 UI 更新
      if (loadedTasks.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      AppLogger.d('加载上传任务失败: $e');
    }
  }

  /// 保存上传任务到本地存储
  Future<void> _saveTasks() async {
    try {
      final tasksList = _tasks.values.map((task) => task.toJson()).toList();
      final tasksJson = jsonEncode(tasksList);
      await StorageService.instance.setString(
        StorageKeys.uploadTasks,
        tasksJson,
      );
      AppLogger.d('已保存 ${_tasks.length} 个上传任务到存储');
    } catch (e) {
      AppLogger.d('保存上传任务失败: $e');
    }
  }

  /// 暂停上传
  ///
  /// 暂停只中断当前网络请求，不删除 Cloudreve 上传会话。
  /// OneDrive / SharePoint 恢复时可复用 upload session 续传；
  /// 其他策略由 retryUpload 按已有规则处理。
  void pauseUpload(String taskId) {
    final task = _tasks[taskId];
    if (task == null ||
        task.status == UploadStatus.completed ||
        task.status == UploadStatus.cancelled) {
      return;
    }

    // 不 cancel 当前请求。OneDrive 对中断的 PUT fragment 不做部分提交，
    // 立即取消会导致恢复时回退到上一个 committed range。
    // 这里仅标记“请求暂停”，让当前 chunk 完整提交后再停。
    _pauseRequestedTaskIds.add(taskId);

    updateTask(task.copyWith(status: UploadStatus.paused, speed: 0));
    _cleanSpeedTracker(taskId);
  }

  /// 取消上传
  void cancelUpload(String taskId) {
    _pauseRequestedTaskIds.remove(taskId);
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('上传已取消');
    }

    final task = _tasks[taskId];
    if (task != null) {
      if (task.session != null) {
        unawaited(_deleteUploadSessionForTask(task));
      }
      updateTask(task.copyWith(status: UploadStatus.cancelled, speed: 0));
      _cleanSpeedTracker(taskId);
    }
  }

  /// 重试上传
  Future<void> retryUpload(String taskId) async {
    _pauseRequestedTaskIds.remove(taskId);
    final task = _tasks[taskId];
    if (task == null) return;

    // 如果失败任务保留了仍有效的 OneDrive 上传会话，继续使用它；
    // 这样可以利用 OneDrive upload session 的 nextExpectedRanges 机制续传。
    // 非 OneDrive 策略没有统一的已上传分片查询接口，重试时重新创建会话更稳。
    var taskForRetry = task;
    if (task.session != null &&
        (!task.session!._isOneDriveUpload || _isUploadSessionExpired(task.session!))) {
      await _deleteUploadSessionForTask(task);
      taskForRetry = task.copyWith(session: null);
    }

    // 重置任务状态
    final resetTask = taskForRetry.copyWith(
      status: UploadStatus.waiting,
      uploadedBytes: taskForRetry.session?._isOneDriveUpload == true
          ? taskForRetry.uploadedBytes
          : 0,
      progress: taskForRetry.session?._isOneDriveUpload == true
          ? taskForRetry.progress
          : 0,
      uploadedChunks: taskForRetry.session?._isOneDriveUpload == true
          ? taskForRetry.uploadedChunks
          : 0,
      errorMessage: null,
      speed: 0,
    );

    updateTask(resetTask);

    // 开始上传
    await startUpload(resetTask);
  }

  /// 开始上传
  Future<void> startUpload(UploadTaskModel task) async {
    _pauseRequestedTaskIds.remove(task.id);
    AppLogger.d('UploadService.startUpload: 开始上传任务 ${task.fileName}');
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      // 步骤1：创建或复用上传会话。
      // OneDrive upload session 本身支持查询 nextExpectedRanges，失败重试时可以复用会话。
      UploadSessionModel session;
      if (task.session != null &&
          task.session!._isOneDriveUpload &&
          !_isUploadSessionExpired(task.session!)) {
        session = task.session!;
        AppLogger.d(
          'UploadService.startUpload: 复用 OneDrive 上传会话，'
          'sessionId=${session.sessionId}',
        );
      } else {
        if (task.session != null && task.status != UploadStatus.completed) {
          await _deleteUploadSessionForTask(task);
        }

        AppLogger.d('UploadService.startUpload: 创建上传会话...');
        session = await _createUploadSession(task);
      }

      AppLogger.d(
        'UploadService.startUpload: 上传会话准备完成，'
        'sessionId=${session.sessionId}, '
        'chunkSize=${session.chunkSize}, '
        'policy=${session._policyType}, '
        'relay=${session.storagePolicy.relay}, '
        'uploadUrls=${session.uploadUrls?.length ?? 0}, '
        'completeUrl=${session.completeUrl}, '
        'callbackSecret=${session.callbackSecret != null && session.callbackSecret!.isNotEmpty}',
      );

      // 更新任务，添加会话信息
      final effectiveChunkSize = _effectiveChunkSize(
        session: session,
        fileSize: task.fileSize,
        usesContentUri: task.usesContentUri,
      );
      final updatedTask = task.copyWith(
        session: session,
        totalChunks: task.calculateTotalChunks(effectiveChunkSize),
        status: UploadStatus.uploading,
        errorMessage: null,
        speed: 0,
      );
      updateTask(updatedTask);

      // 步骤2：上传文件
      await _uploadFile(updatedTask, cancelToken);

      // 上传完成
      final completedTask = updatedTask.copyWith(
        status: UploadStatus.completed,
        progress: 1.0,
        uploadedBytes: task.fileSize,
        uploadedChunks: updatedTask.totalChunks,
        completedAt: DateTime.now(),
        speed: 0,
      );
      updateTask(completedTask);
      _cleanSpeedTracker(task.id);
      unawaited(_clearPickerTemporaryFiles());

      onUploadCompleted?.call(task.targetPath, task.fileName);

      _emitProgress(task.id, 1.0);

      if (activeTasks.isEmpty) {
        unawaited(
          UploadForegroundService.showFinishedThenStop(
            title: 'Cloudreve 上传完成',
            text: task.fileName,
          ),
        );
      }
    } catch (e) {
      _logUploadException(e, task.fileName);

      final isPaused = _isPausedCancel(e);
      final isCancelled =
          e is DioException && e.type == DioExceptionType.cancel && !isPaused;

      final latestTask = getTask(task.id) ?? task;

      if (isCancelled || (!isPaused && _shouldDeleteUploadSessionAfterFailure(e))) {
        await _deleteUploadSessionForTask(latestTask);
      }

      updateTask(
        latestTask.copyWith(
          status: isPaused
              ? UploadStatus.paused
              : isCancelled
                  ? UploadStatus.cancelled
                  : UploadStatus.failed,
          errorMessage: isPaused ? null : _formatUploadError(e),
          speed: 0,
        ),
      );
      _cleanSpeedTracker(task.id);

      if (isCancelled || (!isPaused && _shouldDeleteUploadSessionAfterFailure(e))) {
        unawaited(_clearPickerTemporaryFiles());
      }

      if (!isCancelled && !isPaused) {
        _emitProgress(task.id, latestTask.progress);
      }

      if (activeTasks.where((t) => t.status != UploadStatus.paused).isEmpty) {
        unawaited(
          UploadForegroundService.showFinishedThenStop(
            title: isPaused
                ? 'Cloudreve 上传已暂停'
                : isCancelled
                    ? 'Cloudreve 上传已取消'
                    : 'Cloudreve 上传失败',
            text: task.fileName,
          ),
        );
      }
    }
  }

  /// 创建上传会话
  Future<UploadSessionModel> _createUploadSession(UploadTaskModel task) async {
    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/file/upload',
      data: {
        'uri': task.targetPath.endsWith('/')
            ? '${task.targetPath}${task.fileName}'
            : '${task.targetPath}/${task.fileName}',
        'size': task.fileSize,
      },
    );

    // ApiService._parseResponse 已经解析出 response.data，这里直接使用 response。
    final Map<String, dynamic> sessionData = response;
    AppLogger.d('UPLOAD_SESSION_JSON: ${jsonEncode(sessionData)}');
    return UploadSessionModel.fromJson(sessionData);
  }

  /// 上传文件（支持分片上传）
  ///
  /// 关键点：
  /// - Android content:// 文件走原生 ContentResolver 按 offset/length 读取；
  /// - 普通文件路径走 RandomAccessFile；
  /// - 全程不使用 file.readAsBytes()，避免大文件 OOM；
  /// - 每次只读取当前 chunk 到内存。
  Future<void> _uploadFile(
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    final session = task.session!;

    AppLogger.d(
      '开始上传 -> ${task.fileName}, '
      'usesContentUri=${task.usesContentUri}, sourceUri=${task.sourceUri}',
    );

    final totalSize = task.fileSize;

    if (totalSize == 0 && session._isOneDriveUpload) {
      throw Exception('OneDrive 不支持通过上传会话上传空文件，请换一个非空文件测试');
    }

    final chunkSize = _effectiveChunkSize(
      session: session,
      fileSize: totalSize,
      usesContentUri: task.usesContentUri,
    );

    await _uploadMultipart(totalSize, chunkSize, task, cancelToken);
  }

  int _effectiveChunkSize({
    required UploadSessionModel session,
    required int fileSize,
    bool usesContentUri = false,
  }) {
    if (fileSize <= 0) return 1;

    if (session._isOneDriveUpload) {
      final serverChunkSize = session.chunkSize > 0 ? session.chunkSize : fileSize;
      final clientChunkSize = _adaptiveOneDriveChunkSize(
        fileSize: fileSize,
        usesContentUri: usesContentUri,
      );

      return math.min(
        fileSize,
        math.min(serverChunkSize, clientChunkSize),
      );
    }

    if (session.chunkSize > 0) {
      // local/relay/remote/S3-like 策略先遵循 Cloudreve 会话返回的 chunk_size，
      // 避免破坏服务端对分片索引和预签名 URL 数量的假设。
      return session.chunkSize;
    }

    return math.min(fileSize, 10 * 1024 * 1024);
  }

  int _adaptiveOneDriveChunkSize({
    required int fileSize,
    required bool usesContentUri,
  }) {
    // OneDrive upload session 的非最后分片需要是 320 KiB 的整数倍。
    // 这里的候选值全部满足：5/10/20/40 MiB 都是 320 KiB 的整数倍。
    const fiveMiB = 5 * 1024 * 1024;
    const tenMiB = 10 * 1024 * 1024;
    const twentyMiB = 20 * 1024 * 1024;
    const fortyMiB = 40 * 1024 * 1024;

    // Android content:// 走 MethodChannel 时会有一次跨通道编码开销，
    // 不能直接使用 Cloudreve 返回的 100 MiB，否则容易 OOM。
    //
    // 但固定 5 MiB 会让大文件分片太多，速度明显下降。
    // 所以按文件大小自适应：
    // - 小文件：5 MiB，低内存压力；
    // - 中大文件：10/20 MiB，减少请求次数；
    // - 非 content:// 本地路径：可用 40 MiB。
    if (usesContentUri) {
      if (fileSize >= 512 * 1024 * 1024) return twentyMiB;
      if (fileSize >= 128 * 1024 * 1024) return tenMiB;
      return fiveMiB;
    }

    if (fileSize >= 1024 * 1024 * 1024) return fortyMiB;
    if (fileSize >= 256 * 1024 * 1024) return twentyMiB;
    if (fileSize >= 64 * 1024 * 1024) return tenMiB;
    return fiveMiB;
  }

  /// 分片上传
  Future<void> _uploadMultipart(
    int totalSize,
    int chunkSize,
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    final session = task.session!;
    final totalChunks = totalSize == 0 ? 1 : (totalSize / chunkSize).ceil();
    final completedParts = <Map<String, dynamic>>[];

    var resumeStart = 0;

    // OneDrive / SharePoint 支持通过 upload session 查询 nextExpectedRanges。
    // 暂停/失败后恢复时，不能盲目从 chunk 0 开始，否则看起来像“没有断点续传”，
    // 甚至可能触发 fragmentOverlap。这里在进入循环前先拿服务端真实续传点。
    if (session._isOneDriveUpload && task.uploadedBytes > 0) {
      final urls = session.uploadUrls ?? const <String>[];
      if (urls.isNotEmpty) {
        try {
          final dio = _buildRawUploadDio();
          resumeStart = await _queryOneDriveNextExpectedStart(
            dio: dio,
            uploadUrl: urls.first,
            cancelToken: cancelToken,
          );

          if (resumeStart < 0) resumeStart = 0;
          if (resumeStart > totalSize) resumeStart = totalSize;

          AppLogger.d(
            'OneDrive resume point resolved: $resumeStart/$totalSize, '
            'previousLocalProgress=${task.uploadedBytes}/$totalSize',
          );

          if (resumeStart > 0) {
            final progress = totalSize == 0 ? 1.0 : resumeStart / totalSize;
            final currentTask = getTask(task.id) ?? task;
            updateTask(
              currentTask.copyWith(
                uploadedBytes: resumeStart,
                progress: progress,
                uploadedChunks: math.min(totalChunks, resumeStart ~/ chunkSize),
                speed: 0,
              ),
            );
            _emitProgress(task.id, progress);
          }
        } catch (e) {
          // 查询续传点失败时，不直接失败；保守使用本地记录。
          // 如果本地记录过高，OneDrive 后续可能返回 fragmentOverlap，再由现有逻辑处理。
          resumeStart = math.min(task.uploadedBytes, totalSize);
          AppLogger.d(
            'Query OneDrive resume point failed, fallback to local uploadedBytes=$resumeStart: $e',
          );
        }
      }
    }

    RandomAccessFile? raf;

    try {
      if (!task.usesContentUri) {
        raf = await task.file.open(mode: FileMode.read);
      }

      final startIndex = chunkSize <= 0 ? 0 : resumeStart ~/ chunkSize;

      for (int i = startIndex; i < totalChunks; i++) {
        if (cancelToken.isCancelled) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
            error: '上传已取消',
          );
        }

        if (_pauseRequestedTaskIds.contains(task.id)) {
          _pauseRequestedTaskIds.remove(task.id);
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
            error: '上传已暂停',
          );
        }

        final chunkStart = i * chunkSize;
        final start = math.max(chunkStart, resumeStart);
        final endExclusive = math.min(chunkStart + chunkSize, totalSize);

        if (start >= endExclusive) {
          continue;
        }

        final bytesToRead = math.max(0, endExclusive - start);

        AppLogger.d(
          'Uploading chunk ${i + 1}/$totalChunks for ${task.fileName}, '
          'policy=${session._policyType}, relay=${session.isRelayUpload}, '
          'range=$start-${endExclusive - 1}/$totalSize, '
          'chunkSize=$bytesToRead, '
          'source=${task.usesContentUri ? 'contentUri' : 'file'}, '
          'resumeStart=$resumeStart',
        );

        DateTime lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);

        void handleChunkProgress(int sent, int total) {
          final now = DateTime.now();
          final isFinalProgress = sent >= total || sent >= bytesToRead;
          if (!isFinalProgress &&
              now.difference(lastProgressUpdate).inMilliseconds < 500) {
            return;
          }
          lastProgressUpdate = now;

          final uploadedBytes = math.min(start + sent, endExclusive);
          final progress = totalSize == 0 ? 1.0 : uploadedBytes / totalSize;
          final speed = _computeSpeed(task.id, uploadedBytes);
          final currentTask = getTask(task.id) ?? task;

          _updateRuntimeTask(
            currentTask.copyWith(
              uploadedBytes: uploadedBytes,
              progress: progress,
              uploadedChunks: i,
              speed: speed,
            ),
          );
          _emitProgress(task.id, progress);
        }

        Map<String, dynamic>? partInfo;

        // Android content:// + OneDrive/SharePoint：直接让 Kotlin 读取 ContentResolver
        // 并使用 Android 原生 HttpURLConnection PUT 到 upload session。
        // 不再把 chunk bytes 经 MethodChannel 传回 Dart，也不再由 Dio 直传。
        if (task.usesContentUri && session._isOneDriveUpload) {
          await _uploadOneDriveChunkNative(
            task: task,
            index: i,
            start: start,
            endExclusive: endExclusive,
            totalSize: totalSize,
            session: session,
            cancelToken: cancelToken,
            onProgress: handleChunkProgress,
          );
        } else {
          final chunkData = await _readUploadChunk(
            task: task,
            raf: raf,
            start: start,
            length: bytesToRead,
          );

          if (chunkData.length != bytesToRead) {
            throw Exception(
              '读取文件分片失败：期望 $bytesToRead bytes，实际 ${chunkData.length} bytes',
            );
          }

          partInfo = await _uploadChunk(
            chunkData: chunkData,
            index: i,
            start: start,
            endExclusive: endExclusive,
            totalSize: totalSize,
            session: session,
            cancelToken: cancelToken,
            onProgress: handleChunkProgress,
          );
        }

        if (partInfo != null) {
          completedParts.add(partInfo);
        }

        final currentTask = getTask(task.id) ?? task;
        final uploadedBytes = endExclusive;
        final progress = totalSize == 0 ? 1.0 : uploadedBytes / totalSize;
        final speed = _computeSpeed(task.id, uploadedBytes);
        updateTask(
          currentTask.copyWith(
            uploadedBytes: uploadedBytes,
            progress: progress,
            uploadedChunks: i + 1,
            speed: speed,
          ),
        );
        _emitProgress(task.id, progress);

        // 安全暂停：当前 chunk 已经完整提交后再停。
        // 这样恢复时 OneDrive nextExpectedRanges 会指向最新提交点，
        // 不会从 1.5% 之类的旧进度重新开始。
        if (_pauseRequestedTaskIds.contains(task.id)) {
          _pauseRequestedTaskIds.remove(task.id);
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
            error: '上传已暂停',
          );
        }
      }
    } finally {
      await raf?.close();
    }

    await _completeUploadIfNeeded(session, completedParts);
  }

  Future<Uint8List> _readUploadChunk({
    required UploadTaskModel task,
    required RandomAccessFile? raf,
    required int start,
    required int length,
  }) async {
    if (length <= 0) return Uint8List(0);

    if (task.usesContentUri) {
      try {
        return await NativeContentReader.instance.readChunk(
          uri: task.sourceUri!,
          offset: start,
          length: length,
        );
      } catch (e) {
        AppLogger.d('ContentResolver 读取失败，尝试 fallback 到本地缓存路径: $e');

        // 如果 file_picker 同时提供了缓存路径，则 fallback 到缓存文件。
        if (await task.file.exists()) {
          final fallback = await task.file.open(mode: FileMode.read);
          try {
            await fallback.setPosition(start);
            return Uint8List.fromList(await fallback.read(length));
          } finally {
            await fallback.close();
          }
        }

        rethrow;
      }
    }

    final file = raf;
    if (file == null) {
      throw Exception('文件读取器未初始化');
    }

    await file.setPosition(start);
    return Uint8List.fromList(await file.read(length));
  }

  /// 根据存储策略上传单个分片。
  Future<Map<String, dynamic>?> _uploadChunk({
    required List<int> chunkData,
    required int index,
    required int start,
    required int endExclusive,
    required int totalSize,
    required UploadSessionModel session,
    required CancelToken cancelToken,
    void Function(int, int)? onProgress,
  }) async {
    if (session.isRelayUpload) {
      await _uploadChunkToRelay(
        chunkData,
        index,
        session.sessionId,
        cancelToken,
        onProgress,
      );
      return null;
    }

    if (session._isOneDriveUpload) {
      await _uploadChunkToOneDrive(
        chunkData: chunkData,
        index: index,
        start: start,
        endExclusive: endExclusive,
        totalSize: totalSize,
        session: session,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
      return null;
    }

    if (session._isRemoteSlaveUpload) {
      await _uploadChunkToRemoteSlave(
        chunkData,
        index,
        session,
        cancelToken,
        onProgress,
      );
      return null;
    }

    // 兜底：S3/OSS/COS/OBS/KS3 等预签名 URL 策略。
    return _uploadChunkToPresignedUrl(
      chunkData,
      index,
      session,
      cancelToken,
      onProgress,
    );
  }

  /// 上传分片到 Cloudreve 中继服务器。
  Future<void> _uploadChunkToRelay(
    List<int> chunkData,
    int index,
    String sessionId,
    CancelToken cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    try {
      final response = await ApiService.instance.dio.post<Map<String, dynamic>>(
        '/file/upload/$sessionId/$index',
        data: _chunkedUploadBodyStream(chunkData),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': chunkData.length.toString(),
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
      );

      _ensureCloudreveSuccess(response.data);
    } catch (e) {
      AppLogger.d('Relay chunk upload failed: ${_formatUploadError(e)}');
      rethrow;
    }
  }

  /// 上传分片到从机/远程存储节点。
  Future<void> _uploadChunkToRemoteSlave(
    List<int> chunkData,
    int index,
    UploadSessionModel session,
    CancelToken cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    final urls = session.uploadUrls ?? [];
    if (urls.isEmpty) {
      throw Exception('没有可用的远程上传 URL');
    }

    final uploadUrl = _appendChunkQuery(urls.first, index);
    final dio = _buildRawUploadDio();

    try {
      final response = await _withUploadRetry<Response<dynamic>>(
        'Remote slave chunk index=$index',
        () => dio.post(
          uploadUrl,
          data: _chunkedUploadBodyStream(chunkData),
          options: Options(
            contentType: 'application/octet-stream',
            headers: {
              'Content-Length': chunkData.length.toString(),
              if (session.credential != null && session.credential!.isNotEmpty)
                'Authorization': session.credential,
            },
          ),
          cancelToken: cancelToken,
          onSendProgress: onProgress,
        ),
        cancelToken: cancelToken,
      );

      AppLogger.d(
        'Remote slave chunk uploaded: index=$index, status=${response.statusCode}',
      );

      _ensureCloudreveSuccess(_asMap(response.data));
    } catch (e) {
      AppLogger.d('Remote slave chunk upload failed: ${_formatUploadError(e)}');
      rethrow;
    }
  }

  /// Android 原生 ContentResolver + HttpURLConnection 上传 OneDrive 分片。
  ///
  /// 这条路径避免：
  /// 1. ContentResolver chunk bytes 经 MethodChannel 回到 Dart；
  /// 2. Dart Dio 直连 OneDrive/SharePoint；
  /// 3. 大分片导致 MethodChannel / Dart 堆内存压力。
  Future<void> _uploadOneDriveChunkNative({
    required UploadTaskModel task,
    required int index,
    required int start,
    required int endExclusive,
    required int totalSize,
    required UploadSessionModel session,
    required CancelToken cancelToken,
    required void Function(int, int) onProgress,
  }) async {
    final urls = session.uploadUrls ?? [];
    if (urls.isEmpty) {
      throw Exception('没有可用的 OneDrive 上传 URL');
    }

    final uploadUrl = urls.first;
    final bytesToRead = math.max(0, endExclusive - start);
    final range = 'bytes $start-${endExclusive - 1}/$totalSize';

    AppLogger.d(
      'Native OneDrive PUT chunk=$index range=$range size=$bytesToRead',
    );

    await _withUploadRetry<void>(
      'Native OneDrive chunk=$index range=$range',
      () async {
        await NativeContentReader.instance.uploadChunkToUrl(
          uri: task.sourceUri!,
          uploadUrl: uploadUrl,
          method: 'PUT',
          offset: start,
          length: bytesToRead,
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytesToRead.toString(),
            'Content-Range': range,
          },
          onProgress: (sent, total) {
            if (cancelToken.isCancelled) return;
            onProgress(sent, total);
          },
        );
      },
      cancelToken: cancelToken,
    );
  }

  /// 上传分片到 OneDrive / SharePoint upload session。
  Future<void> _uploadChunkToOneDrive({
    required List<int> chunkData,
    required int index,
    required int start,
    required int endExclusive,
    required int totalSize,
    required UploadSessionModel session,
    required CancelToken cancelToken,
    void Function(int, int)? onProgress,
  }) async {
    final urls = session.uploadUrls ?? [];
    if (urls.isEmpty) {
      throw Exception('没有可用的 OneDrive 上传 URL');
    }

    final uploadUrl = urls.first;
    final dio = _buildRawUploadDio();

    Future<void> sendRange({
      required List<int> bytes,
      required int rangeStart,
      required int rangeEndExclusive,
      required int progressOffset,
    }) async {
      final range = 'bytes $rangeStart-${rangeEndExclusive - 1}/$totalSize';
      AppLogger.d(
        'OneDrive PUT chunk=$index range=$range size=${bytes.length}',
      );

      await _withUploadRetry<void>(
        'OneDrive chunk=$index range=$range',
        () async {
          await dio.put(
            uploadUrl,
            data: _chunkedUploadBodyStream(bytes),
            options: Options(
              contentType: 'application/octet-stream',
              headers: {
                'Content-Length': bytes.length.toString(),
                'Content-Range': range,
              },
            ),
            cancelToken: cancelToken,
            onSendProgress: onProgress == null
                ? null
                : (sent, total) => onProgress(progressOffset + sent, totalSize),
          );
        },
        cancelToken: cancelToken,
      );
    }

    try {
      await sendRange(
        bytes: chunkData,
        rangeStart: start,
        rangeEndExclusive: endExclusive,
        progressOffset: 0,
      );

      AppLogger.d('OneDrive chunk uploaded: index=$index');
    } on DioException catch (e) {
      if (!_isOneDriveFragmentOverlap(e)) {
        AppLogger.d('OneDrive chunk upload failed: ${_formatUploadError(e)}');
        rethrow;
      }

      // OneDrive 报 fragmentOverlap 时，查询上传会话的 nextExpectedRanges，
      // 然后跳过已存在部分或续传当前分片剩余部分。
      AppLogger.d('OneDrive fragmentOverlap: querying nextExpectedRanges...');
      final expectedStart = await _queryOneDriveNextExpectedStart(
        dio: dio,
        uploadUrl: uploadUrl,
        cancelToken: cancelToken,
      );

      AppLogger.d(
        'OneDrive nextExpectedStart=$expectedStart, '
        'currentRange=$start-${endExclusive - 1}',
      );

      if (expectedStart >= endExclusive) {
        AppLogger.d('OneDrive chunk already uploaded, skip index=$index');
        return;
      }

      if (expectedStart > start && expectedStart < endExclusive) {
        final newOffset = expectedStart - start;
        final remaining = chunkData.sublist(newOffset);
        await sendRange(
          bytes: remaining,
          rangeStart: expectedStart,
          rangeEndExclusive: endExclusive,
          progressOffset: newOffset,
        );
        return;
      }

      // 无法修正时抛出原始错误。
      rethrow;
    }
  }

  bool _isOneDriveFragmentOverlap(DioException e) {
    final data = _asMap(e.response?.data);
    final error = _asMap(data?['error']);
    final innerError = _asMap(error?['innererror']) ?? _asMap(error?['innerError']);
    final code = innerError?['code']?.toString() ?? error?['code']?.toString();
    final message = error?['message']?.toString() ?? e.response?.data?.toString() ?? '';

    return code == 'fragmentOverlap' || message.contains('fragmentOverlap');
  }

  Future<int> _queryOneDriveNextExpectedStart({
    required Dio dio,
    required String uploadUrl,
    required CancelToken cancelToken,
  }) async {
    final response = await _withUploadRetry<Response<dynamic>>(
      'OneDrive query nextExpectedRanges',
      () => dio.get(
        uploadUrl,
        cancelToken: cancelToken,
        options: Options(headers: {'Accept': 'application/json'}),
      ),
      cancelToken: cancelToken,
    );

    final data = _asMap(response.data);
    final ranges = data?['nextExpectedRanges'];

    if (ranges is List && ranges.isNotEmpty) {
      final first = ranges.first.toString();
      final startText = first.split('-').first.trim();
      final parsed = int.tryParse(startText);
      if (parsed != null) return parsed;
    }

    throw Exception('无法读取 OneDrive nextExpectedRanges: ${response.data}');
  }

  /// 上传分片到 S3/OSS/COS/OBS/KS3 等预签名 URL。
  /// 当前问题是 OneDrive 混用负载均衡；这里保留兜底，避免其他策略直接走错 remote ?chunk。
  Future<Map<String, dynamic>?> _uploadChunkToPresignedUrl(
    List<int> chunkData,
    int index,
    UploadSessionModel session,
    CancelToken cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    final urls = session.uploadUrls ?? [];
    if (urls.isEmpty) {
      throw Exception('没有可用的预签名上传 URL');
    }

    final uploadUrl = urls.length > index ? urls[index] : urls.first;
    final dio = _buildRawUploadDio();

    try {
      final response = await _withUploadRetry<Response<dynamic>>(
        'Presigned chunk index=$index',
        () => dio.put(
          uploadUrl,
          data: _chunkedUploadBodyStream(chunkData),
          options: Options(
            contentType: 'application/octet-stream',
            headers: {
              'Content-Length': chunkData.length.toString(),
            },
          ),
          cancelToken: cancelToken,
          onSendProgress: onProgress,
        ),
        cancelToken: cancelToken,
      );

      final etag = response.headers.value('etag');
      AppLogger.d(
        'Presigned chunk uploaded: index=$index, status=${response.statusCode}, etag=$etag',
      );

      if (etag == null || etag.isEmpty) {
        return {'partNumber': index + 1, 'part_number': index + 1};
      }

      return {
        'partNumber': index + 1,
        'part_number': index + 1,
        'ETag': etag,
        'etag': etag,
      };
    } catch (e) {
      AppLogger.d('Presigned chunk upload failed: ${_formatUploadError(e)}');
      rethrow;
    }
  }

  /// 完成上传。
  Future<void> _completeUploadIfNeeded(
    UploadSessionModel session,
    List<Map<String, dynamic>> completedParts,
  ) async {
    if (session._isOneDriveUpload) {
      await _completeOneDriveUpload(session);
      return;
    }

    // local / remote / upyun 通常最后一个分片上传后自动完成。
    if (session.isRelayUpload || session._isRemoteSlaveUpload) {
      return;
    }

    // S3-like 兜底：如果服务端给了 completeURL，就调用。
    final completeUrl = session.completeUrl;
    if (completeUrl == null || completeUrl.isEmpty) {
      return;
    }

    AppLogger.d('Completing multipart upload: $completeUrl');

    try {
      if (_isAbsoluteUrl(completeUrl)) {
        final dio = _buildRawUploadDio();
        await dio.post(
          completeUrl,
          data: completedParts.isEmpty ? '' : _buildS3CompleteXml(completedParts),
          options: Options(contentType: 'application/octet-stream'),
        );
      } else {
        await ApiService.instance.post<dynamic>(
          completeUrl,
          data: completedParts.isEmpty ? <String, dynamic>{} : {'parts': completedParts},
          isNoData: true,
        );
      }
    } catch (e) {
      AppLogger.d('Complete upload failed: ${_formatUploadError(e)}');
      rethrow;
    }
  }

  /// 通知 Cloudreve OneDrive 上传已经完成。
  Future<void> _completeOneDriveUpload(UploadSessionModel session) async {
    final completeUrl = session.completeUrl;
    final callbackSecret = session.callbackSecret;

    final String callbackPath;
    if (completeUrl != null && completeUrl.isNotEmpty) {
      callbackPath = completeUrl;
    } else if (callbackSecret != null && callbackSecret.isNotEmpty) {
      callbackPath = '/callback/onedrive/${session.sessionId}/$callbackSecret';
    } else {
      throw Exception('OneDrive 上传完成，但上传会话缺少 completeURL/callback_secret，无法通知 Cloudreve');
    }

    AppLogger.d('Completing OneDrive upload callback: $callbackPath');

    try {
      if (_isAbsoluteUrl(callbackPath)) {
        final dio = _buildRawUploadDio();
        final response = await _withUploadRetry<Response<dynamic>>(
          'Complete OneDrive upload callback',
          () => dio.post(callbackPath),
        );
        _ensureCloudreveSuccess(_asMap(response.data));
      } else {
        await ApiService.instance.post<dynamic>(
          callbackPath,
          data: <String, dynamic>{},
          noAuth: true,
          isNoData: true,
        );
      }
    } catch (e) {
      AppLogger.d('OneDrive complete callback failed: ${_formatUploadError(e)}');
      rethrow;
    }
  }

  String _targetFileUri(UploadTaskModel task) {
    return task.targetPath.endsWith('/')
        ? '${task.targetPath}${task.fileName}'
        : '${task.targetPath}/${task.fileName}';
  }

  bool _isUploadSessionExpired(UploadSessionModel session) {
    if (session.expires <= 0) return false;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 提前 60 秒认为过期，避免刚开始重试时会话马上失效。
    return session.expires <= nowSeconds + 60;
  }

  bool _isPausedCancel(Object e) {
    if (e is! DioException || e.type != DioExceptionType.cancel) {
      return false;
    }

    final text = [
      e.error?.toString(),
      e.message,
    ].whereType<String>().join(' ').toLowerCase();

    return text.contains('暂停') || text.contains('pause') || text.contains('paused');
  }

  bool _shouldDeleteUploadSessionAfterFailure(Object e) {
    // 超时、网络连接错误等保留会话，给用户重试/续传机会。
    if (_isRetryableUploadError(e)) return false;

    // 其他非重试错误，例如参数错误、权限错误、服务端明确拒绝，应删除上传会话释放锁。
    return true;
  }

  Future<void> _deleteUploadSessionForTask(UploadTaskModel task) async {
    final session = task.session;
    if (session == null) return;

    await _deleteUploadSession(
      sessionId: session.sessionId,
      uri: _targetFileUri(task),
    );
  }

  Future<void> _deleteUploadSession({
    required String sessionId,
    required String uri,
  }) async {
    AppLogger.d('Deleting Cloudreve upload session: id=$sessionId, uri=$uri');

    try {
      final response = await ApiService.instance.dio.delete<dynamic>(
        '/file/upload',
        data: {
          'id': sessionId,
          'uri': uri,
        },
        options: Options(contentType: 'application/json'),
      );

      final data = _asMap(response.data);
      final code = data?['code'];

      if (code == 0 || code == null || code == 404) {
        return;
      }

      if (code == 40073) {
        final tokens = _extractLockTokens(data);
        if (tokens.isNotEmpty) {
          await _forceUnlock(tokens);
          await ApiService.instance.dio.delete<dynamic>(
            '/file/upload',
            data: {
              'id': sessionId,
              'uri': uri,
            },
            options: Options(contentType: 'application/json'),
          );
          return;
        }
      }

      _ensureCloudreveSuccess(data);
    } catch (e) {
      // 删除上传会话是清理动作，失败不应覆盖真正的上传错误。
      AppLogger.d('Delete upload session failed: ${_formatUploadError(e)}');
    }
  }

  List<String> _extractLockTokens(Map<String, dynamic>? data) {
    final raw = data?['data'];
    if (raw is! List) return const [];

    final tokens = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final token = item['token']?.toString();
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }

    return tokens;
  }

  Future<void> _forceUnlock(List<String> tokens) async {
    if (tokens.isEmpty) return;

    AppLogger.d('Force unlocking Cloudreve locks: ${tokens.length} token(s)');

    final response = await ApiService.instance.dio.delete<dynamic>(
      '/file/lock',
      data: {'tokens': tokens},
      options: Options(contentType: 'application/json'),
    );

    final data = _asMap(response.data);
    _ensureCloudreveSuccess(data);
  }

  Future<T> _withUploadRetry<T>(
    String action,
    Future<T> Function() operation, {
    CancelToken? cancelToken,
    int maxAttempts = 3,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelToken?.isCancelled == true) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.cancel,
          error: '上传已取消',
        );
      }

      try {
        return await operation();
      } catch (e) {
        lastError = e;

        final canRetry = _isRetryableUploadError(e);
        if (!canRetry || attempt >= maxAttempts) {
          rethrow;
        }

        final delaySeconds = math.min(10, attempt * 2).toInt();
        AppLogger.d(
          '$action failed, retry $attempt/$maxAttempts after ${delaySeconds}s: '
          '${_formatUploadError(e)}',
        );

        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    throw lastError ?? Exception('$action failed');
  }

  bool _isRetryableUploadError(Object e) {
    if (e is NativeUploadException) {
      final status = e.statusCode;
      if (status == 408 ||
          status == 429 ||
          status == 500 ||
          status == 502 ||
          status == 503 ||
          status == 504) {
        return true;
      }

      final text = e.toString().toLowerCase();
      return text.contains('timeout') ||
          text.contains('timed out') ||
          text.contains('connection') ||
          text.contains('socket');
    }

    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) return false;

      final status = e.response?.statusCode;
      if (status == 408 ||
          status == 429 ||
          status == 500 ||
          status == 502 ||
          status == 503 ||
          status == 504) {
        return true;
      }

      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown;
    }

    final text = e.toString().toLowerCase();
    return text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('connection') ||
        text.contains('socketexception');
  }

  static const int _uploadStreamFrameSize = 256 * 1024;

  /// 将单个 Cloudreve 分片再拆成更小的传输帧交给 Dio。
  ///
  /// 之前一次性把 20MB/40MB chunk 作为一个 Stream event：
  /// Stream.fromIterable([chunkData])
  ///
  /// 这样 Dio/底层网络层通常要等整个 event 消费完才触发进度，
  /// UI 看起来就像“上传没动静”。这里拆成 256KB 小帧：
  /// - 进度回调更连续；
  /// - 速度计算更稳定；
  /// - 不改变 Cloudreve/OneDrive 的 Content-Range 和分片边界。
  Stream<List<int>> _chunkedUploadBodyStream(List<int> bytes) async* {
    if (bytes.isEmpty) {
      yield bytes;
      return;
    }

    var offset = 0;
    while (offset < bytes.length) {
      final end = math.min(offset + _uploadStreamFrameSize, bytes.length);
      if (bytes is Uint8List) {
        yield Uint8List.sublistView(bytes, offset, end);
      } else {
        yield bytes.sublist(offset, end);
      }
      offset = end;

      // 让事件循环有机会处理 UI/进度刷新，避免大 chunk 连续编码时卡顿。
      await Future<void>.delayed(Duration.zero);
    }
  }

  Dio _buildRawUploadDio() {
    return Dio(
      BaseOptions(
        // OneDrive / SharePoint / 对象存储直传地址在移动网络下建立连接可能比较慢。
        // 原 30 秒太短，会导致 “HTTP null, request connection took longer than 0:00:30”。
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 60),
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }

  String _appendChunkQuery(String url, int index) {
    final uri = Uri.parse(url);
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['chunk'] = index.toString();
    return uri.replace(queryParameters: queryParameters).toString();
  }

  bool _isAbsoluteUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _ensureCloudreveSuccess(Map<String, dynamic>? data) {
    if (data == null) return;

    final code = data['code'];
    if (code == null || code == 0) return;

    final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '上传失败';
    throw Exception('$msg (code: $code)');
  }

  String _buildS3CompleteXml(List<Map<String, dynamic>> parts) {
    final buffer = StringBuffer('<CompleteMultipartUpload>');
    for (final part in parts) {
      final partNumber = part['partNumber'] ?? part['part_number'];
      final etag = part['ETag'] ?? part['etag'];
      if (partNumber == null || etag == null) continue;
      buffer
        ..write('<Part>')
        ..write('<PartNumber>$partNumber</PartNumber>')
        ..write('<ETag>$etag</ETag>')
        ..write('</Part>');
    }
    buffer.write('</CompleteMultipartUpload>');
    return buffer.toString();
  }

  /// 发送进度更新
  void _emitProgress(String taskId, double progress) {
    final controller = _progressControllers[taskId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  /// 计算上传速度
  int _computeSpeed(String taskId, int uploadedBytes) {
    final tracker = _speedTrackers[taskId];
    if (tracker == null) {
      _speedTrackers[taskId] = _SpeedTracker(uploadedBytes);
      return 0;
    }
    return tracker.update(uploadedBytes);
  }

  /// 清理速度追踪器
  void _cleanSpeedTracker(String taskId) {
    _speedTrackers.remove(taskId);
  }


  Future<void> _clearPickerTemporaryFiles() async {
    if (!Platform.isAndroid) return;

    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (e) {
      AppLogger.d('清理 file_picker 临时文件失败: $e');
    }
  }

  void _logUploadException(Object e, String fileName) {
    AppLogger.d('Upload failed for $fileName: ${_formatUploadError(e)}');

    if (e is DioException) {
      AppLogger.d('UPLOAD_DIO_TYPE: ${e.type}');
      AppLogger.d('UPLOAD_DIO_STATUS: ${e.response?.statusCode}');
      AppLogger.d('UPLOAD_DIO_DATA: ${e.response?.data}');
      AppLogger.d('UPLOAD_DIO_HEADERS: ${e.response?.headers}');
      AppLogger.d('UPLOAD_DIO_URI: ${e.requestOptions.uri}');
      AppLogger.d('UPLOAD_DIO_METHOD: ${e.requestOptions.method}');
      AppLogger.d('UPLOAD_DIO_REQ_HEADERS: ${e.requestOptions.headers}');
    } else {
      AppLogger.d('UPLOAD_ERROR_TYPE: ${e.runtimeType}');
      AppLogger.d('UPLOAD_ERROR_VALUE: $e');
    }
  }

  String _formatUploadError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final status = e.response?.statusCode;

      final map = _asMap(data);
      if (map != null) {
        final code = map['code'];
        final msg = map['msg'] ?? map['message'] ?? map['error'];
        if (code == 40004) {
          return '文件已存在，请改名后再上传或先删除云端同名文件 (code: 40004)';
        }
        if (msg != null) {
          return '上传失败: $msg${code != null ? ' (code: $code)' : ''}';
        }
        return '上传失败: HTTP $status, $map';
      }

      if (data is String && data.isNotEmpty) {
        return '上传失败: HTTP $status, $data';
      }

      return '上传失败: HTTP $status, ${e.message ?? e.type.name}';
    }

    final text = e.toString();

    if (text.contains('Object existed') || text.contains('40004')) {
      return '文件已存在，请改名后再上传或先删除云端同名文件 (code: 40004)';
    }

    return text;
  }
}

extension _UploadSessionModelCompat on UploadSessionModel {
  String get _policyType => storagePolicy.type.toLowerCase();

  bool get _isOneDriveUpload {
    final type = _policyType;
    if (type == 'onedrive' || type == 'one_drive' || type.contains('onedrive')) {
      return true;
    }

    final urls = uploadUrls ?? const <String>[];
    if (urls.isEmpty) return false;

    final firstUrl = urls.first.toLowerCase();
    return firstUrl.contains('1drv.com') ||
        firstUrl.contains('sharepoint.com') ||
        firstUrl.contains('onedrive.com') ||
        firstUrl.contains('graph.microsoft.com');
  }

  bool get _isRemoteSlaveUpload {
    final type = _policyType;
    return type == 'remote' || type == 'slave';
  }
}

/// 上传速度追踪器
class _SpeedTracker {
  int lastBytes;
  DateTime lastTime;
  int smoothedSpeed = 0;

  _SpeedTracker(this.lastBytes) : lastTime = DateTime.now();

  int update(int currentBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(lastTime).inMilliseconds;

    // 进度回调可能很密集。间隔太短时不重新计算，返回上一次速度，
    // 避免 UI 在 0 B/s 和实际速度之间反复跳动。
    if (elapsed < 300) {
      return smoothedSpeed;
    }

    final bytesDelta = currentBytes - lastBytes;

    // 进度倒退一般来自重试/恢复，重置采样点。
    if (bytesDelta < 0) {
      lastBytes = currentBytes;
      lastTime = now;
      smoothedSpeed = 0;
      return smoothedSpeed;
    }

    final instantSpeed = (bytesDelta * 1000 / elapsed).round();

    if (instantSpeed <= 0) {
      // 没有新字节时逐步衰减到 0，而不是立刻清空。
      smoothedSpeed = (smoothedSpeed * 0.65).round();
    } else if (smoothedSpeed <= 0) {
      smoothedSpeed = instantSpeed;
    } else {
      // 指数平滑：更稳定，但仍能跟随真实变化。
      smoothedSpeed = (smoothedSpeed * 0.65 + instantSpeed * 0.35).round();
    }

    lastBytes = currentBytes;
    lastTime = now;
    return smoothedSpeed < 0 ? 0 : smoothedSpeed;
  }
}
