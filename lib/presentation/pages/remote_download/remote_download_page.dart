import 'dart:async';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:cloudreve4_flutter/presentation/widgets/folder_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../data/models/remote_download_task_model.dart';
import '../../../services/remote_download_service.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/toast_helper.dart';

class _StatusColors {
  final Color background;
  final Color foreground;
  final Color icon;
  const _StatusColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}

/// 离线下载页面
class RemoteDownloadPage extends StatefulWidget {
  const RemoteDownloadPage({super.key});

  @override
  State<RemoteDownloadPage> createState() => _RemoteDownloadPageState();
}

class _RemoteDownloadPageState extends State<RemoteDownloadPage>
    with SingleTickerProviderStateMixin {
  final RemoteDownloadService _service = RemoteDownloadService();

  List<RemoteDownloadTaskModel> _downloadingTasks = [];
  List<RemoteDownloadTaskModel> _completedTasks = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  static const double _desktopBreakpoint = 800;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTasks());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _startOrStopPolling();
  }

  void _startOrStopPolling() {
    _pollTimer?.cancel();
    int refreshTime = 1;
    if (_tabController.index == 0 && _downloadingTasks.isNotEmpty) {
      _pollTimer = Timer.periodic(
          Duration(seconds: refreshTime), (_) => _loadTasks(quiet: true));
    }
  }

  Future<void> _loadTasks({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _service.listTasks(category: 'downloading', pageSize: 50),
        _service.listTasks(category: 'downloaded', pageSize: 50),
      ]);

      if (!mounted) return;

      final dlData = results[0];
      final cdData = results[1];

      final dlTasks = (dlData['tasks'] as List<dynamic>? ?? [])
          .map((t) =>
              RemoteDownloadTaskModel.fromJson(t as Map<String, dynamic>))
          .toList();
      final cdTasks = (cdData['tasks'] as List<dynamic>? ?? [])
          .map((t) =>
              RemoteDownloadTaskModel.fromJson(t as Map<String, dynamic>))
          .toList();

      setState(() {
        _downloadingTasks = dlTasks;
        _completedTasks = cdTasks;
        _isLoading = false;
      });

      _startOrStopPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!quiet) ToastHelper.failure('加载失败: $e');
    }
  }

  // ─── 辅助方法 ───

  _StatusColors _getStatusColors(RemoteDownloadStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case RemoteDownloadStatus.queued:
        return _StatusColors(
          background: isDark
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          foreground: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          icon: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        );
      case RemoteDownloadStatus.running:
        return _StatusColors(
          background: colorScheme.primary.withValues(alpha: 0.1),
          foreground: colorScheme.primary,
          icon: colorScheme.primary,
        );
      case RemoteDownloadStatus.completed:
        return _StatusColors(
          background: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
          foreground: isDark ? Colors.green.shade300 : Colors.green.shade700,
          icon: isDark ? Colors.green.shade300 : Colors.green.shade600,
        );
      case RemoteDownloadStatus.error:
        return _StatusColors(
          background: colorScheme.error.withValues(alpha: 0.1),
          foreground: colorScheme.error,
          icon: colorScheme.error,
        );
      case RemoteDownloadStatus.suspending:
      case RemoteDownloadStatus.suspended:
        return _StatusColors(
          background: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
          foreground:
              isDark ? Colors.orange.shade300 : Colors.orange.shade700,
          icon: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
        );
    }
  }

  IconData _getStatusIcon(RemoteDownloadStatus status) {
    switch (status) {
      case RemoteDownloadStatus.queued:
        return LucideIcons.clock;
      case RemoteDownloadStatus.running:
        return LucideIcons.download;
      case RemoteDownloadStatus.completed:
        return LucideIcons.checkCircle2;
      case RemoteDownloadStatus.error:
        return LucideIcons.alertCircle;
      case RemoteDownloadStatus.suspending:
      case RemoteDownloadStatus.suspended:
        return LucideIcons.pause;
    }
  }

  Widget _buildCountBadge(int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          '$count',
          key: ValueKey(count),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(RemoteDownloadStatus status) {
    final colors = _getStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors.foreground,
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(RemoteDownloadStatus status) {
    final colors = _getStatusColors(status);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getStatusIcon(status), color: colors.icon, size: 18),
    );
  }

  // ─── 页面构建 ───

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('离线下载',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: !isDesktop,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('下载中'),
                  const SizedBox(width: 8),
                  _buildCountBadge(_downloadingTasks.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('已完成'),
                  const SizedBox(width: 8),
                  _buildCountBadge(_completedTasks.length),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => _loadTasks(),
            tooltip: '刷新',
          ),
          if (isDesktop) const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderBar(isDesktop),
          Expanded(
            child: _buildBody(context, isDesktop),
          ),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context),
              label: const Text('新建任务'),
              icon: const Icon(LucideIcons.plus),
            ),
    );
  }

  Widget _buildHeaderBar(bool isDesktop) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索任务...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (value) {
                  _searchQuery = value.toLowerCase();
                  setState(() {});
                },
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            Text(
              '下载中 ${_downloadingTasks.length} / 已完成 ${_completedTasks.length}',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('新建任务'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    final filteredDownloading = _searchQuery.isEmpty
        ? _downloadingTasks
        : _downloadingTasks
            .where((t) => t.displayName.toLowerCase().contains(_searchQuery))
            .toList();
    final filteredCompleted = _searchQuery.isEmpty
        ? _completedTasks
        : _completedTasks
            .where((t) => t.displayName.toLowerCase().contains(_searchQuery))
            .toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _isLoading &&
              _downloadingTasks.isEmpty &&
              _completedTasks.isEmpty
          ? const Center(
              key: ValueKey('loading'),
              child: CircularProgressIndicator(),
            )
          : _searchQuery.isNotEmpty &&
                  filteredDownloading.isEmpty &&
                  filteredCompleted.isEmpty
              ? _buildNoSearchResult()
              : TabBarView(
                  key: const ValueKey('content'),
                  controller: _tabController,
                  children: [
                    _buildTaskList(filteredDownloading,
                        isOngoing: true, isDesktop: isDesktop),
                    _buildTaskList(filteredCompleted,
                        isOngoing: false, isDesktop: isDesktop),
                  ],
                ),
    );
  }

  Widget _buildTaskList(List<RemoteDownloadTaskModel> tasks,
      {required bool isOngoing, required bool isDesktop}) {
    if (tasks.isEmpty) {
      return _buildEmptyState(isOngoing: isOngoing);
    }

    return RefreshIndicator(
      onRefresh: () => _loadTasks(),
      child: isDesktop
          ? _buildDesktopLayout(tasks, isOngoing)
          : _buildMobileLayout(tasks, isOngoing),
    );
  }

  // ─── 桌面端布局 ───

  Widget _buildDesktopLayout(
      List<RemoteDownloadTaskModel> tasks, bool isOngoing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: isOngoing
              ? _buildDownloadingTable(tasks)
              : _buildCompletedTable(tasks),
        ),
      ),
    );
  }

  Widget _buildDownloadingTable(List<RemoteDownloadTaskModel> tasks) {
    final colorScheme = Theme.of(context).colorScheme;

    return DataTable(
      showCheckboxColumn: false,
      headingRowColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerHighest),
      columnSpacing: 24,
      columns: const [
        DataColumn(
            label: Text('名称',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('状态',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('进度',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('大小/速度',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('创建时间',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('操作',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: tasks.map((task) {
        final download = task.summary?.download;
        return DataRow(
          onSelectChanged: (_) => _showTaskDetail(task),
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Row(
                  children: [
                    _buildLeadingIcon(task.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(_buildStatusBadge(task.status)),
            DataCell(
              download != null && download.total > 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            value: download.progress.clamp(0.0, 1.0),
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '${(download.progress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    )
                  : const Text('-', style: TextStyle(fontSize: 12)),
            ),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (download != null)
                      Text(
                        '${_formatSize(download.downloaded)} / ${_formatSize(download.total)}',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (download != null && download.speedText.isNotEmpty)
                      Text(
                        download.speedText,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            DataCell(Text(_formatTime(task.createdAt),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant))),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (download != null && download.files.isNotEmpty)
                    IconButton(
                      icon: const Icon(LucideIcons.layoutList, size: 18),
                      onPressed: () {
                        if (!mounted) return;
                        Future.microtask(() {
                          if (!mounted) return;
                          _showFilesDialog(context, task);
                        });
                      },
                      tooltip: '查看文件',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  if (task.status.isOngoing)
                    IconButton(
                      icon: Icon(LucideIcons.xCircle,
                          size: 18, color: colorScheme.error),
                      onPressed: () => _cancelTask(task),
                      tooltip: '取消任务',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompletedTable(List<RemoteDownloadTaskModel> tasks) {
    final colorScheme = Theme.of(context).colorScheme;

    return DataTable(
      showCheckboxColumn: false,
      headingRowColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerHighest),
      columnSpacing: 24,
      columns: const [
        DataColumn(
            label: Text('名称',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('状态',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('大小',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('创建时间',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('操作',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: tasks.map((task) {
        final download = task.summary?.download;
        return DataRow(
          onSelectChanged: (_) => _showTaskDetail(task),
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Row(
                  children: [
                    _buildLeadingIcon(task.status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DataCell(_buildStatusBadge(task.status)),
            DataCell(
              download != null
                  ? Text(_formatSize(download.total),
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant))
                  : const Text('-', style: TextStyle(fontSize: 12)),
            ),
            DataCell(Text(_formatTime(task.createdAt),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant))),
            DataCell(
              download != null && download.files.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.layoutList, size: 18),
                      onPressed: () => _showFilesDialog(context, task),
                      tooltip: '查看文件',
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─── 移动端布局 ───

  Widget _buildMobileLayout(
      List<RemoteDownloadTaskModel> tasks, bool isOngoing) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 64,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) =>
          _buildTaskCard(tasks[index], isOngoing),
    );
  }

  Widget _buildTaskCard(RemoteDownloadTaskModel task, bool isOngoing) {
    final download = task.summary?.download;
    final hasFiles = download != null && download.files.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _getStatusColors(task.status);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showTaskDetail(task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Left: status icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getStatusIcon(task.status),
                      color: colors.icon, size: 18),
                ),
                const SizedBox(width: 12),
                // Middle: name + status/speed/size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.displayName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildMobileSubtitle(task, isOngoing),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right: more button
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  onPressed: () =>
                      _showMobileActionMenu(task, isOngoing, hasFiles),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            // Progress bar for downloading tasks
            if (isOngoing && download != null && download.total > 0) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: LinearProgressIndicator(
                  value: download.progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary),
                ),
              ),
            ],
            // Error text
            if (task.error != null && task.error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  task.error!,
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildMobileSubtitle(RemoteDownloadTaskModel task, bool isOngoing) {
    final download = task.summary?.download;
    final parts = <String>[task.status.text];

    if (isOngoing && download != null) {
      if (download.speedText.isNotEmpty) {
        parts.add(download.speedText);
      }
      if (download.total > 0) {
        parts.add(
            '${_formatSize(download.downloaded)} / ${_formatSize(download.total)}');
      }
    } else if (!isOngoing && download != null) {
      parts.add(_formatSize(download.total));
    }

    return parts.join(' · ');
  }

  // ─── 空状态 / 搜索无结果 ───

  Widget _buildEmptyState({required bool isOngoing}) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => _loadTasks(),
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOngoing
                      ? LucideIcons.download
                      : LucideIcons.checkCircle2,
                  size: 80,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  isOngoing ? '暂无下载中的任务' : '暂无已完成的任务',
                  style: TextStyle(
                      fontSize: 16, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 8),
                Text(
                  isOngoing ? '点击右下角按钮新建任务' : '下载完成的任务将显示在这里',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResult() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: const ValueKey('no_result'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '没有找到 "$_searchQuery"',
            style: TextStyle(
                fontSize: 16, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  // ─── 移动端操作菜单 ───

  void _showMobileActionMenu(
      RemoteDownloadTaskModel task, bool isOngoing, bool hasFiles) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text(
                task.displayName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.info),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(context);
                _showTaskDetail(task);
              },
            ),
            if (hasFiles)
              ListTile(
                leading: const Icon(LucideIcons.layoutList),
                title: const Text('查看文件'),
                onTap: () {
                  Navigator.pop(context);
                  _showFilesDialog(this.context, task);
                },
              ),
            if (isOngoing && task.status.isOngoing)
              ListTile(
                leading: Icon(LucideIcons.xCircle, color: colorScheme.error),
                title: Text('取消任务',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _cancelTask(task);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ─── 任务详情抽屉 ───

  void _showTaskDetail(RemoteDownloadTaskModel task) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;
    final colorScheme = Theme.of(context).colorScheme;
    final download = task.summary?.download;
    final hasFiles = download != null && download.files.isNotEmpty;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '任务详情',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero);
        return SlideTransition(
          position: tween.animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
            child: SafeArea(
              right: false,
              bottom: false,
              child: Container(
              width: isDesktop ? 420 : MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
                border: Border(
                    left: BorderSide(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5))),
              ),
              child: Column(
                children: [
                  _buildDetailHeader(task, colorScheme),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildDetailSection('基本信息', [
                          _buildDetailRow(
                            icon: LucideIcons.clock,
                            label: '创建于',
                            value: _formatDateTime(task.createdAt),
                          ),
                          _buildDetailRow(
                            icon: LucideIcons.refreshCw,
                            label: '更新于',
                            value: _formatDateTime(task.updatedAt),
                          ),
                          _buildDetailRow(
                            icon: _getStatusIcon(task.status),
                            label: '状态',
                            value: task.status.text,
                            valueWidget: _buildStatusBadge(task.status),
                          ),
                          if (task.node != null)
                            _buildDetailRow(
                              icon: LucideIcons.server,
                              label: '处理节点',
                              value: task.node!.displayName,
                            ),
                        ]),
                        const SizedBox(height: 20),
                        _buildDetailSection('下载信息', [
                          _buildDetailRow(
                            icon: LucideIcons.logIn,
                            label: '输入',
                            value: task.srcDisplayText,
                            copyable: true,
                          ),
                          _buildDetailRow(
                            icon: LucideIcons.logOut,
                            label: '输出',
                            value: task.dstDisplayText,
                            navigable: true,
                            onNavigate: () {
                              Navigator.of(context).pop();
                              _navigateToFolder(task);
                            },
                          ),
                          _buildDetailRow(
                            icon: LucideIcons.timer,
                            label: '执行净耗时',
                            value: task.durationText,
                          ),
                          _buildDetailRow(
                            icon: LucideIcons.refreshCw,
                            label: '重试次数',
                            value: '${task.retryCount}',
                          ),
                          if (download != null && download.numPieces > 0)
                            _buildDetailRow(
                              icon: LucideIcons.layoutGrid,
                              label: '分片数量',
                              value: '${download.numPieces}',
                            ),
                          if (download != null && download.total > 0) ...[
                            _buildDetailRow(
                              icon: LucideIcons.hardDrive,
                              label: '总大小',
                              value:
                                  '${_formatSize(download.downloaded)} / ${_formatSize(download.total)}',
                            ),
                            if (download.speedText.isNotEmpty)
                              _buildDetailRow(
                                icon: LucideIcons.gauge,
                                label: '下载速度',
                                value: download.speedText,
                              ),
                          ],
                        ]),
                        if (task.error != null &&
                            task.error!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildDetailSection('错误信息', [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                task.error!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onErrorContainer),
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 20),
                        // 操作按钮
                        Row(
                          children: [
                            if (hasFiles)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showFilesDialog(this.context, task);
                                  },
                                  icon: const Icon(LucideIcons.layoutList, size: 18),
                                  label: const Text('查看文件'),
                                ),
                              ),
                            if (hasFiles &&
                                task.status.isOngoing)
                              const SizedBox(width: 12),
                            if (task.status.isOngoing)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _cancelTask(task);
                                  },
                                  icon: Icon(LucideIcons.xCircle, size: 18),
                                  label: const Text('取消任务'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.error),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),  // Container
            ),  // SafeArea
          ),
        );
      },
    );
  }

  Widget _buildDetailHeader(
      RemoteDownloadTaskModel task, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          _buildLeadingIcon(task.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${task.id}',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
      String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? valueWidget,
    bool copyable = false,
    bool navigable = false,
    VoidCallback? onNavigate,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: valueWidget ??
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (copyable && value != '-')
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ToastHelper.success('已复制到剪贴板');
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(LucideIcons.copy,
                              size: 14, color: colorScheme.primary),
                        ),
                      ),
                    if (navigable && value != '-') ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onNavigate,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(LucideIcons.externalLink,
                              size: 14, color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
          ),
        ],
      ),
    );
  }

  void _navigateToFolder(RemoteDownloadTaskModel task) {
    final dst = task.summary?.dst ?? '';
    if (dst.isEmpty) return;

    String relativePath;
    if (dst.startsWith('cloudreve://my')) {
      relativePath = dst.replaceFirst('cloudreve://my', '');
      if (relativePath.isEmpty) relativePath = '/';
    } else {
      relativePath = dst;
    }

    try {
      final fileManager = Provider.of<FileManagerProvider>(
        context,
        listen: false,
      );
      final navProvider = Provider.of<NavigationProvider>(
        context,
        listen: false,
      );
      fileManager.enterFolder(relativePath);
      navProvider.setIndex(1);
      Navigator.of(context).popUntil((route) =>
          route.settings.name == '/home' || route.isFirst);
    } catch (e) {
      ToastHelper.info('目标路径: $relativePath');
    }
  }

  // ─── 对话框 ───

  /// 创建任务对话框
  Future<void> _showCreateDialog(BuildContext context) async {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;
    String selectedDst = '/';
    bool folderSelected = false;
    final srcController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建离线下载'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : MediaQuery.of(ctx).size.width - 48,
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 上方：目录选择区域
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择保存目录',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                if (folderSelected) ...[
                  // 已选择：显示路径 + 修改按钮
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.folder, size: 18, color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              selectedDst == '/' ? '/ (根目录)' : selectedDst,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setDialogState(() => folderSelected = false),
                          child: const Text('修改'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // 未选择：显示目录选择器
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FolderPicker(
                      currentPath: selectedDst,
                      maxVisibleItems: isDesktop ? null : 3,
                      onFolderSelected: (path) {
                        setDialogState(() {
                          selectedDst = path;
                          folderSelected = true;
                        });
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // 下方：下载链接
                TextField(
                  controller: srcController,
                  decoration: const InputDecoration(
                    labelText: '下载链接',
                    hintText: '输入 URL 或磁力链接，每行一个',
                    prefixIcon: Icon(LucideIcons.link),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || confirmed != true) return;

    final srcText = srcController.text.trim();
    if (srcText.isEmpty) {
      ToastHelper.error('请输入下载链接');
      return;
    }

    final urls = srcText
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      ToastHelper.error('请输入至少一个下载链接');
      return;
    }

    final dst = _toCloudreveUri(selectedDst);

    try {
      final tasks = await _service.createDownload(dst: dst, src: urls);
      if (!mounted) return;
      setState(() {
        _downloadingTasks = [...tasks, ..._downloadingTasks];
      });
      _tabController.animateTo(0);
      _startOrStopPolling();
      ToastHelper.success('已创建 ${tasks.length} 个任务');
    } catch (e) {
      if (!mounted) return;
      AppLogger.e('创建失败: $e');
      ToastHelper.failure('创建失败: $e');
    }
  }

  /// 将相对路径转为 cloudreve URI 格式
  String _toCloudreveUri(String path) {
    if (path.startsWith('cloudreve://')) return path;
    if (path == '/' || path.isEmpty) return 'cloudreve://my';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'cloudreve://my/$cleanPath';
  }

  /// 文件选择对话框
  Future<void> _showFilesDialog(
      BuildContext context, RemoteDownloadTaskModel task) async {
    final download = task.summary?.download;
    if (download == null || download.files.isEmpty) return;
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;
    final colorScheme = Theme.of(context).colorScheme;

    final selected = <int, bool>{
      for (final f in download.files) f.index: f.selected,
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title:
              Text(download.name.isNotEmpty ? download.name : '文件列表'),
          content: SizedBox(
            width: isDesktop ? 500 : MediaQuery.of(ctx).size.width - 48,
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: ListView.builder(
              itemCount: download.files.length,
              itemBuilder: (context, index) {
                final file = download.files[index];
                return CheckboxListTile(
                  value: selected[file.index] ?? file.selected,
                  title: Text(file.name,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatSize(file.size),
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  onChanged: (v) =>
                      setDialogState(() => selected[file.index] = v ?? true),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
            if (task.status.isOngoing)
              FilledButton(
                onPressed: () async {
                  final changes = <Map<String, dynamic>>[];
                  for (final file in download.files) {
                    final wasSelected = file.selected;
                    final nowSelected = selected[file.index] ?? wasSelected;
                    if (wasSelected != nowSelected) {
                      changes.add(
                          {'index': file.index, 'download': nowSelected});
                    }
                  }
                  if (changes.isEmpty) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  try {
                    await _service.selectFiles(
                        taskId: task.id, files: changes);
                    if (!mounted) return;
                    if (!context.mounted) return;
                    Navigator.of(ctx).pop();
                    ToastHelper.success('文件选择已更新');
                    _loadTasks();
                  } catch (e) {
                    if (!mounted) return;
                    ToastHelper.failure('更新失败: $e');
                  }
                },
                child: const Text('保存'),
              ),
          ],
        ),
      ),
    );
  }

  /// 取消任务
  Future<void> _cancelTask(RemoteDownloadTaskModel task) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消任务'),
        content: Text('确定要取消离线下载任务"${task.displayName}"吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('否')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('取消任务'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _service.cancelTask(taskId: task.id);
      if (!mounted) return;
      ToastHelper.success('任务已取消');
      _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ToastHelper.failure('取消失败: $e');
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
