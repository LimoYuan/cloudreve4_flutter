import 'package:cloudreve4_flutter/data/models/download_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/download_progress_item.dart';
import 'package:cloudreve4_flutter/core/utils/date_utils.dart' as date_utils;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class DownloadTasksTab extends StatelessWidget {
  const DownloadTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DownloadManagerProvider>(
      builder: (context, downloadManager, _) {
        final allTasks = downloadManager.tasks;
        final activeTasks = allTasks.where((t) =>
            t.status == DownloadStatus.downloading || t.status == DownloadStatus.waiting || t.status == DownloadStatus.paused).toList();
        final completedTasks = allTasks.where((t) => t.status == DownloadStatus.completed).toList();
        final failedTasks = allTasks.where((t) =>
            t.status == DownloadStatus.failed || t.status == DownloadStatus.cancelled).toList();

        if (allTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.download, size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('暂无下载任务', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          children: [
            if (activeTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '进行中', activeTasks.length),
              ...activeTasks.map((task) => DownloadProgressItem(
                task: task,
                onPause: () => downloadManager.pauseDownload(task.id),
                onResume: () => downloadManager.resumeDownload(task.id),
                onCancel: () => downloadManager.cancelDownload(task.id),
              )),
            ],
            if (failedTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '失败', failedTasks.length,
                  actionLabel: '清除失败',
                  onAction: () => _confirmClear(context, '失败', failedTasks.length, () => downloadManager.clearFailedTasks())),
              ...failedTasks.map((task) => DownloadProgressItem(
                task: task,
                onRetry: () => downloadManager.retryDownload(task.id),
                onDelete: () => _confirmDeleteDownloadTask(context, task, downloadManager),
              )),
            ],
            if (completedTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '已完成', completedTasks.length,
                  actionLabel: '清除已完成',
                  onAction: () => _confirmClear(context, '已完成', completedTasks.length, () => downloadManager.clearCompletedTasks())),
              ...completedTasks.map((task) => DownloadProgressItem(
                task: task,
                onDelete: () => _confirmDeleteDownloadTask(context, task, downloadManager),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              icon: const Icon(LucideIcons.trash2, size: 14),
              label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, String label, int count, VoidCallback onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清除$label'),
        content: Text('确定要清除 $count 个$label的任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  Future<void> _confirmDeleteDownloadTask(
    BuildContext context,
    DownloadTaskModel task,
    DownloadManagerProvider downloadManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除下载任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要删除该任务吗？'),
            const SizedBox(height: 8),
            Text(task.fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('下载时间: ${_formatDateTime(task.createdAt)}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
            Text('文件大小: ${date_utils.DateUtils.formatFileSize(task.fileSize)}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) downloadManager.deleteDownloadTask(task.id);
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
