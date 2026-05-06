import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/upload_progress_item.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class UploadTasksTab extends StatelessWidget {
  const UploadTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<UploadManagerProvider>(
      builder: (context, uploadManager, _) {
        final allTasks = uploadManager.allTasks;
        final activeTasks = allTasks.where((t) =>
            t.status == UploadStatus.uploading || t.status == UploadStatus.waiting || t.status == UploadStatus.paused).toList();
        final completedTasks = allTasks.where((t) => t.status == UploadStatus.completed).toList();
        final failedTasks = allTasks.where((t) =>
            t.status == UploadStatus.failed || t.status == UploadStatus.cancelled).toList();

        if (allTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.upload, size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('暂无上传任务', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          children: [
            if (activeTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '进行中', activeTasks.length),
              ...activeTasks.map((task) => UploadProgressItem(
                task: task,
                onPause: () => uploadManager.cancelUpload(task.id),
                onResume: () => uploadManager.retryUpload(task.id),
                onCancel: () => uploadManager.cancelUpload(task.id),
              )),
            ],
            if (failedTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '失败', failedTasks.length,
                  actionLabel: '清除失败',
                  onAction: () => _confirmClear(context, '失败', failedTasks.length, () => uploadManager.clearFailedTasks())),
              ...failedTasks.map((task) => UploadProgressItem(
                task: task,
                onRetry: () => uploadManager.retryUpload(task.id),
                onDelete: () => _confirmDeleteUploadTask(context, task, uploadManager),
              )),
            ],
            if (completedTasks.isNotEmpty) ...[
              _buildSectionHeader(context, '已完成', completedTasks.length,
                  actionLabel: '清除已完成',
                  onAction: () => _confirmClear(context, '已完成', completedTasks.length, () => uploadManager.clearCompletedTasks())),
              ...completedTasks.map((task) => UploadProgressItem(
                task: task,
                onDelete: () => _confirmDeleteUploadTask(context, task, uploadManager),
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

  Future<void> _confirmDeleteUploadTask(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除上传任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要删除该任务吗？'),
            const SizedBox(height: 8),
            Text(task.fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('上传时间: ${_formatDateTime(task.createdAt)}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
            Text('文件大小: ${task.readableFileSize}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
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
    if (confirmed == true) uploadManager.removeTask(task.id);
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
