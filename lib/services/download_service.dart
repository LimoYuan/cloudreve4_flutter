import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/download_task_model.dart';
import 'file_service.dart';

/// 下载服务
class DownloadService {
  final Dio _dio = Dio();
  final FileService _fileService = FileService();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers = {};

  /// 获取下载任务进度流
  Stream<DownloadTaskModel> getProgressStream(String taskId) {
    if (!_progressControllers.containsKey(taskId)) {
      _progressControllers[taskId] = StreamController<DownloadTaskModel>.broadcast();
    }
    return _progressControllers[taskId]!.stream;
  }

  /// 获取下载目录
  Future<Directory> getDownloadDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 请求存储权限
      final status = await Permission.manageExternalStorage.request();

      // 如果权限被永久拒绝，引导用户到设置
      if (status.isPermanentlyDenied) {
        // TODO: 显示对话框引导用户到应用设置
        throw Exception('存储权限被永久拒绝，请在设置中开启');
      }

      // 如果权限被拒绝
      if (!status.isGranted) {
        throw Exception('存储权限被拒绝');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS 使用应用文档目录下的下载文件夹
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${appDocDir.path}/Downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else {
      // 其他平台使用临时目录
      final tempDir = await getTemporaryDirectory();
      final directory = Directory('${tempDir.path}/downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
  }

  /// 开始下载
  Future<void> startDownload(DownloadTaskModel task) async {
    try {
      // 更新状态为下载中
      _updateTask(task.copyWith(status: DownloadStatus.downloading));

      // 如果没有下载URL，先获取
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

      // 创建取消令牌
      final cancelToken = CancelToken();
      _cancelTokens[task.id] = cancelToken;

      // 开始下载文件
      await _downloadFile(
        task: task,
        url: url,
        cancelToken: cancelToken,
      );
    } catch (e) {
      _updateTask(task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      debugPrint('下载失败: $e');
    }
  }

  /// 下载文件
  Future<void> _downloadFile({
    required DownloadTaskModel task,
    required String url,
    required CancelToken cancelToken,
  }) async {
    // 确保保存目录存在
    final File file = File(task.savePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 如果文件已存在，询问是否覆盖（这里简化为直接覆盖）
    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      url,
      task.savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final updatedTask = task.copyWith(
            downloadedBytes: received,
            fileSize: total,
          );
          _updateTask(updatedTask);
        }
      },
    );

    // 下载完成
    _updateTask(task.copyWith(
      status: DownloadStatus.completed,
      downloadedBytes: task.fileSize,
      completedAt: DateTime.now(),
    ));
  }

  /// 暂停下载
  void pauseDownload(String taskId) {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('用户暂停下载');
    }
  }

  /// 恢复下载（实际上是重新开始）
  Future<void> resumeDownload(DownloadTaskModel task) async {
    await startDownload(task);
  }

  /// 取消下载
  void cancelDownload(String taskId) {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('用户取消下载');
    }
  }

  /// 删除下载任务
  void disposeTask(String taskId) {
    // 取消下载（如果正在进行）
    pauseDownload(taskId);

    // 关闭进度流
    final controller = _progressControllers[taskId];
    if (controller != null) {
      controller.close();
      _progressControllers.remove(taskId);
    }

    // 移除取消令牌
    _cancelTokens.remove(taskId);
  }

  /// 删除已下载的文件
  Future<void> deleteDownloadedFile(String savePath) async {
    try {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('删除文件失败: $e');
    }
  }

  /// 更新任务状态并通知监听器
  void _updateTask(DownloadTaskModel task) {
    final controller = _progressControllers[task.id];
    if (controller != null && !controller.isClosed) {
      controller.add(task);
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
    // 取消所有下载
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel();
      }
    }
    _cancelTokens.clear();

    // 关闭所有流
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
