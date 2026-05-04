import 'dart:async';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:cloudreve4_flutter/presentation/widgets/folder_picker.dart';
import 'package:flutter/material.dart';
import '../../../data/models/remote_download_task_model.dart';
import '../../../services/remote_download_service.dart';
import '../../widgets/toast_helper.dart';

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
    // 下载中 Tab 激活时自动轮询
    int refreshTime = 1;
    if (_tabController.index == 0 && _downloadingTasks.isNotEmpty) {
      _pollTimer = Timer.periodic(Duration(seconds: refreshTime), (_) => _loadTasks(quiet: true));
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
          .map((t) => RemoteDownloadTaskModel.fromJson(t as Map<String, dynamic>))
          .toList();
      final cdTasks = (cdData['tasks'] as List<dynamic>? ?? [])
          .map((t) => RemoteDownloadTaskModel.fromJson(t as Map<String, dynamic>))
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('离线下载', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: !isDesktop,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '下载中 (${_downloadingTasks.length})'),
            Tab(text: '已完成 (${_completedTasks.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadTasks(),
            tooltip: '刷新',
          ),
          if (isDesktop) const SizedBox(width: 16),
        ],
      ),
      body: _isLoading && _downloadingTasks.isEmpty && _completedTasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_downloadingTasks, isOngoing: true),
                _buildTaskList(_completedTasks, isOngoing: false),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        label: const Text('新建任务'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskList(List<RemoteDownloadTaskModel> tasks, {required bool isOngoing}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_for_offline_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isOngoing ? '暂无下载中的任务' : '暂无已完成的任务',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) => _buildTaskCard(tasks[index], isOngoing),
      ),
    );
  }

  Widget _buildTaskCard(RemoteDownloadTaskModel task, bool isOngoing) {
    final download = task.summary?.download;
    final hasFiles = download != null && download.files.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：名称 + 状态标签
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 8),

            // 进度信息（下载中任务）
            if (isOngoing && download != null) ...[
              if (download.total > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: download.progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(download.progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Text(
                    '${_formatSize(download.downloaded)} / ${_formatSize(download.total)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (download.speedText.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      download.speedText,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ] else if (!isOngoing && download != null) ...[
              Text(
                _formatSize(download.total),
                style: const TextStyle(fontSize: 12),
              ),
            ],

            // 错误信息
            if (task.error != null && task.error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.error!, style: TextStyle(fontSize: 12, color: Colors.red.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            // 底部操作行
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatTime(task.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                if (hasFiles)
                  TextButton.icon(
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('文件'),
                    onPressed: () => _showFilesDialog(context, task),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                if (isOngoing && task.status.isOngoing)
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                    label: const Text('取消', style: TextStyle(color: Colors.red)),
                    onPressed: () => _cancelTask(task),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(RemoteDownloadStatus status) {
    Color color;
    switch (status) {
      case RemoteDownloadStatus.queued:
        color = Colors.grey;
      case RemoteDownloadStatus.running:
        color = Colors.blue;
      case RemoteDownloadStatus.completed:
        color = Colors.green;
      case RemoteDownloadStatus.error:
        color = Colors.red;
      case RemoteDownloadStatus.suspending:
      case RemoteDownloadStatus.suspended:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  /// 创建任务对话框
  Future<void> _showCreateDialog(BuildContext context) async {
    String selectedDst = '/';
    final srcController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建离线下载'),
          content: SizedBox(
            width: 500,
            height: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 链接输入
                TextField(
                  controller: srcController,
                  decoration: const InputDecoration(
                    labelText: '下载链接',
                    hintText: '输入 URL 或磁力链接，每行一个',
                    prefixIcon: Icon(Icons.link),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // 目录选择
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择保存目录', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FolderPicker(
                      currentPath: selectedDst,
                      onFolderSelected: (path) {
                        setDialogState(() => selectedDst = path);
                      },
                    ),
                  ),
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

    final urls = srcText.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (urls.isEmpty) {
      ToastHelper.error('请输入至少一个下载链接');
      return;
    }

    // 将相对路径转为 cloudreve URI
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
  Future<void> _showFilesDialog(BuildContext context, RemoteDownloadTaskModel task) async {
    final download = task.summary?.download;
    if (download == null || download.files.isEmpty) return;

    // 本地维护选中状态
    final selected = <int, bool>{
      for (final f in download.files) f.index: f.selected,
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(download.name.isNotEmpty ? download.name : '文件列表'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              itemCount: download.files.length,
              itemBuilder: (context, index) {
                final file = download.files[index];
                return CheckboxListTile(
                  value: selected[file.index] ?? file.selected,
                  title: Text(file.name, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatSize(file.size), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  onChanged: (v) => setDialogState(() => selected[file.index] = v ?? true),
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
                      changes.add({'index': file.index, 'download': nowSelected});
                    }
                  }
                  if (changes.isEmpty) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  try {
                    await _service.selectFiles(taskId: task.id, files: changes);
                    if (!mounted) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消任务'),
        content: Text('确定要取消离线下载任务"${task.displayName}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('否')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
}
