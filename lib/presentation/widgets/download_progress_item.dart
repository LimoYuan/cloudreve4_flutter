import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../data/models/download_task_model.dart';
import '../../services/download_service.dart';
import '../providers/download_manager_provider.dart';
import 'toast_helper.dart';
import '../../core/utils/app_logger.dart';

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
    final downloadManager = Provider.of<DownloadManagerProvider>(
      context,
      listen: true,
    );
    final latestTask = downloadManager.getTask(task.id) ?? task;

    final isDownloading = latestTask.status == DownloadStatus.downloading;
    final isCompleted = latestTask.status == DownloadStatus.completed;
    final isPaused = latestTask.status == DownloadStatus.paused;
    final isFailed = latestTask.status == DownloadStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _getCardColor(context, latestTask.status, waitingForWifi: latestTask.waitingForWifi),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getBorderColor(context, latestTask.status, waitingForWifi: latestTask.waitingForWifi),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusIcon(context, latestTask.status, waitingForWifi: latestTask.waitingForWifi),
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
                          _buildStatusRow(context, latestTask),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildActionButtons(context, latestTask),
                    ),
                  ],
                ),
                if (isDownloading || isPaused) ...[
                  const SizedBox(height: 10),
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
                        isPaused ? '已暂停' : latestTask.progressText,
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
                      if (latestTask.speedText.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          latestTask.speedText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else if (isFailed && latestTask.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    latestTask.errorMessage!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
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

  Widget _buildStatusIcon(BuildContext context, DownloadStatus status, {bool waitingForWifi = false}) {
    final color = _getStatusColor(status, waitingForWifi: waitingForWifi);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getStatusIcon(status, waitingForWifi: waitingForWifi),
        size: 18,
        color: color,
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, DownloadTaskModel task) {
    final color = _getStatusColor(task.status, waitingForWifi: task.waitingForWifi);
    final isCompleted = task.status == DownloadStatus.completed;

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
            DownloadService.getReadableFileSize(task.fileSize),
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
    DownloadTaskModel task,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;

    switch (task.status) {
      case DownloadStatus.waiting:
        if (task.waitingForWifi) {
          return [
            IconButton(
              icon: Icon(Icons.cancel, size: 20, color: errorColor),
              onPressed: onCancel,
              tooltip: '取消',
            ),
          ];
        }
        return [];
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
            icon: Icon(Icons.cancel, size: 20, color: errorColor),
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
            icon: Icon(Icons.delete, size: 20, color: errorColor),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case DownloadStatus.completed:
        return [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => _openDownloadedFile(context, task),
            tooltip: '打开',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: errorColor),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ];
      case DownloadStatus.cancelled:
        return [];
    }
  }

  Future<void> checkInstallPermission() async {
    if (await Permission.requestInstallPackages.isDenied) {
      await Permission.requestInstallPackages.request();
    }
  }

  Future<void> _openDownloadedFile(
    BuildContext context,
    DownloadTaskModel task,
  ) async {
    final file = File(task.savePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ToastHelper.error('文件不存在：${task.fileName}');
      }
      return;
    }

    try {
      final ext = task.savePath.toString().split('.').last.toLowerCase();
      if (ext == 'apk') {
        await checkInstallPermission();
      }

      OpenResult openResult = await OpenFile.open(task.savePath);
      AppLogger.d('下载对话框打开文件结果：${openResult.type}');
      if (openResult.type == ResultType.done) {
        AppLogger.d('成功打开文件：${task.fileName}');
      } else {
        if (context.mounted) {
          ToastHelper.error(
            '无法打开文件：${task.fileName} 错误信息: ${openResult.message}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.error('打开文件失败：$e');
      }
    }
  }

  IconData _getStatusIcon(DownloadStatus status, {bool waitingForWifi = false}) {
    switch (status) {
      case DownloadStatus.waiting:
        return waitingForWifi ? LucideIcons.wifi : LucideIcons.clock;
      case DownloadStatus.downloading:
        return LucideIcons.download;
      case DownloadStatus.completed:
        return LucideIcons.checkCircle2;
      case DownloadStatus.paused:
        return LucideIcons.pause;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return LucideIcons.xCircle;
    }
  }

  Color _getStatusColor(DownloadStatus status, {bool waitingForWifi = false}) {
    switch (status) {
      case DownloadStatus.waiting:
        return waitingForWifi ? Colors.blue : Colors.grey;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return Colors.red;
    }
  }

  Color _getCardColor(BuildContext context, DownloadStatus status, {bool waitingForWifi = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case DownloadStatus.waiting:
        if (waitingForWifi) {
          return isDark ? Colors.blue.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.05);
        }
        return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6);
      case DownloadStatus.completed:
        return isDark ? Colors.green.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.05);
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.05);
      default:
        return isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6);
    }
  }

  Color _getBorderColor(BuildContext context, DownloadStatus status, {bool waitingForWifi = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case DownloadStatus.waiting:
        if (waitingForWifi) {
          return Colors.blue.withValues(alpha: isDark ? 0.2 : 0.15);
        }
        return isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3);
      case DownloadStatus.completed:
        return Colors.green.withValues(alpha: isDark ? 0.2 : 0.15);
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
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
