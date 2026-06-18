import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/sync_task_model.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/sync_stats_card.dart';
import '../../widgets/toast_helper.dart';
import 'desktop_sync_wizard_page.dart';
import 'sync_settings_page.dart';

/// 同步 Tab 页 - 展示实时同步状态、活跃任务和已完成任务
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  // 展开的任务 ID
  final Set<String> _expandedTasks = {};
  // 正在加载详情的任务 ID
  final Set<String> _loadingDetails = {};

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().loadRecentTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final theme = Theme.of(context);

    if (_isDesktop && !sync.desktopSyncWizardCompleted) {
      return _buildDesktopWizardGate(sync, theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _navigateToSettings(),
            tooltip: '同步设置',
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: () async {
            final sync = context.read<SyncProvider>();
            sync.invalidateAllTaskDetails();
            await sync.loadRecentTasks();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 800;
                    final statsCard = SyncStatsCard(
                      uploaded: sync.cumUploaded,
                      downloaded: sync.cumDownloaded,
                      renamed: sync.cumRenamed,
                      moved: sync.cumMoved,
                      conflicts: sync.cumConflicts,
                      failed: sync.cumFailed,
                      deletedLocal: sync.cumDeletedLocal,
                      deletedRemote: sync.cumDeletedRemote,
                      skipped: sync.cumSkipped,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildStatusHeaderCard(sync, theme)),
                          const SizedBox(width: 8),
                          Expanded(child: statsCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildStatusHeaderCard(sync, theme),
                        const SizedBox(height: 8),
                        statsCard,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildActiveTasksSection(sync, theme),
              const SizedBox(height: 8),
              _buildCompletedTasksSection(sync, theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyncSettingsPage()),
    );
  }


  // AI_DESKTOP_SYNC_WIZARD_GATE_WIDGET_V3
  Widget _buildDesktopWizardGate(SyncProvider sync, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _navigateToSettings(),
            tooltip: '同步设置',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          LucideIcons.workflow,
                          color: colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '先完成桌面同步向导',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '这是文件同步的软强制配置。未完成前不会开放开始同步、暂停、恢复等操作；你仍然可以离开本页，继续使用文件、分享、设置等其它功能。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _WizardGateChip(icon: Icons.folder_open_outlined, label: '本地目录'),
                      _WizardGateChip(icon: Icons.cloud_outlined, label: '云端目录'),
                      _WizardGateChip(icon: Icons.sync_alt_outlined, label: '同步模式'),
                      _WizardGateChip(icon: Icons.tune_outlined, label: '桌面专属设置'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '向导完成后会保存配置并开始同步。需要修改配置时，可以稍后进入同步设置页调整。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _navigateToSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('打开同步设置'),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('稍后再说'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          final completed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const DesktopSyncWizardPage(),
                            ),
                          );
                          if (!mounted) return;
                          if (completed == true) {
                            await context.read<SyncProvider>().loadRecentTasks();
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('开始设置向导'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard(SyncProvider sync, ThemeData theme) {
    final isActive = sync.isActive;
    final isPaused = sync.isPaused;
    final hasError = sync.hasError;

    Color statusColor;
    String statusText;

    if (isActive) {
      statusColor = theme.colorScheme.primary;
      statusText = _syncModeLabel(sync);
    } else if (isPaused) {
      statusColor = Colors.orange;
      statusText = '已暂停';
    } else if (hasError) {
      statusColor = theme.colorScheme.error;
      statusText = '同步错误';
    } else if (sync.state == SyncState.stopped) {
      statusColor = theme.disabledColor;
      statusText = '已停止';
    } else {
      statusColor = theme.disabledColor;
      statusText = '未启动';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              statusText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          if (sync.errorMessage != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                sync.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isActive)
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: sync.activeTotalCount > 0 ? sync.activeProgress : null,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      )
                    else
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: 0,
                          strokeWidth: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive && sync.activeTotalCount > 0)
                          Text(
                            '${(sync.activeProgress * 100).toInt()}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        Text(
                          isActive
                              ? (sync.state == SyncState.continuous ? '持续同步' : '同步中')
                              : isPaused
                                  ? '已暂停'
                                  : hasError
                                      ? '错误'
                                      : '未启动',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(Icons.file_upload_outlined, '${sync.cumUploaded}', '已上传', Colors.blue, theme),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.file_download_outlined, '${sync.cumDownloaded}', '已下载', Colors.green, theme),
                    const SizedBox(height: 8),
                    _buildStatRow(Icons.warning_amber_outlined, '${sync.cumConflicts}', '冲突', Colors.orange, theme),
                  ],
                ),
              ),
            ],
          ),
          if (isActive && sync.currentFile != null) ...[
            const SizedBox(height: 12),
            Text(
              sync.currentFile!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          if (isActive && sync.activeTotalCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${sync.activeCompletedCount} / ${sync.activeTotalCount} 文件',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (!sync.isActive && !sync.isPaused)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _navigateToSettings(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('开始同步'),
                  ),
                ),
              if (sync.isActive)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => sync.pause(),
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('暂停'),
                  ),
                ),
              if (sync.isPaused)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => sync.resume(),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('恢复'),
                  ),
                ),
              if (sync.isActive || sync.isPaused) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _stopSync(sync),
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('停止'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, String label, Color color, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }

  String _syncModeLabel(SyncProvider sync) {
    final mode = sync.persistedConfig?.syncMode ?? 'full';
    return switch (mode) {
      'full' => '全量同步中',
      'upload_only' => '仅上传中',
      'download_only' => '仅下载中',
      'album' => '相册同步中',
      'mirror_wcf' => '镜像同步中',
      _ => '同步中',
    };
  }

  Widget _buildActiveTasksSection(SyncProvider sync, ThemeData theme) {
    final tasks = sync.activeTasks;

    return _buildTaskSection(
      theme: theme,
      title: '正在同步',
      icon: LucideIcons.loader,
      tasks: tasks,
      emptyText: '暂无正在进行的同步任务',
    );
  }

  Widget _buildCompletedTasksSection(SyncProvider sync, ThemeData theme) {
    final tasks = sync.recentTasks
        .where((t) =>
            (t.status == 'completed' || t.status == 'failed' || t.status == 'cancelled') &&
            t.totalCount > 0)
        .toList();

    return _buildTaskSection(
      theme: theme,
      title: '已完成',
      icon: LucideIcons.checkCircle2,
      tasks: tasks,
      emptyText: '暂无已完成的同步任务',
    );
  }

  Widget _buildTaskSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<SyncTaskModel> tasks,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (tasks.isEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(emptyText, style: TextStyle(color: theme.hintColor)),
              ),
            ),
          )
        else
          ...tasks.map((task) => _buildTaskCard(task, theme)),
      ],
    );
  }

  Widget _buildTaskCard(SyncTaskModel task, ThemeData theme) {
    final isExpanded = _expandedTasks.contains(task.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleTaskExpand(task.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: task.id));
                      ToastHelper.success('已复制任务 ID');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            task.shortId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                        Icon(Icons.copy, size: 14, color: theme.hintColor),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(task.status, theme).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _statusColor(task.status, theme),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${task.completedCount}/${task.totalCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (task.failedCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '失败${task.failedCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            _buildTaskDetailList(task, theme),
        ],
      ),
    );
  }

  Widget _buildTaskDetailList(SyncTaskModel task, ThemeData theme) {
    final sync = context.watch<SyncProvider>();
    final items = sync.getCachedTaskDetail(task.id);

    if (_loadingDetails.contains(task.id)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (items == null || items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('暂无任务项', style: TextStyle(color: theme.hintColor)),
      );
    }

    final hasMore = sync.hasMoreTaskDetail(task.id);

    return Column(
      children: [
        const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text('操作', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor))),
              Expanded(child: Text('文件名', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor))),
              SizedBox(width: 55, child: Text('状态', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor))),
              SizedBox(width: 110, child: Text('时间', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor))),
            ],
          ),
        ),
        ...items.map((item) => _buildTaskItemRow(item, theme)),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              onPressed: () => _loadMoreDetail(task.id),
              icon: const Icon(Icons.expand_more, size: 16),
              label: const Text('加载更多'),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTaskItemRow(SyncTaskItemModel item, ThemeData theme) {
    final timeStr = _formatTime(item.updatedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _actionColor(item.actionType, theme).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                item.actionLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: _actionColor(item.actionType, theme),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.filename,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              item.statusLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _itemStatusColor(item.status, theme),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              timeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, ThemeData theme) {
    return switch (status) {
      'running' => theme.colorScheme.primary,
      'completed' => Colors.green,
      'failed' => theme.colorScheme.error,
      'cancelled' => theme.hintColor,
      _ => theme.hintColor,
    };
  }

  Color _actionColor(String actionType, ThemeData theme) {
    return switch (actionType) {
      'upload' => Colors.blue,
      'download' => Colors.green,
      'create_placeholder' => Colors.teal,
      'delete_local' || 'delete_remote' => theme.colorScheme.error,
      'rename' || 'move' => Colors.orange,
      'conflict_resolve' => Colors.purple,
      _ => theme.colorScheme.primary,
    };
  }

  Color _itemStatusColor(String status, ThemeData theme) {
    return switch (status) {
      'completed' => Colors.green,
      'failed' => theme.colorScheme.error,
      'running' => theme.colorScheme.primary,
      _ => theme.hintColor,
    };
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  void _toggleTaskExpand(String taskId) {
    final sync = context.read<SyncProvider>();
    if (_expandedTasks.contains(taskId)) {
      setState(() => _expandedTasks.remove(taskId));
      sync.unwatchTaskDetail(taskId);
      return;
    }

    setState(() => _expandedTasks.add(taskId));
    sync.watchTaskDetail(taskId);

    if (sync.getCachedTaskDetail(taskId) == null && !_loadingDetails.contains(taskId)) {
      setState(() => _loadingDetails.add(taskId));
      sync.getTaskDetail(taskId).whenComplete(() {
        if (mounted) {
          setState(() => _loadingDetails.remove(taskId));
        }
      });
    }
  }

  void _loadMoreDetail(String taskId) {
    final sync = context.read<SyncProvider>();
    sync.loadMoreTaskDetail(taskId);
  }

  Future<void> _stopSync(SyncProvider sync) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停止同步'),
        content: const Text('确定要停止文件同步吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('停止'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sync.stop();
    }
  }
}


class _WizardGateChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WizardGateChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
