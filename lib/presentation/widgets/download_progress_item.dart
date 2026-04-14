import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';
import '../providers/download_manager_provider.dart';

/// 下载任务列表项
class DownloadProgressItem extends StatelessWidget {
  final DownloadTaskModel task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;

  const DownloadProgressItem({
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
    // 从 DownloadManagerProvider 获取最新的任务状态
    final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: true);
    final latestTask = downloadManager.getTask(task.id) ?? task;

    final isDownloading = latestTask.status == DownloadStatus.downloading;
    final isCompleted = latestTask.status == DownloadStatus.completed;
    final isPaused = latestTask.status == DownloadStatus.paused;
    final isFailed = latestTask.status == DownloadStatus.failed;

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
                        latestTask.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(latestTask.status),
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildActionButtons(latestTask),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 进度条
            if (isDownloading || isPaused) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: isPaused ? null : latestTask.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPaused
                        ? '已暂停'
                        : latestTask.progressText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${DownloadService.getReadableFileSize(latestTask.downloadedBytes)} / '
                    '${DownloadService.getReadableFileSize(latestTask.fileSize)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ] else if (isFailed && latestTask.errorMessage != null) ...[
              Text(
                latestTask.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (isCompleted) ...[
              Text(
                '完成时间: ${_formatDateTime(latestTask.completedAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

    List<Widget> _buildActionButtons(DownloadTaskModel task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return [
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            onPressed: onPause,
            tooltip: '暂停',
          ),
        ];
      case DownloadStatus.paused:
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
      case DownloadStatus.failed:
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
      case DownloadStatus.completed:
        return [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () {
              // TODO: 打开文件
            },
            tooltip: '打开',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      default:
        return [];
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
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
