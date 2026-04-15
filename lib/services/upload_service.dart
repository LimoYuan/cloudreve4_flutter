import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/storage_keys.dart';
import '../data/models/upload_task_model.dart';
import 'storage_service.dart';

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
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<double>> _progressControllers = {};

  /// 添加任务
  void addTask(UploadTaskModel task) {
    _tasks[task.id] = task;
    if (!_progressControllers.containsKey(task.id)) {
      _progressControllers[task.id] = StreamController<double>.broadcast();
    }
    debugPrint('UploadTaskModel -> addTask > ${task.toJson()}');
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
      .where((t) => t.status == UploadStatus.uploading || t.status == UploadStatus.waiting)
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
        .where((t) => t.status == UploadStatus.completed || t.status == UploadStatus.cancelled)
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
      final tasksJson = await StorageService.instance.getString(StorageKeys.uploadTasks);
      if (tasksJson == null || tasksJson.isEmpty) {
        debugPrint('没有保存的上传任务');
        return;
      }

      final tasksList = jsonDecode(tasksJson) as List<dynamic>;
      final loadedTasks = <UploadTaskModel>[];

      final now = DateTime.now();
      for (final taskJson in tasksList) {
        try {
          final task = UploadTaskModel.fromJson(taskJson as Map<String, dynamic>);

          // 检查文件是否存在
          if (!await task.file.exists()) {
            debugPrint('上传任务文件不存在，跳过: ${task.fileName}');
            continue;
          }

          // 过滤掉已取消的任务
          if (task.status == UploadStatus.cancelled) {
            continue;
          }

          // 如果任务已完成，只保留最近7天内的记录
          if (task.status == UploadStatus.completed) {
            if (task.completedAt == null) {
              continue;
            }
            final daysSinceCompletion = now.difference(task.completedAt!).inDays;
            if (daysSinceCompletion > 7) {
              debugPrint('跳过超过7天的已完成任务: ${task.fileName}');
              continue;
            }
          }

          // 对于未完成的任务，重置状态为等待（因为应用关闭后上传已停止）
          if (task.status == UploadStatus.uploading || task.status == UploadStatus.waiting) {
            loadedTasks.add(task.copyWith(
              status: UploadStatus.waiting,
              uploadedBytes: 0,
              progress: 0,
              uploadedChunks: 0,
              errorMessage: null,
            ));
          } else {
            loadedTasks.add(task);
          }
        } catch (e) {
          debugPrint('解析上传任务失败: $e');
        }
      }

      // 将加载的任务添加到当前任务列表
      for (final task in loadedTasks) {
        _tasks[task.id] = task;
        if (!_progressControllers.containsKey(task.id)) {
          _progressControllers[task.id] = StreamController<double>.broadcast();
        }
      }

      debugPrint('从存储加载了 ${loadedTasks.length} 个上传任务');

      // 通知 UI 更新
      if (loadedTasks.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载上传任务失败: $e');
    }
  }

  /// 保存上传任务到本地存储
  Future<void> _saveTasks() async {
    try {
      final tasksList = _tasks.values
          .map((task) => task.toJson())
          .toList();
      final tasksJson = jsonEncode(tasksList);
      await StorageService.instance.setString(StorageKeys.uploadTasks, tasksJson);
      debugPrint('已保存 ${_tasks.length} 个上传任务到存储');
    } catch (e) {
      debugPrint('保存上传任务失败: $e');
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
      updateTask(task.copyWith(
        status: UploadStatus.cancelled,
      ));
    }
  }

  /// 重试上传
  Future<void> retryUpload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    // 重置任务状态
    updateTask(task.copyWith(
      status: UploadStatus.waiting,
      uploadedBytes: 0,
      progress: 0,
      uploadedChunks: 0,
      errorMessage: null,
    ));

    // 开始上传
    await startUpload(task);
  }

  /// 开始上传
  Future<void> startUpload(UploadTaskModel task) async {
    debugPrint('UploadService.startUpload: 开始上传任务 ${task.fileName}');
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      // 步骤1：创建上传会话
      debugPrint('UploadService.startUpload: 创建上传会话...');
      final session = await _createUploadSession(task);
      debugPrint('UploadService.startUpload: 上传会话创建成功，sessionId=${session.sessionId}, chunkSize=${session.chunkSize}');

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
      );
      updateTask(completedTask);

      _emitProgress(task.id, 1.0);
    } catch (e) {
      debugPrint('Upload failed for ${task.fileName}: $e');

      final isCancelled = e is DioException && e.type == DioExceptionType.cancel;

      updateTask(task.copyWith(
        status: isCancelled ? UploadStatus.cancelled : UploadStatus.failed,
        errorMessage: e.toString(),
      ));

      if (!isCancelled) {
        _emitProgress(task.id, task.progress);
      }
    }
  }

  /// 创建上传会话
  Future<UploadSessionModel> _createUploadSession(UploadTaskModel task) async {
    final dio = _createDio();

    // 构建 URI - 正确处理路径分隔符
    String uri;
    if (task.targetPath.endsWith('/')) {
      uri = '${task.targetPath}${task.fileName}';
    } else {
      uri = '${task.targetPath}/${task.fileName}';
    }
    debugPrint('Upload URI: $uri');

    final response = await dio.put<Map<String, dynamic>>(
      '/file/upload',
      data: {
        'uri': uri,
        'size': task.fileSize,
      },
    );

    // API 响应格式: {code: 0, data: {...}, msg: ''}
    final data = response.data as Map<String, dynamic>;
    final sessionData = data['data'] as Map<String, dynamic>?;
    if (sessionData == null) {
      throw Exception('API 响应中没有 data 字段: ${data['msg']}');
    }
    return UploadSessionModel.fromJson(sessionData);
  }

  /// 上传文件（支持分片上传）
  Future<void> _uploadFile(UploadTaskModel task, CancelToken cancelToken) async {
    final session = task.session!;
    final file = task.file;
    final dio = _createDio();

    // 读取文件
    final fileBytes = await file.readAsBytes();

    if (session.isMultipartEnabled) {
      // 分片上传
      await _uploadMultipart(fileBytes, session, dio, task, cancelToken);
    } else {
      // 单次上传
      await _uploadSinglePart(fileBytes, session, dio, task, cancelToken);
    }
  }

  /// 分片上传
  Future<void> _uploadMultipart(
    List<int> fileBytes,
    UploadSessionModel session,
    Dio dio,
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    final totalChunks = task.totalChunks;
    final chunkSize = session.chunkSize;

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

      debugPrint('Uploading chunk ${i + 1}/$totalChunks for ${task.fileName}');

      if (session.isRelayUpload) {
        // 上传到 Cloudreve 服务器
        await _uploadChunkToRelay(chunkData, i, session.sessionId, dio, cancelToken);
      } else {
        // 上传到远程存储
        await _uploadChunkToRemote(chunkData, i, session, cancelToken);
      }

      // 更新进度
      final uploadedBytes = end;
      final progress = uploadedBytes / task.fileSize;
      updateTask(task.copyWith(
        uploadedBytes: uploadedBytes,
        progress: progress,
        uploadedChunks: i + 1,
      ));
      _emitProgress(task.id, progress);
    }

    // 完成上传（某些存储策略需要）
    if (session.completeUrl != null && session.completeUrl!.isNotEmpty) {
      await _completeMultipartUpload(session, dio);
    }
  }

  /// 上传分片到中继服务器
  Future<void> _uploadChunkToRelay(
    List<int> chunkData,
    int index,
    String sessionId,
    Dio dio,
    CancelToken cancelToken,
  ) async {
    await dio.post(
      '/file/upload/$sessionId/$index',
      data: Stream.fromIterable([chunkData]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {
          'Content-Length': chunkData.length.toString(),
        },
      ),
      cancelToken: cancelToken,
    );
  }

  /// 上传分片到远程存储
  Future<void> _uploadChunkToRemote(
    List<int> chunkData,
    int index,
    UploadSessionModel session,
    CancelToken cancelToken,
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
    );
  }

  /// 完成多部分上传
  Future<void> _completeMultipartUpload(
    UploadSessionModel session,
    Dio dio,
  ) async {
    await dio.post(
      session.completeUrl!,
      data: {},
    );
  }

  /// 单次上传
  Future<void> _uploadSinglePart(
    List<int> fileBytes,
    UploadSessionModel session,
    Dio dio,
    UploadTaskModel task,
    CancelToken cancelToken,
  ) async {
    if (session.isRelayUpload) {
      // 上传到中继服务器
      await _uploadChunkToRelay(fileBytes, 0, session.sessionId, dio, cancelToken);
    } else {
      // 上传到远程存储
      await _uploadChunkToRemote(fileBytes, 0, session, cancelToken);
    }

    updateTask(task.copyWith(
      uploadedBytes: task.fileSize,
      progress: 1.0,
      uploadedChunks: 1,
    ));
    _emitProgress(task.id, 1.0);
  }

  /// 发送进度更新
  void _emitProgress(String taskId, double progress) {
    final controller = _progressControllers[taskId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  /// 创建配置了 token 的 Dio 实例
  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://demo.cloudreve.org/api/v4',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 300),
      sendTimeout: const Duration(seconds: 300),
    ));

    // 添加请求拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.instance.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));

    // 添加错误拦截器（处理 401）
    bool _isRefreshing = false;
    final List<Completer<void>> _refreshSubscribers = [];

    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          if (path.contains('/session/token/refresh')) {
            return handler.next(error);
          }

          if (_isRefreshing) {
            final completer = Completer<void>();
            _refreshSubscribers.add(completer);
            await completer.future;
            error.requestOptions.headers.remove('Authorization');
            return handler.resolve(await dio.fetch(error.requestOptions));
          }

          _isRefreshing = true;

          try {
            final refreshToken = await StorageService.instance.refreshToken;
            if (refreshToken == null || refreshToken.isEmpty) {
              _isRefreshing = false;
              return handler.next(error);
            }

            final refreshDio = Dio(BaseOptions(
              baseUrl: 'https://demo.cloudreve.org/api/v4',
              headers: {'Content-Type': 'application/json'},
            ));

            final response = await refreshDio.post<Map<String, dynamic>>(
              '/session/token/refresh',
              data: {'refresh_token': refreshToken},
            );

            final data = response.data as Map<String, dynamic>;
            await StorageService.instance.setAccessToken(data['access_token'] as String);
            await StorageService.instance.setRefreshToken(data['refresh_token'] as String);

            _isRefreshing = false;

            for (final subscriber in _refreshSubscribers) {
              if (!subscriber.isCompleted) {
                subscriber.complete();
              }
            }
            _refreshSubscribers.clear();

            error.requestOptions.headers.remove('Authorization');
            return handler.resolve(await dio.fetch(error.requestOptions));
          } catch (e) {
            debugPrint('UploadService: Refresh token failed: $e');
            _isRefreshing = false;

            for (final subscriber in _refreshSubscribers) {
              if (!subscriber.isCompleted) {
                subscriber.completeError(e);
              }
            }
            _refreshSubscribers.clear();

            return handler.next(error);
          }
        }

        return handler.next(error);
      },
    ));

    return dio;
  }
}
