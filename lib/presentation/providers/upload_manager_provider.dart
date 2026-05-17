import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/upload_task_model.dart';
import '../../services/native_content_reader.dart';
import '../../services/upload_service.dart';

/// 上传管理 Provider
class UploadManagerProvider extends ChangeNotifier {
  final UploadService _uploadService = UploadService.instance;
  bool _isInitialized = false;
  bool _shouldShowDialog = false;

  bool get showUploadDialog =>
      _shouldShowDialog && _uploadService.allTasks.isNotEmpty;

  List<UploadTaskModel> get allTasks => _uploadService.allTasks;
  List<UploadTaskModel> get activeTasks => _uploadService.activeTasks;

  /// 初始化上传管理器
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _uploadService.initialize();
    _uploadService.addListener(_onServiceChanged);
    _isInitialized = true;
  }

  void _onServiceChanged() {
    notifyListeners();
  }

  /// 标记应该显示上传任务弹窗
  void markShouldShowDialog() {
    _shouldShowDialog = true;
    notifyListeners();
  }

  /// 隐藏上传任务弹窗
  void hideDialog() {
    _shouldShowDialog = false;
    notifyListeners();
  }

  String _normalizeTargetPath(String targetPath) {
    if (targetPath.startsWith('cloudreve://my')) {
      return targetPath;
    }

    var pathPart = targetPath;
    if (pathPart.startsWith('/')) {
      pathPart = pathPart.substring(1);
    }

    return pathPart.isEmpty ? 'cloudreve://my' : 'cloudreve://my/$pathPart';
  }

  /// 兼容旧入口：从 dart:io File 开始上传。
  ///
  /// 桌面端拖拽上传、部分旧逻辑仍会调用这个方法。
  Future<void> startUpload(
    List<File> files,
    String targetPath,
  ) async {
    final uri = _normalizeTargetPath(targetPath);

    for (final file in files) {
      final task = UploadTaskModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.path}',
        file: file,
        fileName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path.split(Platform.pathSeparator).last,
        fileSize: await file.length(),
        targetPath: uri,
      );

      _uploadService.addTask(task);
      _uploadService.startUpload(task);
    }
  }

  /// 从 file_picker 的 PlatformFile 开始上传。
  ///
  /// Android 上优先使用 PlatformFile.identifier 暴露的 content:// URI，
  /// 通过原生 ContentResolver 分片读取，避免 file_picker 复制大文件。
  ///
  /// 如果 identifier 不可用，则回退到 file_picker 给出的本地 path。
  Future<void> startUploadPlatformFiles(
    List<PlatformFile> platformFiles,
    String targetPath,
  ) async {
    final uri = _normalizeTargetPath(targetPath);

    for (final pickedFile in platformFiles) {
      final identifier = pickedFile.identifier;
      final sourceUri = Platform.isAndroid &&
              identifier != null &&
              identifier.toLowerCase().startsWith('content://')
          ? identifier
          : null;

      if (sourceUri != null) {
        await NativeContentReader.instance.persistReadPermission(sourceUri);
      }

      final fallbackPath = pickedFile.path ?? '';
      if (sourceUri == null && fallbackPath.isEmpty) {
        continue;
      }

      final task = UploadTaskModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}',
        file: File(fallbackPath),
        fileName: pickedFile.name,
        fileSize: pickedFile.size,
        targetPath: uri,
        sourceUri: sourceUri,
      );

      _uploadService.addTask(task);
      _uploadService.startUpload(task);
    }
  }

  /// 从 Android 原生文件选择器返回的 content:// 文件开始上传。
  ///
  /// 这条路径不经过 file_picker，因此不会先把大文件复制进 App 缓存目录。
  Future<void> startUploadNativeFiles(
    List<NativePickedFile> nativeFiles,
    String targetPath,
  ) async {
    final uri = _normalizeTargetPath(targetPath);

    for (final nativeFile in nativeFiles) {
      if (nativeFile.uri.isEmpty || nativeFile.size <= 0) {
        continue;
      }

      await NativeContentReader.instance.persistReadPermission(nativeFile.uri);

      final task = UploadTaskModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${nativeFile.name}',
        file: File(''),
        fileName: nativeFile.name,
        fileSize: nativeFile.size,
        targetPath: uri,
        sourceUri: nativeFile.uri,
      );

      _uploadService.addTask(task);
      _uploadService.startUpload(task);
    }
  }

  /// 暂停上传
  void pauseUpload(String taskId) {
    _uploadService.pauseUpload(taskId);
  }

  /// 取消上传
  void cancelUpload(String taskId) {
    _uploadService.cancelUpload(taskId);
  }

  /// 重试 / 继续上传
  void retryUpload(String taskId) {
    _uploadService.retryUpload(taskId);
  }

  /// 删除任务
  void removeTask(String taskId) {
    _uploadService.removeTask(taskId);
  }

  /// 清除所有已完成的任务
  void clearCompletedTasks() {
    _uploadService.clearCompletedTasks();
  }

  /// 清除失败任务
  void clearFailedTasks() {
    _uploadService.clearFailedTasks();
  }

  @override
  void dispose() {
    _uploadService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
