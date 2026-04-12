import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
      ));

  static UploadService? _instance;
  static UploadService get instance {
    _instance ??= UploadService._internal();
    return _instance!;
  }

  final Dio _dio;
  final Map<String, UploadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  static const String _baseUrl = 'https://demo.cloudreve.org/api/v4';

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
