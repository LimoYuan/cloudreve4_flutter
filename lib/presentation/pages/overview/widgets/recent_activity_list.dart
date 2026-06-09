import 'package:cloudreve4_flutter/data/models/download_task_model.dart';
import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/sync_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/services/local_recent_activity_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class RecentActivityList extends StatefulWidget {
  const RecentActivityList({super.key});

  @override
  State<RecentActivityList> createState() => _RecentActivityListState();
}

class _RecentActivityListState extends State<RecentActivityList> {
  List<LocalRecentShareActivity> _shareActivities = [];
  List<LocalRecentFileActivity> _fileActivities = [];

  @override
  void initState() {
    super.initState();
    _loadLocalActivities();
    LocalRecentActivityService.instance.revision.addListener(_onRevisionChange);
  }

  @override
  void dispose() {
    LocalRecentActivityService.instance.revision.removeListener(
      _onRevisionChange,
    );
    super.dispose();
  }

  void _onRevisionChange() {
    _loadLocalActivities();
  }

  Future<void> _loadLocalActivities() async {
    final shares = await LocalRecentActivityService.instance
        .getShareActivities();
    final files = await LocalRecentActivityService.instance.getFileActivities();
    if (mounted) {
      setState(() {
        _shareActivities = shares;
        _fileActivities = files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(LucideIcons.activity, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '最近活动',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 1180;
            final sections = _buildSections(context);

            if (sections.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.activity,
                          size: 40,
                          color: theme.hintColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无活动记录',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (useTwoColumns) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (int i = 0; i < sections.length; i += 2)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i + 2 < sections.length ? 12 : 0,
                            ),
                            child: sections[i],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (int i = 1; i < sections.length; i += 2)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i + 1 < sections.length ? 12 : 0,
                            ),
                            child: sections[i],
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                for (int i = 0; i < sections.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < sections.length - 1 ? 12 : 0,
                    ),
                    child: sections[i],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final sections = <Widget>[];

    // 最近分享
    if (_shareActivities.isNotEmpty) {
      sections.add(
        _buildSection(
          context,
          icon: LucideIcons.share2,
          title: '最近分享的文件',
          rows: _shareActivities
              .map(
                (a) => _ActivityRow(
                  name: a.name,
                  typeLabel: a.typeLabel,
                  detail: a.isExpired ? '已过期' : '${a.visited} 次访问',
                  isExpired: a.isExpired,
                ),
              )
              .toList(),
          onMore: () => _navigateToTab(2),
        ),
      );
    }

    // 最近查看/编辑
    if (_fileActivities.isNotEmpty) {
      sections.add(
        _buildSection(
          context,
          icon: LucideIcons.eye,
          title: '最近查看 / 编辑',
          rows: _fileActivities
              .map(
                (a) => _ActivityRow(
                  name: a.name,
                  typeLabel: a.typeLabel,
                  detail: a.actionLabel,
                ),
              )
              .toList(),
          onMore: () => _navigateToTab(1),
        ),
      );
    }

    // 最近传输
    sections.add(
      Consumer2<UploadManagerProvider, DownloadManagerProvider>(
        builder: (context, uploadProvider, downloadProvider, _) {
          final transfers = _mergeTransfers(
            uploadProvider.allTasks,
            downloadProvider.tasks,
          );
          if (transfers.isEmpty) return const SizedBox.shrink();
          return _buildSection(
            context,
            icon: LucideIcons.arrowUpDown,
            title: '最近完成的上传 / 下载',
            rows: transfers
                .map(
                  (t) => _ActivityRow(
                    name: t.name,
                    typeLabel: t.typeLabel,
                    detail: t.statusLabel,
                    statusColor: t.statusColor,
                  ),
                )
                .toList(),
            onMore: () => _navigateToTab(2),
          );
        },
      ),
    );

    // 最近同步
    sections.add(
      Consumer<SyncProvider>(
        builder: (context, syncProvider, _) {
          final syncItems = _buildSyncActivities(syncProvider);
          if (syncItems.isEmpty) return const SizedBox.shrink();
          return _buildSection(
            context,
            icon: LucideIcons.refreshCw,
            title: '最近同步的文件',
            rows: syncItems
                .map(
                  (s) => _ActivityRow(
                    name: s.name,
                    typeLabel: s.typeLabel,
                    detail: s.actionLabel,
                  ),
                )
                .toList(),
            onMore: () => _navigateToTab(4),
          );
        },
      ),
    );

    return sections;
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<_ActivityRow> rows,
    VoidCallback? onMore,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onMore != null)
                  TextButton(
                    onPressed: onMore,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '查看更多',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Header row
            _buildTableHeader(context),
            const SizedBox(height: 2),
            // Data rows
            ...rows.map((row) => _buildTableRow(context, row)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              '文件名',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '类型',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '状态',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(BuildContext context, _ActivityRow row) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor =
        row.statusColor ??
        (row.isExpired ? colorScheme.error : colorScheme.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.typeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TransferActivity> _mergeTransfers(
    List<UploadTaskModel> uploads,
    List<DownloadTaskModel> downloads,
  ) {
    final items = <_TransferActivity>[];

    for (final u in uploads.where(
      (t) =>
          t.status == UploadStatus.completed || t.status == UploadStatus.failed,
    )) {
      items.add(
        _TransferActivity(
          name: u.fileName,
          typeLabel: '上传',
          statusLabel: u.status == UploadStatus.completed ? '完成' : '失败',
          statusColor: u.status == UploadStatus.completed
              ? Colors.green
              : Theme.of(context).colorScheme.error,
        ),
      );
    }

    for (final d in downloads.where(
      (t) =>
          t.status == DownloadStatus.completed ||
          t.status == DownloadStatus.failed,
    )) {
      items.add(
        _TransferActivity(
          name: d.fileName,
          typeLabel: '下载',
          statusLabel: d.status == DownloadStatus.completed ? '完成' : '失败',
          statusColor: d.status == DownloadStatus.completed
              ? Colors.green
              : Theme.of(context).colorScheme.error,
        ),
      );
    }

    return items;
  }

  List<_SyncFileActivity> _buildSyncActivities(SyncProvider syncProvider) {
    if (!syncProvider.isActive && syncProvider.activeWorkerCount == 0) {
      return [];
    }
    // 简化：使用 SyncProvider 的最近活动数据
    return [];
  }

  void _navigateToTab(int tabIndex) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    navProvider.setIndex(tabIndex);
  }
}

class _ActivityRow {
  final String name;
  final String typeLabel;
  final String detail;
  final bool isExpired;
  final Color? statusColor;

  const _ActivityRow({
    required this.name,
    required this.typeLabel,
    required this.detail,
    this.isExpired = false,
    this.statusColor,
  });
}

class _TransferActivity {
  final String name;
  final String typeLabel;
  final String statusLabel;
  final Color statusColor;

  const _TransferActivity({
    required this.name,
    required this.typeLabel,
    required this.statusLabel,
    required this.statusColor,
  });
}

class _SyncFileActivity {
  final String name;
  final String typeLabel;
  final String actionLabel;

  const _SyncFileActivity({
    required this.name,
    required this.typeLabel,
    required this.actionLabel,
  });
}
