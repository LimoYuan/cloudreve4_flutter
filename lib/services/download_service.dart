import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:background_downloader/background_downloader.dart' as bd;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/download_task_model.dart';
import 'file_service.dart';
import '../core/utils/app_logger.dart';

/// 下载服务 - 单例模式
/// Android 使用 flutter_downloader，Windows/Linux/macOS 使用 background_downloader
@pragma('vm:entry-point')
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  DownloadService._internal() {
    if (!_useBackgroundDownloader) {
      _port = ReceivePort();
      _port!.listen((dynamic data) {
        AppLogger.d('DownloadService ReceivePort 收到数据: $data');
        final id = data[0] as String;
        final status = data[1] as int;
        final progress = data[2] as int;
        _callbackHandler?.call(id, status, progress);
      });
    }
  }

  ReceivePort? _port;

  // 统一映射：外部下载器 task ID → 内部 task ID
  final Map<String, String> _externalTaskIdToInternalId = {};
  final Map<String, String> _internalIdToExternalTaskId = {};

  // 存储 background_downloader 的 DownloadTask 对象，用于暂停/恢复/取消
  final Map<String, bd.DownloadTask> _bdTasks = {};

  // 回调处理器
  static Function(String taskId, int status, int progress)? _callbackHandler;

  final FileService _fileService = FileService();
  final Map<String, StreamController<DownloadTaskModel>> _progressControllers = {};
  bool _isInitialized = false;

  /// 是否使用 background_downloader（Windows/Linux/macOS）
  bool get _useBackgroundDownloader =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// 设置回调处理器
  static void setCallbackHandler(Function(String taskId, int status, int progress) handler) {
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
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      final status = await Permission.manageExternalStorage.request();

      if (status.isPermanentlyDenied) {
        throw Exception('存储权限被永久拒绝，请在设置中开启');
      }

      if (!status.isGranted) {
        throw Exception('存储权限被拒绝');
      }

      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${appDocDir.path}/Downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else {
      // Windows/Linux/macOS - 使用系统下载目录
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
      // 回退方案
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final dir = Directory('$userProfile\\Downloads');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory('$home/Downloads');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  /// 初始化下载器
  Future<void> initialize({Function(String taskId, int status, int progress)? callbackHandler}) async {
    if (callbackHandler != null) {
      setCallbackHandler(callbackHandler);
      AppLogger.d('回调处理器已更新');
    }

    if (_isInitialized) {
      AppLogger.d('DownloadService 已经初始化');
      return;
    }

    if (_useBackgroundDownloader) {
      // Windows/Linux/macOS: 使用 background_downloader
      bd.FileDownloader().registerCallbacks(
        taskStatusCallback: _handleBdStatusUpdate,
        taskProgressCallback: _handleBdProgressUpdate,
      );
      AppLogger.d('background_downloader 回调已注册');
    } else {
      // Android: 使用 flutter_downloader
      IsolateNameServer.registerPortWithName(_port!.sendPort, 'download_service_port');
      AppLogger.d('已注册 ReceivePort 到 IsolateNameServer');

      await FlutterDownloader.initialize(
        debug: kDebugMode,
      );
      FlutterDownloader.registerCallback(_staticCallback);
    }

    _isInitialized = true;
    AppLogger.d('DownloadService 初始化完成 (${_useBackgroundDownloader ? "background_downloader" : "flutter_downloader"})');
  }

  /// flutter_downloader 静态回调
  @pragma('vm:entry-point')
  static void _staticCallback(String id, int status, int progress) {
    AppLogger.d('flutter_downloader 静态回调: id=$id, status=$status, progress=$progress');
    final sendPort = IsolateNameServer.lookupPortByName('download_service_port');
    if (sendPort != null) {
      sendPort.send([id, status, progress]);
    } else {
      _callbackHandler?.call(id, status, progress);
    }
  }

  /// background_downloader 状态回调
  void _handleBdStatusUpdate(bd.TaskStatusUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    if (internalId == null) {
      AppLogger.d('background_downloader 状态回调: 未找到内部任务ID, taskId=${update.task.taskId}');
      return;
    }

    // 映射为 flutter_downloader 兼容的状态码
    // 0=undefined, 1=enqueued, 2=running, 3=complete, 4=failed, 5=canceled, 6=paused
    int status;
    switch (update.status) {
      case bd.TaskStatus.enqueued:
        status = 1;
        break;
      case bd.TaskStatus.running:
        status = 2;
        break;
      case bd.TaskStatus.complete:
        status = 3;
        break;
      case bd.TaskStatus.notFound:
      case bd.TaskStatus.failed:
        status = 4;
        break;
      case bd.TaskStatus.canceled:
        status = 5;
        break;
      case bd.TaskStatus.paused:
        status = 6;
        break;
      case bd.TaskStatus.waitingToRetry:
        status = 1;
        break;
    }

    AppLogger.d('background_downloader 状态更新: taskId=${update.task.taskId}, internalId=$internalId, status=$status');

    // 状态变化时，进度设为完成(100)或当前值
    final progress = status == 3 ? 100 : 0;
    _callbackHandler?.call(update.task.taskId, status, progress);
  }

  /// background_downloader 进度回调
  void _handleBdProgressUpdate(bd.TaskProgressUpdate update) {
    final internalId = _externalTaskIdToInternalId[update.task.taskId];
    if (internalId == null) return;

    final progress = (update.progress * 100).toInt().clamp(0, 100);
    _callbackHandler?.call(update.task.taskId, 2, progress);
  }

  /// 开始下载
  Future<String?> startDownload(DownloadTaskModel task) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // 获取下载 URL（共用逻辑）
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

      if (_useBackgroundDownloader) {
        return _startBdDownload(task, url, dir);
      } else {
        return _startFlutterDownloader(task, url, dir, file);
      }
    } catch (e) {
      AppLogger.d('下载失败: $e');
      rethrow;
    }
  }

  /// 使用 background_downloader 开始下载
  Future<String?> _startBdDownload(DownloadTaskModel task, String url, Directory dir) async {
    final bdTask = bd.DownloadTask(
      url: url,
      filename: task.fileName,
      directory: dir.path,
      baseDirectory: bd.BaseDirectory.root,
      updates: bd.Updates.statusAndProgress,
      allowPause: true,
      metaData: task.id,
    );

    final success = await bd.FileDownloader().enqueue(bdTask);

    if (!success) {
      throw Exception('创建下载任务失败');
    }

    // 保存映射关系
    _externalTaskIdToInternalId[bdTask.taskId] = task.id;
    _internalIdToExternalTaskId[task.id] = bdTask.taskId;
    _bdTasks[task.id] = bdTask;

    AppLogger.d('background_downloader 任务已添加: taskId=${bdTask.taskId}, internalId=${task.id}');

    return bdTask.taskId;
  }

  /// 使用 flutter_downloader 开始下载
  Future<String?> _startFlutterDownloader(DownloadTaskModel task, String url, Directory dir, File file) async {
    final flutterTaskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: file.uri.pathSegments.last,
      showNotification: true,
      openFileFromNotification: true,
    );

    if (flutterTaskId == null || flutterTaskId.isEmpty) {
      throw Exception('创建下载任务失败');
    }

    _externalTaskIdToInternalId[flutterTaskId] = task.id;
    _internalIdToExternalTaskId[task.id] = flutterTaskId;

    AppLogger.d('flutter_downloader 任务已添加: flutterTaskId=$flutterTaskId, internalId=${task.id}');

    return flutterTaskId;
  }

  /// 根据外部下载器 task ID 获取内部任务 ID
  String? getInternalTaskId(String externalTaskId) {
    return _externalTaskIdToInternalId[externalTaskId];
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    if (_useBackgroundDownloader) {
      final bdTask = _bdTasks[taskId];
      if (bdTask != null) {
        await bd.FileDownloader().pause(bdTask);
      }
    } else {
      final externalId = _internalIdToExternalTaskId[taskId];
      if (externalId != null) {
        await FlutterDownloader.pause(taskId: externalId);
      }
    }
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (_useBackgroundDownloader) {
      final bdTask = _bdTasks[taskId];
      if (bdTask != null) {
        await bd.FileDownloader().resume(bdTask);
      }
    } else {
      final externalId = _internalIdToExternalTaskId[taskId];
      if (externalId != null) {
        await FlutterDownloader.resume(taskId: externalId);
      }
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    if (_useBackgroundDownloader) {
      final bdTask = _bdTasks[taskId];
      if (bdTask != null) {
        await bd.FileDownloader().cancel(bdTask);
      }
    } else {
      final externalId = _internalIdToExternalTaskId[taskId];
      if (externalId != null) {
        await FlutterDownloader.cancel(taskId: externalId);
      }
    }
  }

  /// 删除下载任务
  void disposeTask(String taskId) {
    final externalId = _internalIdToExternalTaskId[taskId];
    if (externalId != null) {
      _externalTaskIdToInternalId.remove(externalId);
    }
    _internalIdToExternalTaskId.remove(taskId);
    _bdTasks.remove(taskId);

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
      AppLogger.d('删除文件失败: $e');
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
    _externalTaskIdToInternalId.clear();
    _internalIdToExternalTaskId.clear();
    _bdTasks.clear();

    // 关闭所有流
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
  }
}
