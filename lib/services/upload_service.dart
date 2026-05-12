import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/storage_keys.dart';
import '../data/models/upload_task_model.dart';
import 'storage_service.dart';
import 'api_service.dart';
import '../core/utils/app_logger.dart';

/// 上传服务 - 单例模式
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

  /// 添加任务
  void addTask(UploadTaskModel task) {
    _tasks[task.id] = task;
    if (!_progressControllers.containsKey(task.id)) {
      _progressControllers[task.id] = StreamController<double>.broadcast();
    }
    AppLogger.d('UploadTaskModel -> addTask > ${task.toJson()}');
    _saveTasks();
    notifyListeners();
  }

  /// 更新任务
  void updateTask(UploadTaskModel task) {
    if (_tasks.containsKey(task.id)) {
      _tasks[task.id] = task;
      _saveTasks();
      notifyListeners();
    }
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
            t.status == UploadStatus.waiting,
      )
      .toList();

  /// 移除任务
  void removeTask(String id) {
    _tasks.remove(id);
    _cancelTokens.remove(id);
    final controller = _progressControllers.remove(id);
    controller?.close();
    _saveTasks();
    notifyListeners();
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
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _tasks.clear();
    _cancelTokens.clear();
    _progressControllers.clear();
    _saveTasks();
    notifyListeners();
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

          // 检查文件是否存在
          if (!await task.file.exists()) {
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
            final retentionDays = await StorageService.instance
                    .getInt(StorageKeys.taskRetentionDays) ??
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

  /// 取消上传
  void cancelUpload(String taskId) {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null) {
      cancelToken.cancel('上传已取消');
    }

    final task = _tasks[taskId];
    if (task != null) {
      updateTask(task.copyWith(status: UploadStatus.cancelled, speed: 0));
      _cleanSpeedTracker(taskId);
    }
  }

  /// 重试上传
  Future<void> retryUpload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    // 重置任务状态
    updateTask(
      task.copyWith(
        status: UploadStatus.waiting,
        uploadedBytes: 0,
        progress: 0,
        uploadedChunks: 0,
        errorMessage: null,
      ),
    );

    // 开始上传
    await startUpload(task);
  }

  /// 开始上传
  Future<void> startUpload(UploadTaskModel task) async {
    AppLogger.d('UploadService.startUpload: 开始上传任务 ${task.fileName}');
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      // 步骤1：创建上传会话
      AppLogger.d('UploadService.startUpload: 创建上传会话...');
      final session = await _createUploadSession(task);
      AppLogger.d(
        'UploadService.startUpload: 上传会话创建成功，sessionId=${session.sessionId}, chunkSize=${session.chunkSize}',
      );

      // 更新任务，添加会话信息
      final updatedTask = task.copyWith(
        session: session,
        totalChunks: task.calculateTotalChunks(session.chunkSize),
        status: UploadStatus.uploading,
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

      onUploadCompleted?.call(task.targetPath, task.fileName);

      _emitProgress(task.id, 1.0);
    } catch (e) {
      AppLogger.d('Upload failed for ${task.fileName}: $e');

      final isCancelled =
          e is DioException && e.type == DioExceptionType.cancel;

      updateTask(
        task.copyWith(
          status: isCancelled ? UploadStatus.cancelled : UploadStatus.failed,
          errorMessage: e.toString(),
          speed: 0,
        ),
      );
      _cleanSpeedTracker(task.id);

      if (!isCancelled) {
        _emitProgress(task.id, task.progress);
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

    // API: /file/upload 响应格式: {code: 0, data: {...}, msg: ''} 但在 _parseResponse 已经解析过 data, 这里直接使用 response
    final Map<String, dynamic> sessionData = response;

    return UploadSessionModel.fromJson(sessionData);
  }

  /// 上传文件（支持分片上传）
  Future<void> _uploadFile(
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    final session = task.session!;
    final file = task.file;

    AppLogger.d('开始上传 -> ${task.fileName}');

    // 读取文件
    final fileBytes = await file.readAsBytes();

    // 检查是否需要分片：服务器返回了分片大小 或 文件大于20MB
    const largeFileThreshold = 20 * 1024 * 1024; // 20MB
    final shouldMultipart = session.isMultipartEnabled || task.fileSize > largeFileThreshold;

    if (shouldMultipart) {
      // 分片上传
      final chunkSize = session.isMultipartEnabled ? session.chunkSize : largeFileThreshold;
      await _uploadMultipart(fileBytes, chunkSize, task, cancelToken);
    } else {
      // 单次上传
      await _uploadSinglePart(fileBytes, session, task, cancelToken);
    }
  }

  /// 分片上传
  Future<void> _uploadMultipart(
    List<int> fileBytes,
    int chunkSize,
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    final session = task.session!;
    final totalChunks = (fileBytes.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      if (cancelToken.isCancelled) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.cancel,
          error: '上传已取消',
        );
      }

      // 计算当前分片的范围
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, fileBytes.length);
      final chunkData = fileBytes.sublist(start, end);

      AppLogger.d('Uploading chunk ${i + 1}/$totalChunks for ${task.fileName}');

      if (session.isRelayUpload) {
        // 上传到 Cloudreve 服务器
        await _uploadChunkToRelay(chunkData, i, session.sessionId, cancelToken, null);
      } else {
        // 上传到远程存储
        await _uploadChunkToRemote(chunkData, i, session, cancelToken, null);
      }

      // 更新进度 - 获取最新任务状态并计算正确进度
      final currentTask = getTask(task.id) ?? task;
      final progress = (i + 1) / totalChunks;
      final speed = _computeSpeed(task.id, end);
      updateTask(
        currentTask.copyWith(
          uploadedBytes: end,
          progress: progress,
          uploadedChunks: i + 1,
          speed: speed,
        ),
      );
      _emitProgress(task.id, progress);
    }

    // 完成上传（某些存储策略需要）
    if (session.completeUrl != null && session.completeUrl!.isNotEmpty) {
      await _completeMultipartUpload(session);
    }
  }

  /// 上传分片到中继服务器
  Future<void> _uploadChunkToRelay(
    List<int> chunkData,
    int index,
    String sessionId,
    CancelToken cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    await ApiService.instance.postWithProgress(
      '/file/upload/$sessionId/$index',
      data: Stream.fromIterable([chunkData]),
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': chunkData.length.toString(),
      },
      onSendProgress: onProgress,
    );
  }

  /// 上传分片到远程存储
  Future<void> _uploadChunkToRemote(
    List<int> chunkData,
    int index,
    UploadSessionModel session,
    CancelToken cancelToken,
    void Function(int, int)? onProgress,
  ) async {
    final urls = session.uploadUrls ?? [];
    if (urls.isEmpty) {
      throw Exception('没有可用的上传 URL');
    }

    // 大多数远程存储使用一个 URL，通过 query 参数指定分片索引
    final url = urls.first;
    final uploadUrl = url.contains('?')
        ? '$url&chunk=$index'
        : '$url?chunk=$index';

    final dio = Dio(BaseOptions());

    await dio.post(
      uploadUrl,
      data: Stream.fromIterable([chunkData]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {
          'Content-Length': chunkData.length.toString(),
          if (session.credential != null) 'Authorization': session.credential,
        },
      ),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    );
  }

  /// 完成多部分上传
  Future<void> _completeMultipartUpload(UploadSessionModel session) async {
    await ApiService.instance.post(session.completeUrl!, data: {});
  }

  /// 单次上传
  Future<void> _uploadSinglePart(
    List<int> fileBytes,
    UploadSessionModel session,
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    if (session.isRelayUpload) {
      // 上传到中继服务器
      await _uploadChunkToRelay(
        fileBytes,
        0,
        session.sessionId,
        cancelToken,
        (sent, total) {
          final progress = sent / total;
          final currentTask = getTask(task.id) ?? task;
          final speed = _computeSpeed(task.id, sent);
          updateTask(
            currentTask.copyWith(
              uploadedBytes: sent,
              progress: progress,
              speed: speed,
            ),
          );
          _emitProgress(task.id, progress);
        },
      );
    } else {
      // 上传到远程存储
      await _uploadChunkToRemote(
        fileBytes,
        0,
        session,
        cancelToken,
        (sent, total) {
          final progress = sent / total;
          final currentTask = getTask(task.id) ?? task;
          final speed = _computeSpeed(task.id, sent);
          updateTask(
            currentTask.copyWith(
              uploadedBytes: sent,
              progress: progress,
              speed: speed,
            ),
          );
          _emitProgress(task.id, progress);
        },
      );
    }
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
}

/// 上传速度追踪器
class _SpeedTracker {
  int lastBytes;
  DateTime lastTime;

  _SpeedTracker(this.lastBytes) : lastTime = DateTime.now();

  int update(int currentBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(lastTime).inMilliseconds;
    if (elapsed < 200) return 0; // 至少 200ms 间隔才计算

    final bytesDelta = currentBytes - lastBytes;
    final speed = (bytesDelta * 1000 / elapsed).round();

    lastBytes = currentBytes;
    lastTime = now;
    return speed > 0 ? speed : 0;
  }
}
