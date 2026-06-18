import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../core/utils/file_icon_utils.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../../data/models/file_model.dart';
import '../../../router/app_router.dart';
import '../../../services/file_service.dart';
import '../../providers/download_manager_provider.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/file_list_header.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/pdf_action_menu.dart';
import '../../widgets/toast_helper.dart';

/// 所有转存 / 与我共享文件页面。
///
/// Cloudreve V4 的 shared_with_me 文件系统用于展示别人共享给当前用户的
/// 文件入口；首页"转存文件"的查看更多会进入此页面。
class TransferredFilesPage extends StatefulWidget {
  final String? initialUri;

  const TransferredFilesPage({super.key, this.initialUri});

  @override
  State<TransferredFilesPage> createState() => _TransferredFilesPageState();
}

enum _TransferredViewMode { list, grid }

class _TransferredFilesPageState extends State<TransferredFilesPage> {
  static const String _rootUri = 'cloudreve://shared_with_me';

  final List<_TransferredBreadcrumb> _breadcrumbs = [];
  final Set<String> _selectedPaths = <String>{};

  List<FileModel> _files = const [];
  bool _loading = true;
  bool _downloadPreparing = false;
  String? _error;
  String? _currentUri;
  String? _contextHint;
  _TransferredViewMode _viewMode = _TransferredViewMode.list;

  bool get _hasSelection => _selectedPaths.isNotEmpty;

  bool get _allVisibleSelected =>
      _files.isNotEmpty && _files.every((file) => _selectedPaths.contains(file.path));

