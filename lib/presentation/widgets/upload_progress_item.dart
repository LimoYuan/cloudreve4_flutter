import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/upload_task_model.dart';

/// 上传任务列表项
class UploadProgressItem extends StatelessWidget {
  final UploadTaskModel task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onNavigate;

  const UploadProgressItem({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onDelete,
    this.onRetry,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isUploading = task.status == UploadStatus.uploading;
    final isWaiting = task.status == UploadStatus.waiting;
    final isPaused = task.status == UploadStatus.paused;
    final isFailed = task.status == UploadStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _getCardColor(context, task.status),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getBorderColor(context, task.status),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusIcon(context, task.status),
                    const SizedBox(width: 10),
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
                          _buildStatusRow(context, task),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildActionButtons(context, task),
                    ),
                  ],
                ),
                if (isUploading || isWaiting || isPaused) ...[
                  const SizedBox(height: 10),
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
                      if (isUploading && task.speedText.isNotEmpty) ...[
                        Text(
                          task.speedText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        task.readableFileSize,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ] else if (isFailed && task.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, UploadStatus status) {
    final color = _getStatusColor(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getStatusIcon(status),
        size: 18,
        color: color,
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, UploadTaskModel task) {
    final color = _getStatusColor(task.status);
    final isCompleted = task.status == UploadStatus.completed;

    return Row(
      children: [
        Text(
          task.statusText,
          style: TextStyle(fontSize: 12, color: color),
        ),
        if (isCompleted) ...[
          Text(
            ' · ',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          Text(
            task.readableFileSize,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          Text(
            ' · ',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          Text(
            _formatDateTime(task.completedAt!),
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    UploadTaskModel task,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;

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
            icon: Icon(Icons.cancel, size: 20, color: errorColor),
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
            icon: Icon(Icons.delete, size: 20, color: errorColor),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case UploadStatus.completed:
        return [
          if (onNavigate != null)
            IconButton(
              icon: const Icon(LucideIcons.folderOpen, size: 20),
              onPressed: onNavigate,
              tooltip: '打开文件夹',
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: errorColor),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case UploadStatus.cancelled:
        return [
          IconButton(
            icon: Icon(Icons.delete, size: 20, color: errorColor),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
    }
  }

  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.waiting:
        return LucideIcons.clock;
      case UploadStatus.uploading:
        return LucideIcons.upload;
      case UploadStatus.completed:
        return LucideIcons.checkCircle2;
      case UploadStatus.paused:
        return LucideIcons.pause;
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return LucideIcons.xCircle;
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

  Color _getCardColor(BuildContext context, UploadStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case UploadStatus.completed:
        return isDark ? Colors.green.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.05);
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.05);
      default:
        return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6);
    }
  }

  Color _getBorderColor(BuildContext context, UploadStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case UploadStatus.completed:
        return Colors.green.withValues(alpha: isDark ? 0.2 : 0.15);
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return Colors.red.withValues(alpha: isDark ? 0.2 : 0.15);
      default:
        return isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3);
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
