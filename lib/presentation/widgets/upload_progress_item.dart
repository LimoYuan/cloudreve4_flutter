import 'package:flutter/material.dart';
import '../../data/models/upload_task_model.dart';

/// 上传任务列表项
class UploadProgressItem extends StatelessWidget {
  final UploadTaskModel task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;

  const UploadProgressItem({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isUploading = task.status == UploadStatus.uploading;
    final isWaiting = task.status == UploadStatus.waiting;
    final isCompleted = task.status == UploadStatus.completed;
    final isPaused = task.status == UploadStatus.paused;
    final isFailed = task.status == UploadStatus.failed;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文件名和状态
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(task.status),
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildActionButtons(context, task),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 进度条
            if (isUploading || isWaiting || isPaused) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: isPaused ? null : task.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPaused ? '已暂停' : task.progressText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${task.uploadedBytes}/${task.fileSize} bytes',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    task.readableFileSize,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ] else if (isFailed && task.errorMessage != null) ...[
              Text(
                task.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (isCompleted) ...[
              Text(
                '完成时间: ${_formatDateTime(task.completedAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    UploadTaskModel task,
  ) {
    switch (task.status) {
      case UploadStatus.waiting:
      case UploadStatus.uploading:
        return [
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            onPressed: onPause,
            tooltip: '暂停',
          ),
        ];
      case UploadStatus.paused:
        return [
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: onResume,
            tooltip: '继续',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, size: 20),
            onPressed: onCancel,
            tooltip: '取消',
          ),
        ];
      case UploadStatus.failed:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRetry,
            tooltip: '重试',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case UploadStatus.completed:
        return [
          IconButton(
            icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
            onPressed: null,
            tooltip: '已完成',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case UploadStatus.cancelled:
        return [
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
    }
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.waiting:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.paused:
        return Colors.orange;
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
