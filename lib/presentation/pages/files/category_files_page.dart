// AI_PATCH_FORCE_PREVIEW_NO_SECOND_REQUEST_V3_20260611
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/constants/sort_options.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../../data/models/file_model.dart';
import '../../../router/app_router.dart';
import '../../../services/file_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/file_manager_provider.dart';
import '../../widgets/file_info_dialog.dart';
import '../../widgets/file_operation_dialogs.dart';
import '../../widgets/pdf_action_menu.dart';
import '../../widgets/selection_toolbar.dart';
import '../../widgets/thumbnail_image.dart';
import '../../widgets/toast_helper.dart';

/// 快捷入口分类页面参数。
///
/// category 对应 Cloudreve V4 文件 URI 查询条件：
/// image / video / audio / document。
class CategoryFilesPageArgs {
  final String category;
  final String title;
  final IconData icon;
  final Color color;

  const CategoryFilesPageArgs({
    required this.category,
    required this.title,
    required this.icon,
    required this.color,
  });

  factory CategoryFilesPageArgs.fromMap(Map<String, dynamic> map) {
    return CategoryFilesPageArgs(
      category: map['category'] as String,
      title: map['title'] as String,
      icon: map['icon'] as IconData? ?? LucideIcons.file,
      color: map['color'] as Color? ?? const Color(0xFF64748B),
    );
  }
}

/// 分类文件瀑布流页面。
///
/// 使用 Cloudreve V4 的文件 URI 查询：
/// cloudreve://my?category=image
/// cloudreve://my?category=video
/// cloudreve://my?category=audio
/// cloudreve://my?category=document
class CategoryFilesPage extends StatefulWidget {
  final CategoryFilesPageArgs args;

  const CategoryFilesPage({
    super.key,
    required this.args,
  });

  @override
  State<CategoryFilesPage> createState() => _CategoryFilesPageState();
}

