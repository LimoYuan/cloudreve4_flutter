import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(LucideIcons.upload, size: 18),
                text: '上传',
              ),
              Tab(
                icon: const Icon(LucideIcons.download, size: 18),
                text: '下载',
              ),
            ],
          ),
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
