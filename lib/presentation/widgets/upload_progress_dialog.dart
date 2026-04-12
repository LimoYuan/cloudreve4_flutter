import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/upload_service.dart';
import '../providers/upload_manager_provider.dart';

/// 上传进度对话框
class UploadProgressDialog extends StatelessWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Expanded(child: _buildProgressList(context)),
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<UploadManagerProvider>(
      builder: (context, uploadManager, child) {
        final tasks = uploadManager.allTasks;
        final uploadedBytes = tasks.fold<int>(0, (sum, t) => sum + t.uploadedBytes);
        final totalBytes = tasks.fold<int>(0, (sum, t) => sum + t.fileSize);

        return Row(
          children: [
            Icon(Icons.cloud_upload, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '上传文件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatBytes(uploadedBytes, totalBytes),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressList(BuildContext context) {
    return Consumer<UploadManagerProvider>(
      builder: (context, uploadManager, child) {
        return uploadManager.allTasks.isEmpty
            ? const Center(child: Text('准备上传...'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: uploadManager.allTasks.length,
                itemBuilder: (context, index) {
                  final task = uploadManager.allTasks[index];
                  return _buildTaskItem(context, task, uploadManager);
                },
              );
      },
    );
  }

  Widget _buildTaskItem(BuildContext context, UploadTask task, UploadManagerProvider uploadManager) {
    final fileName = task.fileName;
    final isError = task.error != null;
    final isCompleted = task.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildFileIcon(task, isError, isCompleted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (isError)
                  Text(
                    task.error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  )
                else
                  Text(
                    '${_formatBytes(task.uploadedBytes, task.fileSize)} - ${task.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.green.shade600 : Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progress / 100,
                  backgroundColor: isError
                      ? Colors.red.withValues(alpha: 0.1)
                      : isCompleted
                          ? Colors.green.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isError
                        ? Colors.red
                        : isCompleted
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          if (!isCompleted && !isError)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                uploadManager.cancelUpload(task.id);
              },
              tooltip: '取消',
            ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(UploadTask task, bool isError, bool isCompleted) {
    IconData icon;
    Color color;

    if (isError) {
      icon = Icons.error_outline;
      color = Colors.red;
    } else if (isCompleted) {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else {
      icon = Icons.cloud_upload_outlined;
      color = Colors.grey.shade600;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildActions(BuildContext context) {
    return Consumer<UploadManagerProvider>(
      builder: (context, uploadManager, child) {
        final hasError = uploadManager.allTasks.any((t) => t.error != null);
        final isUploading = uploadManager.activeTasks.isNotEmpty;
        final hasCompleted = uploadManager.allTasks.any((t) => t.completed || t.cancelled);

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (hasCompleted)
              TextButton(
                onPressed: () {
                  uploadManager.clearCompletedTasks();
                },
                child: const Text('清除已完成'),
              ),
            if (hasError)
              TextButton(
                onPressed: () {
                  // TODO: 实现重试功能
                },
                child: const Text('重试'),
              ),
            if (hasCompleted || hasError) const SizedBox(width: 8),
            if (isUploading)
              OutlinedButton(
                onPressed: () {
                  // 可以在这里实现全部取消
                },
                child: const Text('全部取消'),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('关闭'),
              ),
          ],
        );
      },
    );
  }

  String _formatBytes(int uploaded, int total) {
    final uploadedStr = _formatSize(uploaded);
    final totalStr = _formatSize(total);
    return '$uploadedStr / $totalStr';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
