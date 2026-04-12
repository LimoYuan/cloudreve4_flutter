import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../services/upload_service.dart';

/// 上传管理Provider
class UploadManagerProvider extends ChangeNotifier {
  bool _showUploadDialog = false;

  bool get showUploadDialog => _showUploadDialog;

  final UploadService _uploadService = UploadService.instance;

  List<UploadTask> get allTasks => _uploadService.allTasks;
  List<UploadTask> get activeTasks => _uploadService.activeTasks;

  void toggleUploadDialog() {
    _showUploadDialog = !_showUploadDialog;
    notifyListeners();
  }

  void setShowUploadDialog(bool value) {
    _showUploadDialog = value;
    notifyListeners();
  }

  /// 开始上传
  Future<void> startUpload(
    List<File> files,
    String targetPath,
  ) async {
    setShowUploadDialog(true);

    for (final file in files) {
      final task = UploadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString() + file.path,
        file: file,
        fileName: file.path.split('/').last,
        fileSize: await file.length(),
      );

      _uploadService.addTask(task);

      await _uploadService.uploadFile(
        task: task,
        onProgress: (progress) {
          // Progress updates are handled by the service
        },
      );
    }
  }

  /// 取消上传
  void cancelUpload(String taskId) {
    _uploadService.cancelUpload(taskId);
  }

  /// 清除所有已完成的任务
  void clearCompletedTasks() {
    final completedTasks = _uploadService.allTasks
        .where((t) => t.completed || t.cancelled)
        .map((t) => t.id)
        .toList();

    for (final taskId in completedTasks) {
      _uploadService.removeTask(taskId);
    }

    if (_uploadService.allTasks.isEmpty) {
      setShowUploadDialog(false);
    }
  }
}
