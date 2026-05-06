import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'widgets/upload_tasks_tab.dart';
import 'widgets/download_tasks_tab.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务'),
          bottom: const _TasksTabBar(),
        ),
        body: const TabBarView(
          children: [
            UploadTasksTab(),
            DownloadTasksTab(),
          ],
        ),
      ),
    );
  }
}

class _TasksTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _TasksTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Consumer2<UploadManagerProvider, DownloadManagerProvider>(
      builder: (context, uploadManager, downloadManager, _) {
        final uploadActiveCount = uploadManager.allTasks
            .where((t) =>
                t.status == UploadStatus.uploading ||
                t.status == UploadStatus.waiting ||
                t.status == UploadStatus.paused)
            .length;
        final downloadActiveCount = downloadManager.activeTaskCount;

        return TabBar(
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.upload, size: 18),
                  const SizedBox(width: 6),
                  const Text('上传'),
                  if (uploadActiveCount > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: uploadActiveCount),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.download, size: 18),
                  const SizedBox(width: 6),
                  const Text('下载'),
                  if (downloadActiveCount > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(count: downloadActiveCount),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
