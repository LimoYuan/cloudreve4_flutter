import 'package:cloudreve4_flutter/data/models/upload_task_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/upload_progress_item.dart';
import 'package:cloudreve4_flutter/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class UploadTasksTab extends StatefulWidget {
  const UploadTasksTab({super.key});

  @override
  State<UploadTasksTab> createState() => _UploadTasksTabState();
}

class _UploadTasksTabState extends State<UploadTasksTab> {
  static const int _pageSize = 15;

  /// 进行中任务当前页码（0-based）
  int _activePage = 0;

  /// 失败/取消任务当前页码（0-based）
  int _failedPage = 0;

  /// 已完成任务当前页码（0-based）
  int _completedPage = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadManagerProvider>(
      builder: (context, uploadManager, _) {
        // 进行中任务（waiting/uploading/paused）走内存，实时更新进度
        final activeTasks = uploadManager.activeTasks;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            if (isDesktop) {
              return _buildDesktopLayout(context, uploadManager, activeTasks);
            }

            return _buildMobileLayout(context, uploadManager, activeTasks);
          },
        );
      },
    );
  }

  // ============ 分页 Stream ============

  Stream<List<UploadTaskEntry>> _failedTasksStream() {
    return TaskDatabase.instance.watchUploadTasks(
      statusIndexes: [
        UploadStatus.failed.index,
        UploadStatus.cancelled.index,
      ],
      limit: _pageSize,
      offset: _failedPage * _pageSize,
    );
  }

  Stream<int> _failedTasksCountStream() {
    return TaskDatabase.instance.watchUploadTasksCount([
      UploadStatus.failed.index,
      UploadStatus.cancelled.index,
    ]);
  }

  Stream<List<UploadTaskEntry>> _completedTasksStream() {
    return TaskDatabase.instance.watchUploadTasks(
      statusIndexes: [UploadStatus.completed.index],
      limit: _pageSize,
      offset: _completedPage * _pageSize,
    );
  }

  Stream<int> _completedTasksCountStream() {
    return TaskDatabase.instance.watchUploadTasksCount([
      UploadStatus.completed.index,
    ]);
  }

  // ============ Mobile Layout ============

  Widget _buildMobileLayout(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // 进行中任务分页 section（内存数据，避免 1000 个 Widget 全量渲染卡死）
        _buildActiveSection(context, uploadManager, activeTasks),
        // 失败任务分页 section
        _buildFailedSection(context, uploadManager, activeTasks, theme),
        // 已完成任务分页 section
        _buildCompletedSection(context, uploadManager, activeTasks, theme),
      ],
    );
  }

  /// 进行中任务分页 section
  ///
  /// active 任务在内存里（UploadService._tasks），不走数据库 Stream。
  /// 文件夹上传可能产生上千个 waiting 任务，全量渲染会卡死 UI，所以也分页。
  Widget _buildActiveSection(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
  ) {
    if (activeTasks.isEmpty) return const SizedBox.shrink();

    final totalCount = activeTasks.length;
    final totalPages = (totalCount / _pageSize).ceil();
    // 当前页越界（任务完成后总数减少），回退到最后一页
    if (_activePage >= totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _activePage = (totalPages - 1).clamp(0, totalPages - 1));
        }
      });
    }
    final safePage = _activePage.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, totalCount);
    final pageTasks = activeTasks.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(context, '进行中', totalCount),
        ...pageTasks.map((task) => UploadProgressItem(
          task: task,
          onPause: () => uploadManager.pauseUpload(task.id),
          onResume: () => uploadManager.retryUpload(task.id),
          onCancel: () => uploadManager.cancelUpload(task.id),
        )),
        _buildPaginationControls(
          context: context,
          currentPage: safePage,
          totalPages: totalPages,
          onPrev: safePage > 0
              ? () => setState(() => _activePage--)
              : null,
          onNext: safePage < totalPages - 1
              ? () => setState(() => _activePage++)
              : null,
        ),
      ],
    );
  }

  Widget _buildFailedSection(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
    ThemeData theme,
  ) {
    return StreamBuilder<int>(
      stream: _failedTasksCountStream(),
      builder: (context, countSnapshot) {
        final totalCount = countSnapshot.data ?? 0;
        // 总数变化导致当前页超出范围时回退
        if (totalCount == 0) return const SizedBox.shrink();
        final totalPages = (totalCount / _pageSize).ceil();
        // 当前页越界（例如清除任务后），回退到最后一页
        if (_failedPage >= totalPages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _failedPage = (totalPages - 1).clamp(0, totalPages - 1));
          });
        }
        return StreamBuilder<List<UploadTaskEntry>>(
          stream: _failedTasksStream(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const [];
            final failedTasks = entries
                .map((e) => UploadTaskModel.fromEntry(e))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, '失败', totalCount,
                    actionLabel: '清除失败',
                    onAction: () => _confirmClear(context, '失败',
                        totalCount, () {
                      uploadManager.clearFailedTasks();
                      setState(() => _failedPage = 0);
                    })),
                ...failedTasks.map((task) => UploadProgressItem(
                  task: task,
                  onRetry: () => uploadManager.retryUpload(task.id),
                  onDelete: () => _confirmDeleteUploadTask(context, task, uploadManager),
                )),
                _buildPaginationControls(
                  context: context,
                  currentPage: _failedPage,
                  totalPages: totalPages,
                  onPrev: _failedPage > 0
                      ? () => setState(() => _failedPage--)
                      : null,
                  onNext: _failedPage < totalPages - 1
                      ? () => setState(() => _failedPage++)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedSection(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
    ThemeData theme,
  ) {
    return StreamBuilder<int>(
      stream: _completedTasksCountStream(),
      builder: (context, countSnapshot) {
        final totalCount = countSnapshot.data ?? 0;
        if (totalCount == 0) {
          // 失败和已完成都为空且进行中也空 -> 显示空态
          if (activeTasks.isEmpty &&
              !snapshotHasData(countSnapshot)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.upload, size: 48,
                      color: theme.hintColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('暂无上传任务', style: TextStyle(color: theme.hintColor)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final totalPages = (totalCount / _pageSize).ceil();
        if (_completedPage >= totalPages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _completedPage = (totalPages - 1).clamp(0, totalPages - 1));
          });
        }
        return StreamBuilder<List<UploadTaskEntry>>(
          stream: _completedTasksStream(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const [];
            final completedTasks = entries
                .map((e) => UploadTaskModel.fromEntry(e))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, '已完成', totalCount,
                    actionLabel: '清除已完成',
                    onAction: () => _confirmClear(context, '已完成',
                        totalCount, () {
                      uploadManager.clearCompletedTasks();
                      setState(() => _completedPage = 0);
                    })),
                ...completedTasks.map((task) => UploadProgressItem(
                  task: task,
                  onNavigate: () => _navigateToUploadedFile(context, task),
                  onDelete: () => _confirmDeleteUploadTask(context, task, uploadManager),
                )),
                _buildPaginationControls(
                  context: context,
                  currentPage: _completedPage,
                  totalPages: totalPages,
                  onPrev: _completedPage > 0
                      ? () => setState(() => _completedPage--)
                      : null,
                  onNext: _completedPage < totalPages - 1
                      ? () => setState(() => _completedPage++)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool snapshotHasData(AsyncSnapshot<int> snapshot) => snapshot.hasData;

  /// 分页控件：[上一页] 第 X/Y 页 [下一页]
  Widget _buildPaginationControls({
    required BuildContext context,
    required int currentPage,
    required int totalPages,
    VoidCallback? onPrev,
    VoidCallback? onNext,
  }) {
    // 只有一页时不显示分页控件
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: onPrev,
            tooltip: '上一页',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: onPrev == null ? theme.disabledColor : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            '第 ${currentPage + 1} / $totalPages 页',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: onNext,
            tooltip: '下一页',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: onNext == null ? theme.disabledColor : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // ============ Desktop Layout ============

  Widget _buildDesktopLayout(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    // 对 active 任务分页，避免 1000 个 DataRow 全量渲染卡死 DataTable
    final activeTotal = activeTasks.length;
    final activeTotalPages = activeTotal == 0 ? 0 : (activeTotal / _pageSize).ceil();
    if (activeTotalPages > 0 && _activePage >= activeTotalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _activePage = (activeTotalPages - 1).clamp(0, activeTotalPages - 1));
        }
      });
    }
    final activeSafePage = activeTotalPages > 0
        ? _activePage.clamp(0, activeTotalPages - 1)
        : 0;
    final activeStart = activeSafePage * _pageSize;
    final activeEnd = (activeStart + _pageSize).clamp(0, activeTotal);
    final pagedActiveTasks = activeTasks.sublist(activeStart, activeEnd);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 失败任务的清除按钮
          StreamBuilder<int>(
            stream: _failedTasksCountStream(),
            builder: (context, snapshot) {
              final failedCount = snapshot.data ?? 0;
              if (failedCount == 0) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('清除失败', style: TextStyle(fontSize: 12)),
                    onPressed: () => _confirmClear(context, '失败', failedCount, () {
                      uploadManager.clearFailedTasks();
                      setState(() => _failedPage = 0);
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              );
            },
          ),
          // 已完成任务的清除按钮（仅在失败任务为空时显示）
          StreamBuilder<int>(
            stream: _failedTasksCountStream(),
            builder: (context, failedSnapshot) {
              final failedCount = failedSnapshot.data ?? 0;
              if (failedCount > 0) return const SizedBox.shrink();
              return StreamBuilder<int>(
                stream: _completedTasksCountStream(),
                builder: (context, completedSnapshot) {
                  final completedCount = completedSnapshot.data ?? 0;
                  if (completedCount == 0) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton.icon(
                        icon: const Icon(LucideIcons.trash2, size: 14),
                        label: const Text('清除已完成', style: TextStyle(fontSize: 12)),
                        onPressed: () => _confirmClear(context, '已完成', completedCount, () {
                          uploadManager.clearCompletedTasks();
                          setState(() => _completedPage = 0);
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: _buildTasksDataTable(context, uploadManager, pagedActiveTasks),
            ),
          ),
          // 进行中任务分页控件
          if (activeTotalPages > 1)
            _buildPaginationControls(
              context: context,
              currentPage: activeSafePage,
              totalPages: activeTotalPages,
              onPrev: activeSafePage > 0
                  ? () => setState(() => _activePage--)
                  : null,
              onNext: activeSafePage < activeTotalPages - 1
                  ? () => setState(() => _activePage++)
                  : null,
            ),
          // 已完成任务分页控件
          StreamBuilder<int>(
            stream: _completedTasksCountStream(),
            builder: (context, snapshot) {
              final totalCount = snapshot.data ?? 0;
              if (totalCount <= _pageSize) return const SizedBox.shrink();
              final totalPages = (totalCount / _pageSize).ceil();
              return _buildPaginationControls(
                context: context,
                currentPage: _completedPage,
                totalPages: totalPages,
                onPrev: _completedPage > 0
                    ? () => setState(() => _completedPage--)
                    : null,
                onNext: _completedPage < totalPages - 1
                    ? () => setState(() => _completedPage++)
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 桌面端 DataTable：进行中任务来自内存，失败/已完成任务来自 Stream（当前页）
  Widget _buildTasksDataTable(
    BuildContext context,
    UploadManagerProvider uploadManager,
    List<UploadTaskModel> activeTasks,
  ) {
    return StreamBuilder<List<UploadTaskEntry>>(
      stream: _failedTasksStream(),
      builder: (context, failedSnapshot) {
        final failedTasks = (failedSnapshot.data ?? const [])
            .map((e) => UploadTaskModel.fromEntry(e))
            .toList();
        return StreamBuilder<List<UploadTaskEntry>>(
          stream: _completedTasksStream(),
          builder: (context, completedSnapshot) {
            final completedTasks = (completedSnapshot.data ?? const [])
                .map((e) => UploadTaskModel.fromEntry(e))
                .toList();

            final sortedTasks = <UploadTaskModel>[
              ...activeTasks.reversed,
              ...failedTasks.reversed,
              ...completedTasks.reversed,
            ];

            if (sortedTasks.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('暂无上传任务',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ),
              );
            }

            return DataTable(
              headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest),
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('名称')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('进度')),
                DataColumn(label: Text('大小')),
                DataColumn(label: Text('速度/完成时间')),
                DataColumn(label: Text('操作')),
              ],
              rows: sortedTasks
                  .map((task) => _buildUploadDataRow(context, task, uploadManager))
                  .toList(),
            );
          },
        );
      },
    );
  }

  DataRow _buildUploadDataRow(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = colorScheme.error;
    final statusColor = _getStatusColor(task.status);
    final statusIcon = _getStatusIcon(task.status);
    final isActive = task.status == UploadStatus.uploading ||
        task.status == UploadStatus.waiting ||
        task.status == UploadStatus.paused;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            task.statusText,
            style: TextStyle(color: statusColor, fontSize: 13),
          ),
        ),
        DataCell(
          isActive
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: task.status == UploadStatus.paused ? null : task.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.status == UploadStatus.paused ? '已暂停' : task.progressText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              : Text(
                  task.status == UploadStatus.completed ? '100%' : '-',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
        DataCell(Text(task.readableFileSize, style: const TextStyle(fontSize: 13))),
        DataCell(
          Text(
            task.status == UploadStatus.completed
                ? (task.completedAt != null ? _formatDateTime(task.completedAt!) : '-')
                : task.speedText,
            style: TextStyle(
              fontSize: 13,
              color: task.status == UploadStatus.completed
                  ? null
                  : colorScheme.primary,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildDesktopActionButtons(context, task, uploadManager, errorColor),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDesktopActionButtons(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
    Color errorColor,
  ) {
    switch (task.status) {
      case UploadStatus.waiting:
      case UploadStatus.uploading:
        return [
          IconButton(
            icon: const Icon(Icons.pause, size: 18),
            onPressed: () => uploadManager.pauseUpload(task.id),
            tooltip: '暂停',
          ),
          IconButton(
            icon: Icon(Icons.cancel, size: 18, color: errorColor),
            onPressed: () => uploadManager.cancelUpload(task.id),
            tooltip: '取消',
          ),
        ];
      case UploadStatus.paused:
        return [
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => uploadManager.retryUpload(task.id),
            tooltip: '继续',
          ),
          IconButton(
            icon: Icon(Icons.cancel, size: 18, color: errorColor),
            onPressed: () => uploadManager.cancelUpload(task.id),
            tooltip: '取消',
          ),
        ];
      case UploadStatus.failed:
        return [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => uploadManager.retryUpload(task.id),
            tooltip: '重试',
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
            tooltip: '删除',
          ),
        ];
      case UploadStatus.completed:
        return [
          IconButton(
            icon: const Icon(LucideIcons.folderOpen, size: 18),
            onPressed: () => _navigateToUploadedFile(context, task),
            tooltip: '打开文件夹',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
            tooltip: '删除',
          ),
        ];
      case UploadStatus.cancelled:
        return [
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: errorColor),
            onPressed: () => _confirmDeleteUploadTask(context, task, uploadManager),
            tooltip: '删除',
          ),
        ];
    }
  }

  IconData _getStatusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.waiting:
        return LucideIcons.clock;
      case UploadStatus.uploading:
        return LucideIcons.upload;
      case UploadStatus.completed:
        return LucideIcons.checkCircle2;
      case UploadStatus.paused:
        return LucideIcons.pause;
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return LucideIcons.xCircle;
    }
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.waiting:
        return Colors.orange;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.paused:
        return Colors.orange;
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              icon: const Icon(LucideIcons.trash2, size: 14),
              label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, String label, int count, VoidCallback onConfirm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清除$label'),
        content: Text('确定要清除 $count 个$label的任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  Future<void> _confirmDeleteUploadTask(
    BuildContext context,
    UploadTaskModel task,
    UploadManagerProvider uploadManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除上传任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要删除该任务吗？'),
            const SizedBox(height: 8),
            Text(task.fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('上传时间: ${_formatDateTime(task.createdAt)}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
            Text('文件大小: ${task.readableFileSize}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) uploadManager.removeTask(task.id);
  }

  void _navigateToUploadedFile(BuildContext context, UploadTaskModel task) {
    final targetPath = task.targetPath;
    String relativePath;
    if (targetPath.startsWith('cloudreve://my')) {
      relativePath = targetPath.replaceFirst('cloudreve://my', '');
      if (relativePath.isEmpty) relativePath = '/';
    } else {
      relativePath = targetPath;
    }

    final filePath = targetPath.endsWith('/')
        ? '$targetPath${task.fileName}'
        : '$targetPath/${task.fileName}';

    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    fileManager.navigateAndHighlight(relativePath, filePath);
    navProvider.setIndex(1);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
