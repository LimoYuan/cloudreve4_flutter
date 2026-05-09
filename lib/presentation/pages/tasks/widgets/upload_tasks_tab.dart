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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            if (isDesktop) {
              return _buildDesktopLayout(
                context,
                uploadManager,
                allTasks: allTasks,
                activeTasks: activeTasks,
                failedTasks: failedTasks,
                completedTasks: completedTasks,
              );
            }

            return _buildMobileLayout(
              context,
              uploadManager,
              activeTasks: activeTasks,
              failedTasks: failedTasks,
              completedTasks: completedTasks,
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    UploadManagerProvider uploadManager, {
    required List<UploadTaskModel> activeTasks,
    required List<UploadTaskModel> failedTasks,
    required List<UploadTaskModel> completedTasks,
  }) {
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
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    UploadManagerProvider uploadManager, {
    required List<UploadTaskModel> allTasks,
    required List<UploadTaskModel> activeTasks,
    required List<UploadTaskModel> failedTasks,
    required List<UploadTaskModel> completedTasks,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final sortedTasks = [
      ...activeTasks,
      ...failedTasks,
      ...completedTasks,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
            if (failedTasks.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('清除失败', style: TextStyle(fontSize: 12)),
                    onPressed: () => _confirmClear(context, '失败', failedTasks.length, () => uploadManager.clearFailedTasks()),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            if (completedTasks.isNotEmpty && failedTasks.isEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('清除已完成', style: TextStyle(fontSize: 12)),
                    onPressed: () => _confirmClear(context, '已完成', completedTasks.length, () => uploadManager.clearCompletedTasks()),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: DataTable(
                headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('名称')),
                  DataColumn(label: Text('状态')),
                  DataColumn(label: Text('进度')),
                  DataColumn(label: Text('大小')),
                  DataColumn(label: Text('操作')),
                ],
                rows: sortedTasks.map((task) => _buildUploadDataRow(context, task, uploadManager)).toList(),
              ),
            ),
            ),
          ],
        ),
    );
  }

  DataRow _buildUploadDataRow(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = colorScheme.error;
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);
    final isActive = task.status == UploadStatus.uploading ||
        task.status == UploadStatus.waiting ||
        task.status == UploadStatus.paused;

    return DataRow(
      cells: [
        // 名称 (with status icon)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // 状态
        DataCell(
          Text(
            task.statusText,
            style: TextStyle(color: statusColor, fontSize: 13),
          ),
        ),
        // 进度
        DataCell(
          isActive
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: task.status == UploadStatus.paused ? null : task.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.status == UploadStatus.paused ? '已暂停' : task.progressText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              : Text(
                  task.status == UploadStatus.completed ? '100%' : '-',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
        // 大小
        DataCell(Text(task.readableFileSize, style: const TextStyle(fontSize: 13))),
        // 操作
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildDesktopActionButtons(context, task, uploadManager, errorColor),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDesktopActionButtons(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
    Color errorColor,
  ) {
    switch (task.status) {
      case UploadStatus.waiting:
      case UploadStatus.uploading:
        return [
          IconButton(
            icon: const Icon(Icons.pause, size: 18),
            onPressed: () => uploadManager.cancelUpload(task.id),
            tooltip: '暂停',
          ),
        ];
      case UploadStatus.paused:
        return [
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => uploadManager.retryUpload(task.id),
            tooltip: '继续',
          ),
          IconButton(
            icon: Icon(Icons.cancel, size: 18, color: errorColor),
            onPressed: () => uploadManager.cancelUpload(task.id),
            tooltip: '取消',
          ),
        ];
      case UploadStatus.failed:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => uploadManager.retryUpload(task.id),
            tooltip: '重试',
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
            tooltip: '删除',
          ),
        ];
      case UploadStatus.completed:
        return [
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
            tooltip: '删除',
          ),
        ];
      case UploadStatus.cancelled:
        return [
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
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