class _CategoryFilesPageState extends State<CategoryFilesPage>
    with TickerProviderStateMixin {
  final _fileService = FileService();
  final _scrollController = ScrollController();

  final List<FileModel> _files = [];
  final Set<String> _selectedFilePaths = <String>{};
  String? _nextPageToken;
  String? _contextHint;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  SortOption _sortOption = SortOption.default_;

  bool get _hasSelection => _selectedFilePaths.isNotEmpty;

  List<FileModel> get _selectedFiles => _files
      .where((file) => _selectedFilePaths.contains(file.path))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _restoreSortOption();
    _loadFiles(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant CategoryFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.category != widget.args.category) {
      _clearSelection();
      _loadFiles(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_nextPageToken == null || _isLoading || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadFiles(refresh: false);
    }
  }

  Future<void> _loadFiles({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
        _nextPageToken = null;
        _contextHint = null;
        _files.clear();
        _selectedFilePaths.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _fileService.listFilesByCategory(
        category: widget.args.category,
        pageSize: 100,
        orderBy: _sortOption.field.apiKey,
        orderDirection: _sortOption.direction.apiKey,
        nextPageToken: refresh ? null : _nextPageToken,
      );

      final filesData = response['files'] as List<dynamic>? ?? const [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? const {};
      final newFiles = filesData
          .map((item) => FileModel.fromJson(item as Map<String, dynamic>))
          .where((file) => file.isFile)
          .toList();

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _files
            ..clear()
            ..addAll(newFiles);
        } else {
          final existingIds = _files.map((e) => e.id).toSet();
          _files.addAll(newFiles.where((file) => !existingIds.contains(file.id)));
        }

        _nextPageToken = pagination['next_token'] as String?;
        _contextHint = response['context_hint'] as String?;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildSortMenu() {
    final allOptions = [
      for (final field in SortField.values)
        for (final dir in SortDirection.values) SortOption(field, dir),
    ];

    return PopupMenuButton<SortOption>(
      icon: const Icon(LucideIcons.arrowUpDown),
      tooltip: '排序',
      position: PopupMenuPosition.under,
      onSelected: _setSortOption,
      itemBuilder: (context) => allOptions.map((option) {
        final isSelected = _sortOption == option;
        return PopupMenuItem<SortOption>(
          value: option,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                )
              else
                const SizedBox(width: 24),
              Text(option.menuLabel),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _refresh() => _loadFiles(refresh: true);

  Future<void> _restoreSortOption() async {
    final key = await StorageService.instance.getString(StorageKeys.fileSortOption);
    final option = SortOption.fromKey(key);
    if (option != _sortOption) {
      setState(() => _sortOption = option);
    }
  }

  Future<void> _setSortOption(SortOption option) async {
    if (_sortOption == option) return;
    setState(() => _sortOption = option);
    await StorageService.instance.setString(StorageKeys.fileSortOption, option.toKey());
    await _loadFiles(refresh: true);
  }

  void _toggleSelection(FileModel file) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedFilePaths.contains(file.path)) {
        _selectedFilePaths.remove(file.path);
      } else {
        _selectedFilePaths.add(file.path);
      }
    });
  }

  void _clearSelection() {
    if (_selectedFilePaths.isEmpty) return;
    setState(_selectedFilePaths.clear);
  }

  void _selectAllVisible() {
    setState(() {
      _selectedFilePaths
        ..clear()
        ..addAll(_files.map((file) => file.path));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasSelection) {
          _clearSelection();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: _buildBody(context),
        ),
        bottomNavigationBar: _buildSelectionBottomBar(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final args = widget.args;

    if (_hasSelection) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: '取消选择',
          onPressed: _clearSelection,
        ),
        centerTitle: true,
        title: Text('已选中 ${_selectedFilePaths.length} 个文件'),
        actions: [
          TextButton(
            onPressed: _selectAllVisible,
            child: const Text('全选'),
          ),
        ],
      );
    }

    return AppBar(
      title: Text(args.title),
      actions: [
        _buildSortMenu(),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw),
          tooltip: '刷新',
          onPressed: _refresh,
        ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(BuildContext context) {
    final selected = _selectedFiles;
    final singleSelected = selected.length == 1 ? selected.first : null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.10),
            end: Offset.zero,
          ).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: _hasSelection
            ? SelectionToolbar(
                key: const ValueKey('category-selection-toolbar'),
                selectionCount: _selectedFilePaths.length,
                totalCount: _files.length,
                onCancel: _clearSelection,
                onSelectAll: _selectAllVisible,
                onMore: singleSelected == null
                    ? null
                    : () => _showSelectionMore(context, singleSelected),
                onDownload: () => _downloadSelectedFiles(context, selected),
                onMove: () => FileOperationDialogs.showBatchMoveDialog(
                      context,
                      context.read<FileManagerProvider>(),
                      _selectedFilePaths.toList(),
                      false,
                    ),
                onCopy: () => FileOperationDialogs.showBatchMoveDialog(
                      context,
                      context.read<FileManagerProvider>(),
                      _selectedFilePaths.toList(),
                      true,
                    ),
                onDelete: () => _deleteSelectedFiles(context, selected),
              )
            : const SizedBox.shrink(
                key: ValueKey('category-selection-toolbar-empty'),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            LucideIcons.alertTriangle,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }

    if (_files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            widget.args.icon,
            size: 52,
            color: widget.args.color,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '没有找到${widget.args.title}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnCount = _columnCountForWidth(width);
        final spacing = width >= 720 ? 14.0 : 10.0;
        final horizontalPadding = width >= 720 ? 16.0 : 10.0;
        final columnWidth =
            (width - horizontalPadding * 2 - spacing * (columnCount - 1)) /
                columnCount;

        final columns = List.generate(columnCount, (_) => <FileModel>[]);
        final heights = List.generate(columnCount, (_) => 0.0);

        for (final file in _files) {
          final targetIndex = _indexOfMin(heights);
          columns[targetIndex].add(file);
          heights[targetIndex] += _estimatedTileHeight(file, columnWidth) + spacing;
        }

        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            _hasSelection ? 92 : 24,
          ),
          children: [
            _buildSummaryHeader(context),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < columnCount; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        for (final file in columns[i])
                          Padding(
                            padding: EdgeInsets.only(bottom: spacing),
                            child: _CategoryFileTile(
                              key: ValueKey('category-file-${file.id.isNotEmpty ? file.id : file.path}'),
                              file: file,
                              contextHint: _contextHint,
                              category: widget.args.category,
                              accentColor: widget.args.color,
                              isSelected: _selectedFilePaths.contains(file.path),
                              selectionMode: _hasSelection,
                              onTap: () {
                                if (_hasSelection) {
                                  _toggleSelection(file);
                                } else {
                                  _openFile(context, file);
                                }
                              },
                              onLongPress: () => _toggleSelection(file),
                              onSelect: () => _toggleSelection(file),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (i != columnCount - 1) SizedBox(width: spacing),
                ],
              ],
            ),
            if (_isLoadingMore) ...[
              const SizedBox(height: 8),
              const Center(child: CircularProgressIndicator()),
            ] else if (_nextPageToken != null) ...[
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _loadFiles(refresh: false),
                  icon: const Icon(LucideIcons.chevronsDown, size: 16),
                  label: const Text('加载更多'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.args.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(widget.args.icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.args.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${_files.length} 项',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  int _columnCountForWidth(double width) {
    if (width < 420) return 2;
    final count = (width / 186).floor();
    return count.clamp(2, 8).toInt();
  }

  int _indexOfMin(List<double> values) {
    var index = 0;
    var minValue = values[0];

    for (var i = 1; i < values.length; i++) {
      if (values[i] < minValue) {
        minValue = values[i];
        index = i;
      }
    }

    return index;
  }

  double _estimatedTileHeight(FileModel file, double width) {
    if (widget.args.category == 'audio') return 156;
    if (widget.args.category == 'document') return 168;
    return 218;
  }

  void _openFile(BuildContext context, FileModel file) {
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
      ToastHelper.info('暂不支持预览 ${FileTypeUtils.getFileTypeDescription(file.name)}');
    }
  }

  Future<void> _downloadSelectedFiles(
    BuildContext context,
    List<FileModel> selectedFiles,
  ) async {
    if (selectedFiles.isEmpty) return;

    try {
      final response = await _fileService.getDownloadUrls(
        uris: selectedFiles.map((file) => file.path).toList(),
        download: true,
        archive: selectedFiles.length > 1,
        contextHint: _contextHint,
      );

      final urls = response['urls'] as List<dynamic>? ?? const [];
      if (urls.isEmpty) {
        if (context.mounted) ToastHelper.failure('没有可用的下载链接');
        return;
      }

      String? url;
      final first = urls.first;
      if (first is String) {
        url = first;
      } else if (first is Map<String, dynamic>) {
        url = (first['url'] ?? first['download_url'] ?? first['src']) as String?;
      }

      if (url == null || url.isEmpty) {
        if (context.mounted) ToastHelper.failure('下载链接格式无效');
        return;
      }

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ToastHelper.failure('无法打开下载链接');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.failure('下载失败: $e');
      }
    }
  }

  Future<void> _deleteSelectedFiles(
    BuildContext context,
    List<FileModel> selectedFiles,
  ) async {
    if (selectedFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除这 ${selectedFiles.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _fileService.deleteFiles(
        uris: selectedFiles.map((file) => file.path).toList(),
      );
      if (!mounted) return;
      setState(() {
        final selectedPaths = selectedFiles.map((file) => file.path).toSet();
        _files.removeWhere((file) => selectedPaths.contains(file.path));
        _selectedFilePaths.clear();
      });
      ToastHelper.success('删除成功');
    } catch (e) {
      if (context.mounted) {
        ToastHelper.failure('删除失败: $e');
      }
    }
  }

  Future<void> _renameFile(BuildContext context, FileModel file) async {
    final controller = TextEditingController(text: file.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新名称',
            prefixIcon: Icon(LucideIcons.edit3, size: 20),
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    final newName = controller.text.trim();
    if (confirmed != true || newName.isEmpty || newName == file.name) return;

    try {
      final response = await _fileService.renameFile(
        uri: file.path,
        newName: newName,
      );
      if (!mounted) return;
      if (response.isEmpty) {
        await _refresh();
      } else {
        final updatedFile = FileModel.fromJson(response);
        setState(() {
          final index = _files.indexWhere((item) => item.path == file.path);
          if (index != -1) _files[index] = updatedFile;
          _selectedFilePaths
            ..remove(file.path)
            ..add(updatedFile.path);
        });
      }
      ToastHelper.success('重命名成功');
    } catch (e) {
      if (context.mounted) {
        ToastHelper.failure('重命名失败: $e');
      }
    }
  }

  void _showSelectionMore(BuildContext context, FileModel file) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _renameFile(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                FileInfoPanel.showAsBottomSheet(context, file);
              },
            ),
          ],
        ),
      ),
    );
  }
}



