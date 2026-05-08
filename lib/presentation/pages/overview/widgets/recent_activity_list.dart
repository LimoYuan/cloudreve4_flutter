import 'dart:io';
import 'package:cloudreve4_flutter/data/models/download_task_model.dart';
import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
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
              clipBehavior: Clip.antiAlias,
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
        createdAt: DateTime.now(),
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
        savePath: d.savePath,
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
    final icon = isUpload ? LucideIcons.upload : LucideIcons.download;
    final statusColor = _statusColor(item.status, colorScheme);

    // 判断点击行为
    final bool canTap;
    if (item.status == _ActivityStatus.completed) {
      if (isUpload) {
        canTap = true; // 上传完成 → 跳转目录
      } else {
        // 下载完成 → 仅桌面端可打开文件夹
        canTap = Platform.isWindows || Platform.isLinux;
      }
    } else {
      canTap = false;
    }

    return InkWell(
      onTap: canTap ? () => _handleTap(context, item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(item),
                    style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            if (canTap) ...[
              const SizedBox(width: 8),
              Icon(
                isUpload ? LucideIcons.folderOpen : LucideIcons.externalLink,
                size: 16,
                color: theme.hintColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, _ActivityItem item) {
    if (item.type == _ActivityType.upload) {
      _navigateToFolder(context, item.path);
    } else {
      _openLocalFolder(item.savePath);
    }
  }

  void _navigateToFolder(BuildContext context, String path) {
    final parentPath = _getParentPath(path);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

    // 先设置目标路径，再切换 Tab
    fileManager.enterFolder(parentPath);
    navProvider.setIndex(1);
  }

  Future<void> _openLocalFolder(String? savePath) async {
    if (savePath == null || savePath.isEmpty) return;
    try {
      final dir = File(savePath).parent.path;
      final result = await OpenFile.open(dir);
      if (result.type != ResultType.done) {
        AppLogger.d('打开文件夹失败: ${result.message}');
      }
    } catch (e) {
      AppLogger.d('打开文件夹失败: $e');
    }
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
  final String? savePath;

  _ActivityItem({
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.path,
    this.savePath,
  });
}
