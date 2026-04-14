import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/download_task_model.dart';
import '../providers/download_manager_provider.dart';
import 'download_progress_item.dart';

/// 下载进度对话框
class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadManagerProvider>(
      builder: (context, downloadManager, child) {
        final tasks = downloadManager.tasks;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300,
              // 当没有任务时，最小高度约为2个任务的大小（约160px）
              minHeight: tasks.isEmpty ? 160 : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                _buildHeader(context),

                // 任务列表
                Flexible(
                  child: tasks.isEmpty
                      ? _buildEmptyState(context)
                      : _buildTaskList(context, downloadManager, tasks),
                ),

                // 底部操作栏
                _buildFooter(context, tasks),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_done,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无下载任务',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    DownloadManagerProvider downloadManager,
    List<DownloadTaskModel> tasks,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return DownloadProgressItem(
          key: ValueKey(task.id),
          task: task,
          onPause: () => downloadManager.pauseDownload(task.id),
          onResume: () => downloadManager.resumeDownload(task.id),
          onCancel: () => downloadManager.cancelDownload(task.id),
          onDelete: () async {
            await downloadManager.deleteDownloadTask(task.id);
          },
          onRetry: () => downloadManager.retryDownload(task.id),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.download, color: Colors.blue),
          const SizedBox(width: 12),
          const Text(
            '下载任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Consumer<DownloadManagerProvider>(
            builder: (context, downloadManager, child) {
              final downloadingCount = downloadManager.downloadingCount;
              if (downloadingCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '下载中: $downloadingCount',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, List<DownloadTaskModel> tasks) {
    final hasCompleted = tasks.any((t) => t.status == DownloadStatus.completed);
    final hasFailed = tasks.any((t) => t.status == DownloadStatus.failed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          if (hasCompleted)
            Consumer<DownloadManagerProvider>(
              builder: (context, downloadManager, child) {
                return TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('清除已完成'),
                  onPressed: () async {
                    await downloadManager.clearCompletedTasks();
                  },
                );
              },
            ),
          if (hasFailed)
            Consumer<DownloadManagerProvider>(
              builder: (context, downloadManager, child) {
                return TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('清除失败'),
                  onPressed: () {
                    downloadManager.clearFailedTasks();
                  },
                );
              },
            ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 显示下载对话框
void showDownloadDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const DownloadProgressDialog(),
    barrierDismissible: false,
  );
}
