import 'package:cloudreve4_flutter/data/models/download_task_model.dart';
import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(LucideIcons.activity, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('最近活动', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Consumer2<UploadManagerProvider, DownloadManagerProvider>(
          builder: (context, uploadProvider, downloadProvider, _) {
            final activities = _mergeActivities(uploadProvider.allTasks, downloadProvider.tasks);

            if (activities.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.activity, size: 40, color: theme.hintColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('暂无活动记录', style: TextStyle(color: theme.hintColor)),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: activities.take(10).map((item) => _buildActivityItem(context, item)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  List<_ActivityItem> _mergeActivities(
    List<UploadTaskModel> uploads,
    List<DownloadTaskModel> downloads,
  ) {
    final items = <_ActivityItem>[];

    for (final u in uploads) {
      items.add(_ActivityItem(
        name: u.fileName,
        type: _ActivityType.upload,
        status: _mapUploadStatus(u.status),
        createdAt: DateTime.now(), // UploadTaskModel 可能没有 createdAt
        path: u.targetPath.replaceFirst('cloudreve://my', ''),
      ));
    }

    for (final d in downloads) {
      items.add(_ActivityItem(
        name: d.fileName,
        type: _ActivityType.download,
        status: _mapDownloadStatus(d.status),
        createdAt: d.createdAt,
        path: d.fileUri,
      ));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  _ActivityStatus _mapUploadStatus(UploadStatus status) {
    switch (status) {
      case UploadStatus.completed:
        return _ActivityStatus.completed;
      case UploadStatus.failed:
        return _ActivityStatus.failed;
      case UploadStatus.uploading:
        return _ActivityStatus.active;
      default:
        return _ActivityStatus.pending;
    }
  }

  _ActivityStatus _mapDownloadStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return _ActivityStatus.completed;
      case DownloadStatus.failed:
        return _ActivityStatus.failed;
      case DownloadStatus.downloading:
        return _ActivityStatus.active;
      default:
        return _ActivityStatus.pending;
    }
  }

  Widget _buildActivityItem(BuildContext context, _ActivityItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUpload = item.type == _ActivityType.upload;

    return ListTile(
      dense: true,
      leading: Icon(
        isUpload ? LucideIcons.upload : LucideIcons.download,
        size: 20,
        color: _statusColor(item.status, colorScheme),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        _statusLabel(item),
        style: theme.textTheme.bodySmall?.copyWith(color: _statusColor(item.status, colorScheme)),
      ),
      trailing: item.status == _ActivityStatus.completed
          ? IconButton(
              icon: Icon(LucideIcons.folderOpen, size: 18, color: theme.hintColor),
              tooltip: '打开目录',
              onPressed: () {
                final navProvider = Provider.of<NavigationProvider>(context, listen: false);
                final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
                navProvider.setIndex(1);
                final parentPath = _getParentPath(item.path);
                fileManager.enterFolder(parentPath);
              },
            )
          : null,
    );
  }

  String _getParentPath(String path) {
    if (path.isEmpty || path == '/') return '/';
    final parts = path.split('/')..removeLast();
    final result = parts.join('/');
    return result.isEmpty ? '/' : result;
  }

  Color _statusColor(_ActivityStatus status, ColorScheme colorScheme) {
    switch (status) {
      case _ActivityStatus.completed:
        return Colors.green;
      case _ActivityStatus.failed:
        return colorScheme.error;
      case _ActivityStatus.active:
        return colorScheme.primary;
      case _ActivityStatus.pending:
        return colorScheme.tertiary;
    }
  }

  String _statusLabel(_ActivityItem item) {
    final prefix = item.type == _ActivityType.upload ? '上传' : '下载';
    switch (item.status) {
      case _ActivityStatus.completed:
        return '$prefix完成';
      case _ActivityStatus.failed:
        return '$prefix失败';
      case _ActivityStatus.active:
        return '$prefix中...';
      case _ActivityStatus.pending:
        return '等待$prefix...';
    }
  }
}

enum _ActivityType { upload, download }

enum _ActivityStatus { completed, failed, active, pending }

class _ActivityItem {
  final String name;
  final _ActivityType type;
  final _ActivityStatus status;
  final DateTime createdAt;
  final String path;

  _ActivityItem({
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.path,
  });
}
