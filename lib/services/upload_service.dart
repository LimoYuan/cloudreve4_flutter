import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// 上传任务
class UploadTask {
  final String id;
  final File file;
  final String fileName;
  final int fileSize;
  int uploadedBytes;
  double progress;
  String? error;
  bool completed;
  bool cancelled;

  UploadTask({
    required this.id,
    required this.file,
    required this.fileName,
    required this.fileSize,
  })  : uploadedBytes = 0,
       progress = 0,
       completed = false,
       cancelled = false;

  double get percentage => fileSize > 0 ? (uploadedBytes / fileSize) * 100 : 0;
}

/// 上传服务
class UploadService extends ChangeNotifier {
  UploadService._internal() : _dio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
        },
      )) {
    // 添加请求拦截器，自动添加 token
    _dio.interceptors.add(_requestInterceptor());
    // 添加错误拦截器，处理 401
    _dio.interceptors.add(_errorInterceptor());
  }

  static UploadService? _instance;
  static UploadService get instance {
    _instance ??= UploadService._internal();
    return _instance!;
  }

  final Dio _dio;
  final Map<String, UploadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  static const String _baseUrl = 'https://demo.cloudreve.org/api/v4';

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshSubscribers = [];

  /// 请求拦截器 - 自动添加 token
  Interceptor _requestInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加Token
        final token = await StorageService.instance.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    );
  }

  /// Error 拦截器 - 处理 401
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        // 处理 401 未授权错误
        if (error.response?.statusCode == 401) {
          // 检查是否需要跳过 token 检查（如刷新 token 请求本身）
          final path = error.requestOptions.path;
          if (path.contains('/session/token/refresh')) {
            return handler.next(error);
          }

          // 如果正在刷新 token，等待刷新完成
          if (_isRefreshing) {
            final completer = Completer<void>();
            _refreshSubscribers.add(completer);
            await completer.future;

            // 移除旧 header，让拦截器重新添加新 token
            error.requestOptions.headers.remove('Authorization');

            // 重试请求
            return handler.resolve(await _dio.fetch(error.requestOptions));
          }

          // 开始刷新 token
          _isRefreshing = true;

          try {
            // 获取新的 token
            final refreshToken = await StorageService.instance.refreshToken;
            if (refreshToken == null || refreshToken.isEmpty) {
              _isRefreshing = false;
              return handler.next(error);
            }

            // 创建新的 Dio 实例来刷新 token
            final refreshDio = Dio(BaseOptions(
              baseUrl: _baseUrl,
              headers: {'Content-Type': 'application/json'},
            ));

            final response = await refreshDio.post<Map<String, dynamic>>(
              '/session/token/refresh',
              data: {'refresh_token': refreshToken},
            );

            // 保存新 token
            final data = response.data as Map<String, dynamic>;
            await StorageService.instance.setAccessToken(data['access_token'] as String);
            await StorageService.instance.setRefreshToken(data['refresh_token'] as String);

            _isRefreshing = false;

            // 通知等待的请求
            for (final subscriber in _refreshSubscribers) {
              if (!subscriber.isCompleted) {
                subscriber.complete();
              }
            }
            _refreshSubscribers.clear();

            // 重试当前请求
            error.requestOptions.headers.remove('Authorization');
            return handler.resolve(await _dio.fetch(error.requestOptions));
          } catch (e) {
            debugPrint('UploadService: Refresh token failed: $e');
            _isRefreshing = false;

            // 通知等待的请求失败
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
    );
  }

  /// 上传文件
  Future<void> uploadFile({
    required UploadTask task,
    required void Function(double) onProgress,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        task.file.path,
        filename: task.fileName,
      ),
      'size': task.fileSize.toString(),
    });

    try {
      await _dio.post(
        '/file/upload',
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: (int sent, int total) {
          final progress = total > 0 ? (sent / total * 100).toDouble() : 0.0;
          task.progress = progress;
          task.uploadedBytes = sent;
          onProgress(progress);
          notifyListeners();
        },
      );

      task.completed = true;
      task.progress = 100;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.cancelled = true;
      } else {
        task.error = e.toString();
      }
      notifyListeners();
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
      task.cancelled = true;
    }
    _removeTask(taskId);
    notifyListeners();
  }

  /// 添加任务
  void addTask(UploadTask task) {
    _tasks[task.id] = task;
    notifyListeners();
  }

  /// 获取任务
  UploadTask? getTask(String id) => _tasks[id];

  /// 移除任务
  void removeTask(String id) {
    _tasks.remove(id);
    _cancelTokens.remove(id);
    notifyListeners();
  }

  void _removeTask(String id) {
    _tasks.remove(id);
    _cancelTokens.remove(id);
  }

  /// 获取所有任务
  List<UploadTask> get allTasks => _tasks.values.toList();

  /// 获取进行中的任务
  List<UploadTask> get activeTasks => _tasks.values
      .where((t) => !t.completed && !t.cancelled)
      .toList();

  /// 清除所有任务
  void clearAllTasks() {
    _tasks.clear();
    _cancelTokens.clear();
    notifyListeners();
  }
}
