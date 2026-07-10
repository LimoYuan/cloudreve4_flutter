import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/upload_task_model.dart';
import '../../services/native_content_reader.dart';
import '../../services/file_service.dart';
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


  String _localName(String path) {
    final normalized = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final parts = normalized.split(RegExp(r'[\\/]+'));
    return parts.isEmpty || parts.last.trim().isEmpty ? '未命名文件夹' : parts.last.trim();
  }

  String _plainRemotePath(String targetPath) {
    var text = targetPath.trim();
    if (text.startsWith('cloudreve://my')) {
      text = text.substring('cloudreve://my'.length);
    }
    if (text.isEmpty || text == '/') return '/';
    return text.startsWith('/') ? text : '/$text';
  }

  String _joinRemotePath(String base, Iterable<String> segments) {
    final parts = <String>[];
    final baseText = _plainRemotePath(base).replaceAll(RegExp(r'^/+|/+$'), '');
    if (baseText.isNotEmpty) {
      parts.addAll(baseText.split('/').where((part) => part.trim().isNotEmpty));
    }
    for (final segment in segments) {
      final clean = segment.trim().replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), '');
      if (clean.isEmpty) continue;
      parts.add(clean);
    }
    return parts.isEmpty ? '/' : '/${parts.join('/')}';
  }

  List<String> _relativeSegments(String rootPath, String childPath) {
    final root = rootPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final child = childPath.replaceAll('\\', '/');
    var relative = child.startsWith('$root/') ? child.substring(root.length + 1) : _localName(childPath);
    return relative
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> _ensureRemoteFolder(String remotePath) async {
    try {
      await FileService().createFile(
        uri: remotePath,
        type: 'folder',
        errOnConflict: false,
      );
      return true;
    } catch (_) {
      // 文件夹已存在、无返回体或服务端兼容差异时，不中断后续文件上传。
      return false;
    }
  }

  /// 桌面端文件夹上传：先按本地目录结构创建远程文件夹，再把文件加入上传队列。
  Future<FolderUploadResult> startUploadDirectory(
    Directory directory,
    String targetPath, {
    bool overwrite = false,
    bool hidden = false,
  }) async {
    if (!await directory.exists()) {
      return const FolderUploadResult();
    }

    final rootPath = directory.absolute.path;
    final rootName = _localName(rootPath);
    final remoteFolders = <String>{_joinRemotePath(targetPath, [rootName])};
    final fileEntries = <_FolderUploadFile>[];
    var skipped = 0;

    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      final segments = _relativeSegments(rootPath, entity.path);
      if (segments.isEmpty) {
        skipped++;
        continue;
      }

      if (type == FileSystemEntityType.directory) {
        remoteFolders.add(_joinRemotePath(targetPath, [rootName, ...segments]));
      } else if (type == FileSystemEntityType.file) {
        final parentSegments = segments.length > 1
            ? segments.sublist(0, segments.length - 1)
            : const <String>[];
        final remoteParent = _joinRemotePath(targetPath, [rootName, ...parentSegments]);
        remoteFolders.add(remoteParent);
        fileEntries.add(_FolderUploadFile(File(entity.path), remoteParent));
      } else {
        skipped++;
      }
    }

    final orderedFolders = remoteFolders.toList()
      ..sort((a, b) => a.length == b.length ? a.compareTo(b) : a.length.compareTo(b.length));

    var ensuredFolders = 0;
    for (final remoteFolder in orderedFolders) {
      if (await _ensureRemoteFolder(remoteFolder)) ensuredFolders++;
    }

    final ids = <String>[];
    for (final entry in fileEntries) {
      final file = entry.file;
      final task = UploadTaskModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.path}',
        file: file,
        fileName: _localName(file.path),
        fileSize: await file.length(),
        targetPath: _normalizeTargetPath(entry.remoteParentPath),
        overwrite: overwrite,
        hidden: hidden,
      );
      _uploadService.addTask(task);
      _uploadService.startUpload(task);
      ids.add(task.id);
    }

    return FolderUploadResult(
      queuedFiles: ids.length,
      ensuredFolders: ensuredFolders,
      skippedEntries: skipped,
      taskIds: ids,
    );
  }

  /// 兼容旧入口：从 dart:io File 开始上传。
  ///
  /// 桌面端拖拽上传、部分旧逻辑仍会调用这个方法。
  ///
  /// 返回创建的 UploadTaskModel id 列表，调用方需要时可监听这些 id 的状态。
  Future<List<String>> startUpload(
    List<File> files,
    String targetPath, {
    bool overwrite = false,
    bool hidden = false,
  }) async {
    final uri = _normalizeTargetPath(targetPath);
    final ids = <String>[];

    for (final file in files) {
      final task = UploadTaskModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.path}',
        file: file,
        fileName: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : file.path.split(Platform.pathSeparator).last,
        fileSize: await file.length(),
        targetPath: uri,
        overwrite: overwrite,
        hidden: hidden,
      );

      _uploadService.addTask(task);
      _uploadService.startUpload(task);
      ids.add(task.id);
    }
    return ids;
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

class FolderUploadResult {
  final int queuedFiles;
  final int ensuredFolders;
  final int skippedEntries;
  final List<String> taskIds;

  const FolderUploadResult({
    this.queuedFiles = 0,
    this.ensuredFolders = 0,
    this.skippedEntries = 0,
    this.taskIds = const [],
  });

  bool get isEmpty => queuedFiles == 0 && ensuredFolders == 0;
}

class _FolderUploadFile {
  final File file;
  final String remoteParentPath;

  const _FolderUploadFile(this.file, this.remoteParentPath);
}

