import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/sync_task_model.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/sync_stats_card.dart';
import 'mobile_sync_wizard_page.dart';
import 'sync_settings_page.dart';

/// 移动端同步详情页面 - 展示实时同步状态和任务列表
class SyncPageAndroid extends StatefulWidget {
  const SyncPageAndroid({super.key});

  @override
  State<SyncPageAndroid> createState() => _SyncPageAndroidState();
}

class _SyncPageAndroidState extends State<SyncPageAndroid> {
  final Set<String> _expandedTasks = {};
  final Set<String> _loadingDetails = {};
  bool _openingSetupWizard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sync = context.read<SyncProvider>();
      await sync.restoreFromStorage();
      await sync.loadRecentTasks();
      await _ensureRequiredWizard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final theme = Theme.of(context);

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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildHeader(sync, theme),
              ),
            ),
            if (sync.persistedConfig == null && !sync.isActive)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildRequiredSetupGate(theme),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SyncStatsCard(
                    uploaded: sync.cumUploaded,
                    downloaded: sync.cumDownloaded,
                    renamed: sync.cumRenamed,
                    moved: sync.cumMoved,
                    conflicts: sync.cumConflicts,
                    failed: sync.cumFailed,
                    deletedLocal: sync.cumDeletedLocal,
                    deletedRemote: sync.cumDeletedRemote,
                    skipped: sync.cumSkipped,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '同步任务',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTaskList(sync, theme),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredSetupGate(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '需要先完成同步设置',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这是第一次使用手机文件同步。完成向导并启动首次同步后，才能使用同步任务和统计信息。你可以返回上一页，但未完成前不能开始同步。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _ensureRequiredWizard,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('打开同步向导'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureRequiredWizard() async {
    if (!mounted || _openingSetupWizard) return;

    final sync = context.read<SyncProvider>();
    if (sync.persistedConfig != null || sync.isActive) return;

    _openingSetupWizard = true;
    try {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const MobileSyncWizardPage()),
      );

      if (completed == true && mounted) {
        sync.invalidateAllTaskDetails();
        await sync.loadRecentTasks();
      }
    } finally {
      _openingSetupWizard = false;
    }
  }

  Future<void> _startSyncFromHeader(SyncProvider sync) async {
    final config = sync.persistedConfig;
    if (config == null) {
      await _ensureRequiredWizard();
      return;
    }

    await sync.startSync(config);
    sync.invalidateAllTaskDetails();
    await sync.loadRecentTasks();
  }

  void _navigateToSettings() {
    final sync = context.read<SyncProvider>();
    if (sync.persistedConfig == null && !sync.isActive) {
      _ensureRequiredWizard();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SyncSettingsPage()));
  }

  Widget _buildHeader(SyncProvider sync, ThemeData theme) {
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
          // 顶部：状态文字居中
          Center(
            child: Text(
              statusText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 中间：左侧旋转圆 + 右侧统计
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 左侧：旋转圆形指示器
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
                          value: sync.activeTotalCount > 0
                              ? sync.activeProgress
                              : null,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: 0,
                          strokeWidth: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    // 中心文字
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
                              ? (sync.state == SyncState.continuous
                                    ? '持续同步'
                                    : '同步中')
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
              // 右侧：统计行
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      Icons.file_upload_outlined,
                      '${sync.cumUploaded}',
                      '已上传',
                      Colors.blue,
                      theme,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      Icons.file_download_outlined,
                      '${sync.cumDownloaded}',
                      '已下载',
                      Colors.green,
                      theme,
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      Icons.warning_amber_outlined,
                      '${sync.cumConflicts}',
                      '冲突',
                      Colors.orange,
                      theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isActive && sync.currentFile != null) ...[
            const SizedBox(height: 12),
            Text(
              sync.currentFile!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
          if (isActive && sync.activeTotalCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${sync.activeCompletedCount} / ${sync.activeTotalCount} 文件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            children: [
              if (!sync.isActive && !sync.isPaused)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _startSyncFromHeader(sync),
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
              if (sync.isActive || isPaused) ...[
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

  Widget _buildStatRow(
    IconData icon,
    String value,
    String label,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildTaskList(SyncProvider sync, ThemeData theme) {
    // 活跃任务 + 已完成任务
    final activeTasks = sync.activeTasks;
    final completedTasks = sync.recentTasks
        .where(
          (t) =>
              (t.status == 'completed' ||
                  t.status == 'failed' ||
                  t.status == 'cancelled') &&
              t.totalCount > 0,
        )
        .toList();
    final allTasks = [...activeTasks, ...completedTasks];

    if (allTasks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: theme.hintColor),
              const SizedBox(height: 12),
              Text('暂无同步任务', style: TextStyle(color: theme.hintColor)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTaskCard(allTasks[index], sync, theme),
          childCount: allTasks.length,
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    SyncTaskModel task,
    SyncProvider sync,
    ThemeData theme,
  ) {
    final isExpanded = _expandedTasks.contains(task.id);
    final isRunning = task.status == 'running';
    final isFailed = task.status == 'failed';
    final isCompleted = task.status == 'completed';

    Color statusColor = switch (task.status) {
      'running' => theme.colorScheme.primary,
      'completed' => Colors.green,
      'failed' => theme.colorScheme.error,
      'cancelled' => theme.hintColor,
      _ => theme.hintColor,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleTaskExpand(task.id),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 状态图标
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isRunning
                          ? Icons.sync
                          : isFailed
                          ? Icons.error_outline
                          : isCompleted
                          ? Icons.check_circle_outline
                          : Icons.cloud_off,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 任务信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.statusLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              task.triggerLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 进度条
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: isRunning && task.totalCount > 0
                                ? task.progress
                                : (isCompleted ? 1.0 : null),
                            minHeight: 4,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${task.completedCount}/${task.totalCount}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            if (task.failedCount > 0)
                              Text(
                                '失败${task.failedCount}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildTaskDetailList(task, sync, theme),
        ],
      ),
    );
  }

  Widget _buildTaskDetailList(
    SyncTaskModel task,
    SyncProvider sync,
    ThemeData theme,
  ) {
    final items = sync.getCachedTaskDetail(task.id);

    if (_loadingDetails.contains(task.id)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
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
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: theme.dividerColor,
        ),
        ...items.map((item) => _buildTaskItemTile(item, theme)),
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

  Widget _buildTaskItemTile(SyncTaskItemModel item, ThemeData theme) {
    Color actionColor = switch (item.actionType) {
      'upload' => Colors.blue,
      'download' => Colors.green,
      'create_placeholder' => Colors.teal,
      'delete_local' || 'delete_remote' => theme.colorScheme.error,
      'rename' || 'move' => Colors.orange,
      'conflict_resolve' => Colors.purple,
      _ => theme.colorScheme.primary,
    };

    Color itemStatusColor = switch (item.status) {
      'completed' => Colors.green,
      'failed' => theme.colorScheme.error,
      'running' => theme.colorScheme.primary,
      _ => theme.hintColor,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 操作类型图标
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.actionType == 'upload'
                  ? Icons.file_upload_outlined
                  : item.actionType == 'download'
                  ? Icons.file_download_outlined
                  : item.actionType == 'delete_local' ||
                        item.actionType == 'delete_remote'
                  ? Icons.delete_outline
                  : item.actionType == 'rename'
                  ? Icons.edit_outlined
                  : item.actionType == 'move'
                  ? Icons.drive_file_move_outline
                  : Icons.sync_outlined,
              color: actionColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          // 文件名 + 状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.filename,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (item.errorMessage != null)
                  Text(
                    item.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: itemStatusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.statusLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: itemStatusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _syncModeLabel(SyncProvider sync) {
    final mode = sync.persistedConfig?.syncMode ?? 'full';
    return switch (mode) {
      'full' => '全量同步中',
      'upload_only' => '仅上传中',
      'download_only' => '仅下载中',
      'album_upload' => '相册上传中',
      'album_download' => '相册下载中',
      'mirror_wcf' => '镜像同步中',
      _ => '同步中',
    };
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

    if (sync.getCachedTaskDetail(taskId) == null &&
        !_loadingDetails.contains(taskId)) {
      setState(() => _loadingDetails.add(taskId));
      sync.getTaskDetail(taskId).whenComplete(() {
        if (mounted) {
          setState(() => _loadingDetails.remove(taskId));
        }
      });
    }
  }

  void _loadMoreDetail(String taskId) {
    context.read<SyncProvider>().loadMoreTaskDetail(taskId);
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
