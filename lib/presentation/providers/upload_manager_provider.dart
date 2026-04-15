import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/upload_task_model.dart';
import '../../services/upload_service.dart';
import '../widgets/upload_progress_dialog.dart';

/// 上传管理Provider
class UploadManagerProvider extends ChangeNotifier {
  final UploadService _uploadService = UploadService.instance;
  bool _isInitialized = false;

  bool get showUploadDialog => _uploadService.allTasks.isNotEmpty;
  List<UploadTaskModel> get allTasks => _uploadService.allTasks;
  List<UploadTaskModel> get activeTasks => _uploadService.activeTasks;

  /// 初始化上传管理器
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _uploadService.initialize();
    _isInitialized = true;
    debugPrint('UploadManagerProvider 初始化完成');
  }

  /// 开始上传
  Future<void> startUpload(
    List<File> files,
    String targetPath,
  ) async {
    for (final file in files) {
      // 构建目标路径 URI
      String uri;
      if (targetPath.startsWith('cloudreve://my')) {
        uri = targetPath;
      } else {
        // 移除前导斜杠避免重复
        String pathPart = targetPath;
        if (pathPart.startsWith('/')) {
          pathPart = pathPart.substring(1);
        }
        uri = pathPart.isEmpty ? 'cloudreve://my' : 'cloudreve://my/$pathPart';
      }

      final task = UploadTaskModel(
        id: DateTime.now().millisecondsSinceEpoch.toString() + file.path,
        file: file,
        fileName: file.path.split('/').last,
        fileSize: await file.length(),
        targetPath: uri,
      );
      debugPrint('UploadTaskModel -> ${task.toJson()}');
      _uploadService.addTask(task);

      // 开始上传任务
      _uploadService.startUpload(task);
    }
  }

  /// 取消上传
  void cancelUpload(String taskId) {
    _uploadService.cancelUpload(taskId);
  }

  /// 重试上传
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

  /// 清除失败的任务
  void clearFailedTasks() {
    _uploadService.clearFailedTasks();
  }
}

/// 显示上传对话框的帮助函数
void showUploadDialogWidget(BuildContext context) {
  showUploadDialog(context);
}