// AI_PATCH_FORCE_PREVIEW_NO_SECOND_REQUEST_20260611
// Category hover previews must not call /file/url. They reuse the same
// thumbnail cache used by the card, so hovering does not trigger a second
// network request or a thumbnail -> original-image flicker.
class _CategoryFullPreviewImage extends StatelessWidget {
  final FileModel file;
  final String? contextHint;
  final bool useOriginalImage;
  final double borderRadius;

  const _CategoryFullPreviewImage({
    required this.file,
    required this.contextHint,
    required this.useOriginalImage,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Keep useOriginalImage in the signature for compatibility with existing
    // call sites, but intentionally ignore it to avoid any /file/url request.
    Object.hash(useOriginalImage, file.id, file.updatedAt, contextHint);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ThumbnailImage(
        file: file,
        contextHint: contextHint,
        borderRadius: borderRadius,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _CategoryFileTile extends StatefulWidget {
  final FileModel file;
  final String? contextHint;
  final String category;
  final Color accentColor;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelect;

  const _CategoryFileTile({
    super.key,
    required this.file,
    required this.contextHint,
    required this.category,
    required this.accentColor,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSelect,
  });

  @override
  State<_CategoryFileTile> createState() => _CategoryFileTileState();
}

class _CategoryFileTileState extends State<_CategoryFileTile> {
  bool _hovering = false;
  Timer? _previewTimer;
  Timer? _previewRemoveTimer;
  OverlayEntry? _previewOverlay;
  ValueNotifier<bool>? _previewVisible;
  final GlobalKey _thumbnailKey = GlobalKey();

  bool get _canPreview {
    return !widget.file.isFolder &&
        (widget.category == 'image' || widget.category == 'video');
  }

  double _previewAspectRatio(Rect thumbnailRect) {
    final cachedRatio = ThumbnailImageSizeCache.aspectRatioFor(widget.file);
    if (cachedRatio != null && cachedRatio > 0) return cachedRatio.clamp(0.28, 3.2).toDouble();
    if (thumbnailRect.width > 0 && thumbnailRect.height > 0) {
      return (thumbnailRect.width / thumbnailRect.height).clamp(0.28, 3.2).toDouble();
    }
    return 1.0;
  }

  @override
  void dispose() {
    _cancelPreview();
    super.dispose();
  }

  void _onEnter() {
    if (!mounted) return;
    setState(() => _hovering = true);
  }

  void _onExit() {
    if (!mounted) return;
    setState(() => _hovering = false);
    _cancelPreview();
  }

  void _onPreviewHoverEnter() {
    if (!mounted || !_canPreview) return;
    _previewTimer?.cancel();
    _previewRemoveTimer?.cancel();

    if (_previewOverlay != null) {
      _previewVisible?.value = true;
      return;
    }

    _previewTimer = Timer(const Duration(seconds: 2), _showPreviewOverlay);
  }

  void _onPreviewHoverExit() {
    _cancelPreview();
  }

  void _cancelPreview() {
    _previewTimer?.cancel();
    _previewTimer = null;

    final visible = _previewVisible;
    final overlay = _previewOverlay;
    if (visible == null || overlay == null) {
      return;
    }

    visible.value = false;
    _previewRemoveTimer?.cancel();
    _previewRemoveTimer = Timer(const Duration(milliseconds: 280), () {
      overlay.remove();
      visible.dispose();
      if (identical(_previewOverlay, overlay)) {
        _previewOverlay = null;
        _previewVisible = null;
      }
      _previewRemoveTimer = null;
    });
  }

  void _showPreviewOverlay() {
    if (!mounted || !_hovering || !_canPreview || _previewOverlay != null) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final thumbnailRenderObject = _thumbnailKey.currentContext?.findRenderObject();
    if (thumbnailRenderObject is! RenderBox || !thumbnailRenderObject.hasSize) {
      return;
    }

    final thumbnailRect =
        thumbnailRenderObject.localToGlobal(Offset.zero) & thumbnailRenderObject.size;
    final screenSize = MediaQuery.sizeOf(context);
    final aspectRatio = _previewAspectRatio(thumbnailRect);
    final maxWidth = (screenSize.width - 24).clamp(280.0, 880.0).toDouble();
    final maxHeight = (screenSize.height - 24).clamp(280.0, 760.0).toDouble();
    var previewWidth = (thumbnailRect.width * 3.55).clamp(320.0, maxWidth).toDouble();
    var previewHeight = previewWidth / aspectRatio;
    final minHeight = (thumbnailRect.height * 2.85).clamp(280.0, maxHeight).toDouble();
    if (previewHeight < minHeight) {
      previewHeight = minHeight;
      previewWidth = previewHeight * aspectRatio;
    }
    if (previewHeight > maxHeight) {
      previewHeight = maxHeight;
      previewWidth = previewHeight * aspectRatio;
    }
    if (previewWidth > maxWidth) {
      previewWidth = maxWidth;
      previewHeight = previewWidth / aspectRatio;
    }
    final previewVisible = ValueNotifier<bool>(false);
    final collapsedScale = (thumbnailRect.width / previewWidth).clamp(0.58, 0.84).toDouble();

    _previewRemoveTimer?.cancel();
    _previewVisible = previewVisible;

    _previewOverlay = OverlayEntry(
      builder: (overlayContext) {
        final screenSize = MediaQuery.sizeOf(overlayContext);
        final idealLeft = thumbnailRect.center.dx - previewWidth / 2;
        final idealTop = thumbnailRect.center.dy - previewHeight / 2;
        final left = idealLeft
            .clamp(8.0, screenSize.width - previewWidth - 8.0)
            .toDouble();
        final top = idealTop
            .clamp(8.0, screenSize.height - previewHeight - 8.0)
            .toDouble();

        return Positioned(
          left: left,
          top: top,
          width: previewWidth,
          height: previewHeight,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: previewVisible,
              builder: (context, visible, child) {
                return AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: AnimatedScale(
                    scale: visible ? 1 : collapsedScale,
                    duration: const Duration(milliseconds: 260),
                    curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CategoryFullPreviewImage(
                      file: widget.file,
                      contextHint: widget.contextHint,
                      useOriginalImage: widget.category == 'image',
                      borderRadius: 14,
                    ),
                    if (widget.category == 'video')
                      Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.play,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_previewOverlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_previewVisible, previewVisible)) return;
      previewVisible.value = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMedia = widget.category == 'image' || widget.category == 'video';
    final isAudio = widget.category == 'audio';
    final isDocument = widget.category == 'document';

    final ext = FileTypeUtils.getExtension(widget.file.name);
    final isPsd = ext == 'psd' || ext == 'psb';

    final borderColor = widget.isSelected
        ? theme.colorScheme.primary
        : theme.dividerColor.withValues(alpha: 0.12);

    final showSelectionCircle = widget.selectionMode || widget.isSelected || _hovering;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        scale: widget.isSelected ? 0.985 : 1.0,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MouseRegion(
                      onEnter: (_) => _onPreviewHoverEnter(),
                      onExit: (_) => _onPreviewHoverExit(),
                      child: AspectRatio(
                        key: _thumbnailKey,
                        aspectRatio: isMedia || isPsd ? 1 : 1.45,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: ThumbnailImage(
                                file: widget.file,
                                contextHint: widget.contextHint,
                                borderRadius: 0,
                                fit: isMedia ? BoxFit.cover : BoxFit.contain,
                              ),
                            ),
                          Positioned(
                            top: 7,
                            left: 7,
                            child: _TypeBadge(
                              icon: _badgeIcon(),
                              label: _badgeLabel(ext),
                              color: widget.accentColor,
                              compact: isMedia,
                            ),
                          ),
                          if (widget.category == 'video')
                            const Center(
                              child: _PlayOverlay(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.file.name,
                            maxLines: isAudio || isDocument ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${FileTypeUtils.getFileTypeDescription(widget.file.name)} · ${date_utils.DateUtils.formatFileSize(widget.file.size)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: borderColor,
                          width: widget.isSelected ? 2.2 : 1,
                        ),
                        boxShadow: widget.isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: MouseRegion(
                    onEnter: (_) => _cancelPreview(),
                    child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 130),
                    opacity: showSelectionCircle ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showSelectionCircle,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        scale: showSelectionCircle ? 1 : 0.86,
                        child: _SelectionCircle(
                          selected: widget.isSelected,
                          onTap: widget.onSelect,
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  IconData _badgeIcon() {
    switch (widget.category) {
      case 'image':
        return LucideIcons.image;
      case 'video':
        return LucideIcons.video;
      case 'audio':
        return LucideIcons.music;
      case 'document':
        return LucideIcons.fileText;
      default:
        return LucideIcons.file;
    }
  }

  String _badgeLabel(String ext) {
    if (ext == 'psd' || ext == 'psb') return ext.toUpperCase();
    switch (widget.category) {
      case 'image':
        return '图片';
      case 'video':
        return '视频';
      case 'audio':
        return '音乐';
      case 'document':
        return '文档';
      default:
        return '文件';
    }
  }
}

class _SelectionCircle extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;

  const _SelectionCircle({
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? colorScheme.primary
                : colorScheme.surface.withValues(alpha: 0.86),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.42),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: selected
              ? const Icon(
                  LucideIcons.check,
                  color: Colors.white,
                  size: 13,
                )
              : null,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const _TypeBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 7,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(
          LucideIcons.play,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
