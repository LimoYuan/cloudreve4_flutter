import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/upload_task_model.dart';
import '../../services/upload_service.dart';
import '../providers/upload_manager_provider.dart';
import 'upload_progress_item.dart';

/// 上传进度对话框
class UploadProgressDialog extends StatelessWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadService>(
      builder: (context, uploadService, child) {
        final tasks = uploadService.allTasks;

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
                _buildHeader(context, uploadService, tasks),

                // 任务列表
                Flexible(
                  child: tasks.isEmpty
                      ? _buildEmptyState(context)
                      : _buildTaskList(context, uploadService, tasks),
                ),

                // 底部操作栏
                _buildFooter(context, uploadService, tasks),
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
            Icons.cloud_upload,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无上传任务',
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
    UploadService uploadService,
    List<UploadTaskModel> tasks,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return UploadProgressItem(
          key: ValueKey(task.id),
          task: task,
          onPause: () => uploadService.cancelUpload(task.id),
          onResume: () => uploadService.retryUpload(task.id),
          onCancel: () => uploadService.cancelUpload(task.id),
          onDelete: () async {
            uploadService.removeTask(task.id);
          },
          onRetry: () => uploadService.retryUpload(task.id),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UploadService uploadService,
    List<UploadTaskModel> tasks,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload, color: Colors.blue),
          const SizedBox(width: 12),
          const Text(
            '上传任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Consumer<UploadService>(
            builder: (context, uploadService, child) {
              final uploadingCount = uploadService.activeTasks.length;
              if (uploadingCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '上传中: $uploadingCount',
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
              final uploadManager = Provider.of<UploadManagerProvider>(
                context,
                listen: false,
              );
              uploadManager.hideDialog();
              Navigator.of(context).pop();
            },
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    UploadService uploadService,
    List<UploadTaskModel> tasks,
  ) {
    final hasCompleted = tasks.any((t) => t.status == UploadStatus.completed);
    final hasFailed = tasks.any((t) => t.status == UploadStatus.failed);
    final hasCancelled = tasks.any((t) => t.status == UploadStatus.cancelled);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          if (hasCompleted || hasCancelled)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('清除已完成'),
              onPressed: () async {
                uploadService.clearCompletedTasks();
              },
            ),
          if (hasFailed)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('清除失败'),
              onPressed: () {
                uploadService.clearFailedTasks();
              },
            ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              final uploadManager = Provider.of<UploadManagerProvider>(
                context,
                listen: false,
              );
              uploadManager.hideDialog();
              Navigator.of(context).pop();
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 显示上传对话框
void showUploadDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const UploadProgressDialog(),
    barrierDismissible: false,
  );
}
