import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/download_task_model.dart';
import 'file_service.dart';

/// 下载服务
class DownloadService {
  final FileService _fileService = FileService();
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers = {};
  bool _isInitialized = false;

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
      // 在开始下载前，建议同时检查这两个权限
      // 没有 POST_NOTIFICATIONS 权限：用户看不到进度条，系统会认为该服务在静默耗电，从而限制其后台活跃
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      // Android 请求存储权限
      final status = await Permission.manageExternalStorage.request();

      // 如果权限被永久拒绝，引导用户到设置
      if (status.isPermanentlyDenied) {
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

  /// 初始化下载器
  Future<void> initialize() async {
    if (_isInitialized) return;

    await FlutterDownloader.initialize(
      debug: kDebugMode,
    );

    // 监听下载进度
    FlutterDownloader.registerCallback((id, status, progress) {
      debugPrint('Download callback: id=$id, status=$status, progress=$progress');
      _handleDownloadCallback(id, status, progress);
    });

    _isInitialized = true;
  }

  /// 开始下载
  Future<void> startDownload(DownloadTaskModel task) async {
    try {
      // 确保已初始化
      if (!_isInitialized) {
        await initialize();
      }

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

      // 确保保存目录存在
      final file = File(task.savePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 如果文件已存在，删除它
      if (await file.exists()) {
        await file.delete();
      }

      // 使用 flutter_downloader 开始下载
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: file.path.split('/').last,
        showNotification: true,
        openFileFromNotification: true,
      );

    } catch (e) {
      _updateTask(task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      debugPrint('下载失败: $e');
    }
  }

  /// 处理下载回调
  void _handleDownloadCallback(String id, int status, int progress) {
    // 这里需要找到对应的任务
    // 注意：flutter_downloader 使用它自己的 task ID
    // 我们需要建立映射关系
    debugPrint('下载进度: $progress%, 状态: $status');

    // 这里简化处理，实际应用中需要维护 taskId 的映射关系
    // 由于 flutter_downloader 的 ID 与我们的 task ID 不同，
    // 这里暂时无法精确更新进度，需要重构任务管理逻辑
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    await FlutterDownloader.pause(taskId: taskId);
  }

  /// 恢复下载
  Future<void> resumeDownload(DownloadTaskModel task) async {
    if (!_isInitialized) {
      await initialize();
    }
    await FlutterDownloader.resume(taskId: task.id);
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  /// 删除下载任务
  void disposeTask(String taskId) {
    // 关闭进度流
    final controller = _progressControllers[taskId];
    if (controller != null) {
      controller.close();
      _progressControllers.remove(taskId);
    }
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
    // 关闭所有流
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
