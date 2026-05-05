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

        return Column(
          children: [
            Expanded(
              child: ListView(
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
                    _buildSectionHeader(context, '失败', failedTasks.length),
                    ...failedTasks.map((task) => UploadProgressItem(
                      task: task,
                      onRetry: () => uploadManager.retryUpload(task.id),
                      onDelete: () => uploadManager.removeTask(task.id),
                    )),
                  ],
                  if (completedTasks.isNotEmpty) ...[
                    _buildSectionHeader(context, '已完成', completedTasks.length),
                    ...completedTasks.map((task) => UploadProgressItem(
                      task: task,
                      onDelete: () => uploadManager.removeTask(task.id),
                    )),
                  ],
                ],
              ),
            ),
            if (completedTasks.isNotEmpty || failedTasks.isNotEmpty)
              _buildBottomActions(context, uploadManager, completedTasks.isNotEmpty, failedTasks.isNotEmpty),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    UploadManagerProvider uploadManager,
    bool hasCompleted,
    bool hasFailed,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasCompleted)
            TextButton.icon(
              icon: const Icon(LucideIcons.checkCircle, size: 16),
              label: const Text('清除已完成'),
              onPressed: () => uploadManager.clearCompletedTasks(),
            ),
          if (hasFailed) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(LucideIcons.xCircle, size: 16),
              label: const Text('清除失败'),
              onPressed: () => uploadManager.clearFailedTasks(),
            ),
          ],
        ],
      ),
    );
  }
}