  List<FileModel> get _selectedFiles =>
      _files.where((file) => _selectedPaths.contains(file.path)).toList();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUri?.trim();
    _currentUri = initial == null || initial.isEmpty ? _rootUri : initial;
    _breadcrumbs.add(
      _TransferredBreadcrumb(title: '全部转存文件', uri: _currentUri!),
    );
    Future.microtask(() => _load(_currentUri!, replaceRoot: true));
  }

  Future<void> _load(String uri, {String? title, bool replaceRoot = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPaths.clear();
    });

    try {
      final response = uri == _rootUri || uri == '$_rootUri/'
          ? await FileService().listSharedWithMeFiles(
              pageSize: 200,
              orderBy: 'updated_at',
              orderDirection: 'desc',
            )
          : await FileService().listFiles(
              uri: uri,
              pageSize: 200,
              orderBy: 'updated_at',
              orderDirection: 'desc',
            );

      final rawFiles = response['files'] as List<dynamic>? ?? const [];
      final parsed = rawFiles
          .map((item) => FileModel.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final aTime = a.updatedAt.isAfter(a.createdAt) ? a.updatedAt : a.createdAt;
          final bTime = b.updatedAt.isAfter(b.createdAt) ? b.updatedAt : b.createdAt;
          return bTime.compareTo(aTime);
        });

      if (!mounted) return;
      setState(() {
        _files = parsed;
        _currentUri = uri;
        _contextHint = response['context_hint'] as String?;
        if (replaceRoot) {
          _breadcrumbs
            ..clear()
            ..add(_TransferredBreadcrumb(title: title ?? '全部转存文件', uri: uri));
        } else if (title != null && (_breadcrumbs.isEmpty || _breadcrumbs.last.uri != uri)) {
          _breadcrumbs.add(_TransferredBreadcrumb(title: title, uri: uri));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _files = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openFolder(FileModel file) async {
    await _load(file.path, title: file.name);
  }

  void _openFile(FileModel file) {
    if (FileTypeUtils.isImage(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.imagePreview, arguments: file);
    } else if (FileTypeUtils.isPdf(file.name)) {
      PdfActionMenu.show(context, file);
    } else if (FileTypeUtils.isVideo(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.videoPreview, arguments: file);
    } else if (FileTypeUtils.isAudio(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.audioPreview, arguments: file);
    } else if (FileTypeUtils.isMarkdown(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.markdownPreview, arguments: file);
    } else if (FileTypeUtils.isTextCode(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.documentPreview, arguments: file);
    } else {
      _openFileInfo(file);
    }
  }

  void _onFileTap(FileModel file) {
    if (_hasSelection) {
      _toggleSelection(file);
      return;
    }

    if (file.isFolder) {
      _openFolder(file);
    } else {
      _openFile(file);
    }
  }

  void _toggleSelection(FileModel file) {
    setState(() {
      if (_selectedPaths.contains(file.path)) {
        _selectedPaths.remove(file.path);
      } else {
        _selectedPaths.add(file.path);
      }
    });
  }

  void _clearSelection() {
    if (!_hasSelection) return;
    setState(_selectedPaths.clear);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allVisibleSelected) {
        _selectedPaths.clear();
      } else {
        _selectedPaths
          ..clear()
          ..addAll(_files.map((file) => file.path));
      }
    });
  }

  Future<void> _downloadSelected() async {
    final items = _selectedFiles;
    if (items.isEmpty) return;
    await _downloadFiles(items);
    if (mounted) _clearSelection();
  }

  Future<void> _downloadFiles(List<FileModel> items) async {
    if (items.isEmpty || _downloadPreparing) return;

    setState(() => _downloadPreparing = true);

    try {
      final downloadManager = context.read<DownloadManagerProvider>();
      final shouldArchive = items.length > 1 || items.any((file) => file.isFolder);

      if (shouldArchive) {
        final uris = items.map((file) => file.path).toList();
        final response = await FileService().getDownloadUrls(
          uris: uris,
          download: true,
          archive: true,
          contextHint: _contextHint,
          noCache: true,
        );

        final url = _extractFirstDownloadUrl(response);
        if (url == null || url.isEmpty) {
          throw Exception('服务端没有返回下载链接');
        }

        final archiveName = _archiveNameFor(items);
        final archiveUri = items.length == 1
            ? items.first.path
            : 'archive:${DateTime.now().millisecondsSinceEpoch}:${uris.join('|')}';

        final task = await downloadManager.addDownloadTask(
          fileName: archiveName,
          fileUri: archiveUri,
          fileSize: 0,
        );

        if (!mounted) return;
        if (task == null) {
          ToastHelper.info('下载任务已存在');
        } else {
          ToastHelper.success('已添加压缩包下载任务');
        }
        return;
      }

      final file = items.first;
      final task = await downloadManager.addDownloadTask(
        fileName: file.name,
        fileUri: file.path,
        fileSize: file.size,
      );

      if (!mounted) return;
      if (task == null) {
        ToastHelper.info('下载任务已存在');
      } else {
        ToastHelper.success('已添加下载任务');
      }
    } catch (e) {
      if (mounted) ToastHelper.failure('添加下载任务失败: $e');
    } finally {
      if (mounted) setState(() => _downloadPreparing = false);
    }
  }

  String? _extractFirstDownloadUrl(Map<String, dynamic> response) {
    final direct = response['url'];
    if (direct is String && direct.isNotEmpty) return direct;

    final urls = response['urls'];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first;
      if (first is String && first.isNotEmpty) return first;
      if (first is Map<String, dynamic>) {
        final value = first['url'];
        if (value is String && value.isNotEmpty) return value;
      }
      if (first is Map) {
        final value = first['url'];
        if (value is String && value.isNotEmpty) return value;
      }
    }

    return null;
  }

  String _archiveNameFor(List<FileModel> items) {
    if (items.length == 1) {
      final name = items.first.name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
      return name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
    }

    final now = DateTime.now();
    final stamp = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
      '_',
      now.hour.toString().padLeft(2, '0'),
      now.minute.toString().padLeft(2, '0'),
      now.second.toString().padLeft(2, '0'),
    ].join();

    return '转存文件_$stamp.zip';
  }

  void _openFileInfo(FileModel file) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FileIconUtils.buildIconWidget(
                      context: context,
                      file: file,
                      size: 44,
                      iconSize: 22,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildInfoRow('类型', FileIconUtils.getFileTypeLabel(file.name, isFolder: file.isFolder)),
                _buildInfoRow('大小', file.isFolder ? '文件夹' : app_date_utils.DateUtils.formatFileSize(file.size)),
                _buildInfoRow('更新时间', app_date_utils.DateUtils.formatDateTime(file.updatedAt)),
                _buildInfoRow('来源', '与我共享 / 转存文件'),
                const SizedBox(height: 8),
                Text(
                  file.path,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: theme.hintColor)),
          ),
          Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _onRefresh() => _load(_currentUri ?? _rootUri, replaceRoot: false);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return PopScope(
      canPop: !_hasSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasSelection) _clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_hasSelection ? '已选中 ${_selectedPaths.length} 项' : '所有转存文件'),
          actions: [
            if (_hasSelection) ...[
              IconButton(
                tooltip: '下载选中项',
                onPressed: _downloadPreparing ? null : _downloadSelected,
                icon: _downloadPreparing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.download),
              ),
              IconButton(
                tooltip: _allVisibleSelected ? '取消全选' : '全选',
                onPressed: _files.isEmpty ? null : _toggleSelectAll,
                icon: Icon(_allVisibleSelected ? LucideIcons.checkCheck : LucideIcons.checkSquare),
              ),
              IconButton(
                tooltip: '取消选择',
                onPressed: _clearSelection,
                icon: const Icon(LucideIcons.x),
              ),
            ],
            IconButton(
              tooltip: _viewMode == _TransferredViewMode.list ? '切换大图模式' : '切换列表模式',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == _TransferredViewMode.list
                      ? _TransferredViewMode.grid
                      : _TransferredViewMode.list;
                });
              },
              icon: Icon(
                _viewMode == _TransferredViewMode.list
                    ? LucideIcons.layoutGrid
                    : LucideIcons.list,
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _onRefresh,
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBreadcrumbs(context),
            if (_hasSelection) _buildSelectionBar(context),
            if (!_loading &&
                _error == null &&
                _files.isNotEmpty &&
                _viewMode == _TransferredViewMode.list &&
                isDesktop)
              FileListHeader(
                showCheckbox: _hasSelection,
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(context)
                      : _files.isEmpty
                          ? _buildEmpty(context)
                          : RefreshIndicator(
                              onRefresh: _onRefresh,
                              child: _viewMode == _TransferredViewMode.grid
                                  ? _buildGridView(context, isDesktop)
                                  : _buildListView(context, isDesktop),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.16))),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已选中 ${_selectedPaths.length} 项',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _downloadPreparing ? null : _downloadSelected,
            icon: _downloadPreparing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.download, size: 16),
            label: const Text('下载'),
          ),
          TextButton(
            onPressed: _clearSelection,
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, bool isDesktop) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 8, isDesktop ? 28 : 16, 24),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return FileListItem(
          file: file,
          index: index,
          isDesktop: isDesktop,
          isSelected: _selectedPaths.contains(file.path),
          showCheckbox: _hasSelection,
          onTap: () => _onFileTap(file),
          onSelect: () => _toggleSelection(file),
          onDownload: () => _downloadFiles([file]),
          onInfo: () => _openFileInfo(file),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context, bool isDesktop) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 12, isDesktop ? 28 : 16, 28),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isDesktop ? 230 : 180,
        mainAxisSpacing: isDesktop ? 14 : 10,
        crossAxisSpacing: isDesktop ? 14 : 10,
        childAspectRatio: isDesktop ? 0.86 : 0.82,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return FileGridItem(
          file: file,
          isSelected: _selectedPaths.contains(file.path),
          showCheckbox: _hasSelection,
          contextHint: _contextHint,
          onTap: () => _onFileTap(file),
          onSelect: () => _toggleSelection(file),
          onDownload: () => _downloadFiles([file]),
          onInfo: () => _openFileInfo(file),
        );
      },
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _breadcrumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(LucideIcons.chevronRight, size: 14, color: theme.hintColor),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: i == _breadcrumbs.length - 1
                    ? null
                    : () {
                        final item = _breadcrumbs[i];
                        setState(() {
                          _breadcrumbs.removeRange(i + 1, _breadcrumbs.length);
                        });
                        _load(item.uri);
                      },
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: i == _breadcrumbs.length - 1
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _breadcrumbs[i].title,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary,
                      fontWeight: i == _breadcrumbs.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 46),
            const SizedBox(height: 12),
            Text(_error ?? '加载失败', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.share2, size: 56, color: theme.hintColor.withValues(alpha: 0.65)),
          const SizedBox(height: 12),
          Text('暂无转存文件', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('这里会显示与我共享 / 从分享转存相关的文件', style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }
}

class _TransferredBreadcrumb {
  final String title;
  final String uri;

  const _TransferredBreadcrumb({required this.title, required this.uri});
}
