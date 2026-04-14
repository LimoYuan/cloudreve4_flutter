import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/download_task_model.dart';
import 'file_service.dart';

/// 下载服务
@pragma('vm:entry-point')
class DownloadService {
  // 用于存储从 flutter_downloader task ID 到我们内部 task ID 的映射
  final Map<String, String> _flutterTaskIdToInternalId = {};
  final Map<String, String> _internalIdToFlutterTaskId = {};

  // 回调处理器 - 必须是静态方法
  static Function(String flutterTaskId, int status, int progress)? _callbackHandler;

  final FileService _fileService = FileService();
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers = {};
  bool _isInitialized = false;

  /// 设置回调处理器
  static void setCallbackHandler(Function(String flutterTaskId, int status, int progress) handler) {
    _callbackHandler = handler;
  }

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
      // 没有 POST_NOTIFICATIONS 权限：用户看不到进度条，系统会认为该服务在静默耗电，从而限制后台活跃
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
  Future<void> initialize({Function(String flutterTaskId, int status, int progress)? callbackHandler}) async {
    // 如果提供了回调处理器，设置它（即使已经初始化过）
    if (callbackHandler != null) {
      setCallbackHandler(callbackHandler);
      debugPrint('回调处理器已更新');
    }

    if (_isInitialized) {
      debugPrint('DownloadService 已经初始化');
      return;
    }

    await FlutterDownloader.initialize(
      debug: kDebugMode,
    );

    // 监听下载进度 - 使用静态回调方法
    FlutterDownloader.registerCallback(_staticCallback);

    _isInitialized = true;
    debugPrint('DownloadService 初始化完成');
  }

  /// 静态回调方法 - flutter_downloader 要求必须是静态或顶层函数
  @pragma('vm:entry-point')
  static void _staticCallback(String id, int status, int progress) {
    debugPrint('flutter_downloader 静态回调: id=$id, status=$status, progress=$progress');
    _callbackHandler?.call(id, status, progress);
  }

  /// 开始下载
  Future<String?> startDownload(DownloadTaskModel task) async {
    try {
      // 确保已初始化
      if (!_isInitialized) {
        await initialize();
      }

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
      final flutterTaskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: file.path.split('/').last,
        showNotification: true,
        openFileFromNotification: true,
      );

      // 检查任务 ID 是否有效
      if (flutterTaskId == null || flutterTaskId.isEmpty) {
        throw Exception('创建下载任务失败');
      }

      // 保存 ID 映射关系
      _flutterTaskIdToInternalId[flutterTaskId] = task.id;
      _internalIdToFlutterTaskId[task.id] = flutterTaskId;

      debugPrint('下载任务已添加: flutterTaskId=$flutterTaskId, internalId=${task.id}');

      return flutterTaskId;

    } catch (e) {
      debugPrint('下载失败: $e');
      rethrow;
    }
  }

  /// 根据 flutter_downloader ID 获取内部任务 ID
  String? getInternalTaskId(String flutterTaskId) {
    return _flutterTaskIdToInternalId[flutterTaskId];
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    final flutterTaskId = _internalIdToFlutterTaskId[taskId];
    if (flutterTaskId != null) {
      await FlutterDownloader.pause(taskId: flutterTaskId);
    }
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    if (!_isInitialized) {
      await initialize();
    }
    final flutterTaskId = _internalIdToFlutterTaskId[taskId];
    if (flutterTaskId != null) {
      await FlutterDownloader.resume(taskId: flutterTaskId);
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    final flutterTaskId = _internalIdToFlutterTaskId[taskId];
    if (flutterTaskId != null) {
      await FlutterDownloader.cancel(taskId: flutterTaskId);
    }
  }

  /// 删除下载任务
  void disposeTask(String taskId) {
    final flutterTaskId = _internalIdToFlutterTaskId[taskId];
    if (flutterTaskId != null) {
      _flutterTaskIdToInternalId.remove(flutterTaskId);
    }
    _internalIdToFlutterTaskId.remove(taskId);

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
    _flutterTaskIdToInternalId.clear();
    _internalIdToFlutterTaskId.clear();

    // 关闭所有流
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
