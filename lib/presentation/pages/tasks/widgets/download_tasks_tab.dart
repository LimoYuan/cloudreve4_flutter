import 'dart:io';

import 'package:cloudreve4_flutter/data/models/download_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/desktop_constrained.dart';
import 'package:cloudreve4_flutter/presentation/widgets/download_progress_item.dart';
import 'package:cloudreve4_flutter/core/utils/date_utils.dart' as date_utils;
import 'package:cloudreve4_flutter/services/download_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloudreve4_flutter/presentation/widgets/toast_helper.dart';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            if (isDesktop) {
              return _buildDesktopLayout(
                context,
                downloadManager,
                allTasks: allTasks,
                activeTasks: activeTasks,
                failedTasks: failedTasks,
                completedTasks: completedTasks,
              );
            }

            return _buildMobileLayout(
              context,
              downloadManager,
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
    DownloadManagerProvider downloadManager, {
    required List<DownloadTaskModel> activeTasks,
    required List<DownloadTaskModel> failedTasks,
    required List<DownloadTaskModel> completedTasks,
  }) {
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
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    DownloadManagerProvider downloadManager, {
    required List<DownloadTaskModel> allTasks,
    required List<DownloadTaskModel> activeTasks,
    required List<DownloadTaskModel> failedTasks,
    required List<DownloadTaskModel> completedTasks,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final sortedTasks = [
      ...activeTasks,
      ...failedTasks,
      ...completedTasks,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DesktopConstrained(
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
                    onPressed: () => _confirmClear(context, '失败', failedTasks.length, () => downloadManager.clearFailedTasks()),
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
                    onPressed: () => _confirmClear(context, '已完成', completedTasks.length, () => downloadManager.clearCompletedTasks()),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            Card(
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
                  DataColumn(label: Text('速度')),
                  DataColumn(label: Text('操作')),
                ],
                rows: sortedTasks.map((task) => _buildDownloadDataRow(context, task, downloadManager)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDownloadDataRow(
    BuildContext context,
    DownloadTaskModel task,
    DownloadManagerProvider downloadManager,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = colorScheme.error;
    final statusColor = _getStatusColor(task.status, waitingForWifi: task.waitingForWifi);
    final statusIcon = _getStatusIcon(task.status, waitingForWifi: task.waitingForWifi);
    final isActive = task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.waiting ||
        task.status == DownloadStatus.paused;

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
                        value: task.status == DownloadStatus.paused ? null : task.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.status == DownloadStatus.paused ? '已暂停' : task.progressText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              : Text(
                  task.status == DownloadStatus.completed ? '100%' : '-',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
        // 大小
        DataCell(
          Text(
            DownloadService.getReadableFileSize(task.fileSize),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        // 速度
        DataCell(
          Text(
            task.speedText.isNotEmpty ? task.speedText : '-',
            style: TextStyle(
              fontSize: 13,
              color: task.speedText.isNotEmpty ? colorScheme.primary : null,
            ),
          ),
        ),
        // 操作
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildDesktopActionButtons(context, task, downloadManager, errorColor),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDesktopActionButtons(
    BuildContext context,
    DownloadTaskModel task,
    DownloadManagerProvider downloadManager,
    Color errorColor,
  ) {
    switch (task.status) {
      case DownloadStatus.waiting:
        if (task.waitingForWifi) {
          return [
            IconButton(
              icon: Icon(Icons.cancel, size: 18, color: errorColor),
              onPressed: () => downloadManager.cancelDownload(task.id),
              tooltip: '取消',
            ),
          ];
        }
        return [];
      case DownloadStatus.downloading:
        return [
          IconButton(
            icon: const Icon(Icons.pause, size: 18),
            onPressed: () => downloadManager.pauseDownload(task.id),
            tooltip: '暂停',
          ),
        ];
      case DownloadStatus.paused:
        return [
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => downloadManager.resumeDownload(task.id),
            tooltip: '继续',
          ),
          IconButton(
            icon: Icon(Icons.cancel, size: 18, color: errorColor),
            onPressed: () => downloadManager.cancelDownload(task.id),
            tooltip: '取消',
          ),
        ];
      case DownloadStatus.failed:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => downloadManager.retryDownload(task.id),
            tooltip: '重试',
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteDownloadTask(context, task, downloadManager),
            tooltip: '删除',
          ),
        ];
      case DownloadStatus.completed:
        final showOpenFolder = !Platform.isAndroid;
        return [
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => _openDownloadedFile(context, task),
            tooltip: '打开',
          ),
          if (showOpenFolder)
            IconButton(
              icon: const Icon(Icons.folder_open, size: 18),
              onPressed: () => _openFileFolder(context, task),
              tooltip: '打开文件夹',
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteDownloadTask(context, task, downloadManager),
            tooltip: '删除',
          ),
        ];
      case DownloadStatus.cancelled:
        return [];
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

  Future<void> _openFileFolder(
    BuildContext context,
    DownloadTaskModel task,
  ) async {
    try {
      final dir = File(task.savePath).parent.path;
      final result = await OpenFile.open(dir);
      if (result.type != ResultType.done && context.mounted) {
        ToastHelper.error('无法打开文件夹：${result.message}');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.error('打开文件夹失败：$e');
      }
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
