import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:cloudreve4_flutter/services/upload_service.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/constants/sort_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/download_manager_provider.dart';
import '../../providers/upload_manager_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/file_list_header.dart';
import '../../widgets/file_breadcrumb.dart';
import '../../widgets/selection_toolbar.dart';
import '../../widgets/empty_folder_view.dart';
import '../../widgets/upload_dialog.dart';
import '../../widgets/file_operation_dialogs.dart';
import '../../widgets/file_info_dialog.dart';
import '../../widgets/search_dialog.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/thumbnail_image.dart';
import '../../../router/app_router.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;

// ---------------------------------------------------------------------------
// Desktop category tab definition
// ---------------------------------------------------------------------------

class _DesktopCategoryTab {
  final int index;
  final String label;
  /// null = all, 'recent', 'document', 'image', 'video', 'audio',
  /// 'transferred', 'shares', 'recycle'
  final String? key;
  /// Whether this tab navigates away rather than filtering
  final bool isNavigation;

  const _DesktopCategoryTab(
    this.index,
    this.label,
    this.key, {
    this.isNavigation = false,
  });
}

const _desktopCategories = <_DesktopCategoryTab>[
  _DesktopCategoryTab(0, '全部', null),
  _DesktopCategoryTab(1, '最近', 'recent'),
  _DesktopCategoryTab(2, '文档', 'document'),
  _DesktopCategoryTab(3, '图片', 'image'),
  _DesktopCategoryTab(4, '视频', 'video'),
  _DesktopCategoryTab(5, '音频', 'audio'),
  _DesktopCategoryTab(6, '转存', 'transferred', isNavigation: true),
  _DesktopCategoryTab(7, '我的分享', 'shares', isNavigation: true),
  _DesktopCategoryTab(8, '回收站', 'recycle', isNavigation: true),
];

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> with TickerProviderStateMixin {
  bool _isFirstLoad = true;
  FileModel? _infoFile;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _breadcrumbController = ScrollController();

  // FAB 状态
  bool _isFabVisible = true;
  bool _isFabExpanded = false;
  Timer? _fabShowTimer;

  // 桌面端拖拽状态
  bool _isDraggingOver = false;

  // 滑动手势追踪
  Offset? _swipeStartPos;
  DateTime? _swipeStartTime;

  // 桌面端分类 Tab 索引
  int _desktopCategoryIndex = 0;

  // 桌面端首页概览折叠状态
  bool _isSummaryCollapsed = false;

  // 桌面端分类 Tab 下划线动画控制器
  late final AnimationController _tabUnderlineController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollForPagination);
    _scrollController.addListener(_onScrollForSummaryCollapse);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _tabUnderlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
        fileManager.restoreViewType();
        fileManager.restoreSortOption();
        if (_isFirstLoad) {
          fileManager.loadFiles();
          fileManager.loadTransferredFiles();
          _isFirstLoad = false;
        }
        final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);
        downloadManager.initialize();
      }
    });

    // 上传完成 -> 自动刷新当前目录文件列表
    UploadService.instance.onUploadCompleted = (targetPath, fileName) {
      if (!mounted) return;
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
      final normalizedCurrent = FileUtils.toCloudreveUri(fileManager.currentPath);
      if (targetPath == normalizedCurrent) {
        final fileUri = targetPath.endsWith('/')
            ? '$targetPath$fileName'
            : '$targetPath/$fileName';
        fileManager.addFileByUri(fileUri);
      }
    };
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollForPagination);
    _scrollController.removeListener(_onScrollForSummaryCollapse);
    _scrollController.dispose();
    _breadcrumbController.dispose();
    _fabShowTimer?.cancel();
    _tabUnderlineController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    UploadService.instance.onUploadCompleted = null;
    super.dispose();
  }

  void _onScrollForPagination() {
    if (!_scrollController.hasClients) return;
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    if (!fileManager.hasMore || fileManager.isLoadingMore || fileManager.isLoading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      fileManager.loadMoreFiles();
    }
  }

  void _onScrollForSummaryCollapse() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    final shouldCollapse = pixels > 60;
    if (shouldCollapse != _isSummaryCollapsed) {
      setState(() => _isSummaryCollapsed = shouldCollapse);
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    // Ctrl+F / Cmd+F -> 打开搜索
    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      if (ModalRoute.of(context)?.isCurrent == false) return false;
      final nav = Provider.of<NavigationProvider>(context, listen: false);
      if (nav.currentIndex == 1 && !SearchDialog.isShowing) {
        SearchDialog.show(context);
        return true;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _swipeStartPos = event.position;
    _swipeStartTime = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_swipeStartPos == null || _swipeStartTime == null) return;
    final dx = event.position.dx - _swipeStartPos!.dx;
    final dy = event.position.dy - _swipeStartPos!.dy;
    final duration = DateTime.now().difference(_swipeStartTime!);
    _swipeStartPos = null;
    _swipeStartTime = null;
    // 从右往左快速滑动 -> 返回上一级
    if (dx < -150 && dx.abs() > dy.abs() * 1.5 && duration.inMilliseconds < 500) {
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
      if (fileManager.currentPath != '/') {
        fileManager.goBack();
      }
    }
  }

  void _showFileInfo(FileModel file) {
    setState(() => _infoFile = file);
    // 等待下一帧 rebuild 完成，endDrawer 从 null 变为非 null 后再打开
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  void _showSelectionMore(
    FileModel file,
    FileManagerProvider fileManager,
  ) {
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
                FileOperationDialogs.showRenameDialog(context, fileManager, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showFileInfo(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- FAB 显隐控制 ----

  void _hideFab() {
    _fabShowTimer?.cancel();
    if (_isFabVisible) {
      setState(() {
        _isFabVisible = false;
        _isFabExpanded = false;
      });
    }
  }

  void _scheduleShowFab() {
    _fabShowTimer?.cancel();
    _fabShowTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && !_isFabVisible) {
        setState(() => _isFabVisible = true);
      }
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      _hideFab();
    } else if (notification is ScrollEndNotification) {
      _scheduleShowFab();
    }
    return false;
  }

  void _toggleFabExpanded() {
    setState(() => _isFabExpanded = !_isFabExpanded);
  }

  void _onFabSubAction(VoidCallback action) {
    setState(() => _isFabExpanded = false);
    action();
  }

  // ---- Desktop category tab handling ----

  void _onDesktopCategoryTap(int index) {
    final tab = _desktopCategories[index];
    if (tab.isNavigation) {
      _handleNavigationTab(tab.key);
      return;
    }
    setState(() => _desktopCategoryIndex = index);
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    fileManager.setActiveCategory(tab.key);
  }

  void _handleNavigationTab(String? key) {
    switch (key) {
      case 'transferred':
        Navigator.of(context).pushNamed(RouteNames.transferredFiles);
        break;
      case 'shares':
        Navigator.of(context).pushNamed(RouteNames.share);
        break;
      case 'recycle':
        Navigator.of(context).pushNamed(RouteNames.recycleBin);
        break;
    }
  }

  // ---- 构建方法 ----

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: isDesktop ? null : _buildMobileAppBar(context),
        body: isDesktop ? _buildDesktopBody(context) : _buildBody(context),
        bottomNavigationBar: _buildBottomBar(context),
        endDrawer: _infoFile != null ? FileInfoPanel(file: _infoFile!) : null,
        floatingActionButton: isDesktop ? null : _buildSpeedDialFAB(context),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      title: Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return _buildMobileBreadcrumb(context, fileManager);
        },
      ),
      actions: _buildMobileActions(),
    );
  }

  /// 桌面端整体布局：顶栏 + Summary + 分类 Tabs + 文件列表
  Widget _buildDesktopBody(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(context);
    final isAtRoot = fileManager.currentPath == '/';

    // 返回根目录时同步分类 Tab 到"全部"
    if (isAtRoot && fileManager.activeCategory == null && _desktopCategoryIndex != 0) {
      _desktopCategoryIndex = 0;
    }

    final column = Column(
      children: [
        // 顶栏：仅子目录显示（根目录操作按钮移至 Category Tabs 右侧）
        if (!isAtRoot) _buildDesktopTopBar(context, fileManager),
        // Home Summary Panel（仅根目录，可折叠）
        if (isAtRoot)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isSummaryCollapsed
                ? const SizedBox.shrink()
                : _buildDesktopSummaryPanel(context, fileManager),
          ),
        // Category Tabs（仅根目录）
        if (isAtRoot) _buildDesktopCategoryTabs(context, Theme.of(context).colorScheme, fileManager),
        // 文件列表
        Expanded(child: _buildDesktopFileList(context)),
      ],
    );

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return column;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        _handleDroppedFiles(details.files);
      },
      child: Stack(
        children: [
          column,
          if (_isDraggingOver)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.upload, size: 28, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '释放文件以上传到当前目录',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileManager.currentPath,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Inline selection action buttons for the desktop action bar.
  Widget _buildDesktopSelectionActions(FileManagerProvider fileManager) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${fileManager.selectedFiles.length} 已选',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(LucideIcons.share2, size: 18, color: colorScheme.primary),
          onPressed: () {
            final selectedPath = fileManager.selectedFiles.first;
            final file = fileManager.files.firstWhere((f) => f.path == selectedPath);
            FileOperationDialogs.showShareDialog(context, file);
          },
          tooltip: '分享',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.download, size: 18, color: colorScheme.primary),
          onPressed: () => _downloadSelectedFiles(fileManager),
          tooltip: '下载',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.trash2, size: 18, color: colorScheme.error),
          onPressed: () => FileOperationDialogs.showDeleteConfirmation(
            context,
            fileManager,
            fileManager.selectedFiles,
          ),
          tooltip: '删除',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.error.withValues(alpha: 0.08),
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.x, size: 18, color: colorScheme.onSurface),
          onPressed: () => fileManager.clearSelection(),
          tooltip: '取消选择',
        ),
      ],
    );
  }

  /// Desktop category tab bar at root directory, with action buttons on the right.
  Widget _buildDesktopCategoryTabs(BuildContext context, ColorScheme colorScheme, FileManagerProvider fileManager) {
    final theme = Theme.of(context);
    final hasSelection = fileManager.hasSelection;

    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // Left: category tabs
          for (int i = 0; i < _desktopCategories.length; i++) ...[
            if (i == 6) // divider before navigation tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  height: 20,
                  child: VerticalDivider(width: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
                ),
              ),
            _buildDesktopCategoryTab(context, _desktopCategories[i], colorScheme),
          ],
          const Spacer(),
          // Right: action buttons (from top bar)
          if (hasSelection) ...[
            _buildDesktopSelectionActions(fileManager),
            const SizedBox(width: 4),
            const VerticalDivider(width: 1, indent: 14, endIndent: 14),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(LucideIcons.search, size: 20),
            onPressed: () => SearchDialog.show(context),
            tooltip: '搜索',
            visualDensity: VisualDensity.compact,
          ),
          if (!hasSelection) ...[
            IconButton(
              icon: Icon(fileManager.isLoading ? Icons.hourglass_empty : Icons.refresh, size: 20),
              onPressed: () => fileManager.refreshFiles(),
              tooltip: '刷新',
              visualDensity: VisualDensity.compact,
            ),
            _buildSortMenu(fileManager),
            Consumer<FileManagerProvider>(
              builder: (context, fm, _) {
                final icon = fm.viewType == FileViewType.list
                    ? Icons.grid_view
                    : Icons.view_list;
                return IconButton(
                  icon: Icon(icon, size: 20),
                  onPressed: () {
                    fm.setViewType(
                      fm.viewType == FileViewType.list
                          ? FileViewType.grid
                          : FileViewType.list,
                    );
                  },
                  tooltip: fm.viewType == FileViewType.list ? '网格视图' : '列表视图',
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.upload, size: 20),
              onPressed: () => showUploadDialog(context),
              tooltip: '上传',
              visualDensity: VisualDensity.compact,
            ),
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.folderPlus, size: 20),
              tooltip: '新建',
              padding: const EdgeInsets.all(8),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'folder') {
                  FileOperationDialogs.showCreateDialog(context, fileManager);
                } else if (value == 'file') {
                  _showCreateTextFileDialog(context, fileManager);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'folder', child: Row(children: [Icon(LucideIcons.folderPlus, size: 18), SizedBox(width: 10), Text('新建文件夹')])),
                const PopupMenuItem(value: 'file', child: Row(children: [Icon(Icons.note_add_outlined, size: 18), SizedBox(width: 10), Text('新建文件')])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCategoryTab(
    BuildContext context,
    _DesktopCategoryTab tab,
    ColorScheme colorScheme,
  ) {
    final isActive = _desktopCategoryIndex == tab.index && !tab.isNavigation;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _onDesktopCategoryTap(tab.index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? colorScheme.primary : theme.hintColor,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isActive ? 20 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 循环解码路径段，处理多重 URL 编码（如 %25E4%25B8%25AD -> 中文）
  String _decodePathSegment(String segment) {
    var decoded = segment;
    for (var i = 0; i < 5; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }
    return decoded;
  }

  Widget _buildMobileBreadcrumb(BuildContext context, FileManagerProvider fileManager) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pathParts = fileManager.currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);

    // 路径变化后自动滚动到末尾
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbController.hasClients) {
        _breadcrumbController.animateTo(
          _breadcrumbController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return SizedBox(
      height: 40,
      child: ListView(
        controller: _breadcrumbController,
        scrollDirection: Axis.horizontal,
        children: [
          _buildBreadcrumbChip(
            context,
            label: '文件',
            icon: LucideIcons.home,
            color: colorScheme.primary,
            onTap: () => fileManager.currentPath != '/' ? fileManager.enterFolder('/') : null,
          ),
          for (int i = 0; i < pathParts.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(LucideIcons.chevronRight, size: 14, color: theme.hintColor.withValues(alpha: 0.5)),
            ),
            _buildBreadcrumbChip(
              context,
              label: _decodePathSegment(pathParts[i]),
              icon: null,
              color: colorScheme.primary,
              isLast: i == pathParts.length - 1,
              onTap: () {
                final targetPath = '/${pathParts.sublist(0, i + 1).join('/')}';
                if (targetPath != fileManager.currentPath) fileManager.enterFolder(targetPath);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbChip(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required Color color,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isLast ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMobileActions() {
    return [
      Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return _buildSortMenu(fileManager);
        },
      ),
      Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          final icon = fileManager.viewType == FileViewType.list
              ? Icons.grid_view
              : Icons.view_list;
          return IconButton(
            icon: Icon(icon),
            onPressed: () {
              fileManager.setViewType(
                fileManager.viewType == FileViewType.list
                    ? FileViewType.grid
                    : FileViewType.list,
              );
            },
            tooltip: fileManager.viewType == FileViewType.list ? '网格视图' : '列表视图',
          );
        },
      ),
    ];
  }

  Widget _buildSortMenu(FileManagerProvider fileManager) {
    final allOptions = [
      for (final field in SortField.values)
        for (final dir in SortDirection.values) SortOption(field, dir),
    ];

    return PopupMenuButton<SortOption>(
      icon: const Icon(LucideIcons.arrowUpDown, size: 20),
      tooltip: '排序',
      position: PopupMenuPosition.under,
      padding: const EdgeInsets.all(8),
      onSelected: (option) => fileManager.setSortOption(option),
      itemBuilder: (context) => allOptions.map((option) {
        final isSelected = fileManager.sortOption == option;
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

  // ---- SpeedDial FAB ----

  Widget _buildSpeedDialFAB(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSlide(
      offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _isFabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildFabSubItem(
              context: context,
              index: 0,
              icon: LucideIcons.search,
              label: '搜索',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: () => _onFabSubAction(() => SearchDialog.show(context)),
            ),
            _buildFabSubItem(
              context: context,
              index: 1,
              icon: LucideIcons.upload,
              label: '上传',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: () => _onFabSubAction(() => showUploadDialog(context)),
            ),
            _buildFabSubItem(
              context: context,
              index: 2,
              icon: LucideIcons.folderPlus,
              label: '新建文件夹',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: () {
                final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
                _onFabSubAction(() => FileOperationDialogs.showCreateDialog(context, fileManager));
              },
            ),
            _buildFabSubItem(
              context: context,
              index: 3,
              icon: LucideIcons.download,
              label: '离线下载',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: () => _onFabSubAction(() => Navigator.of(context).pushNamed(RouteNames.remoteDownload)),
            ),
            Consumer<FileManagerProvider>(
              builder: (context, fileManager, _) {
                final isListView = fileManager.viewType == FileViewType.list;
                return _buildFabSubItem(
                  context: context,
                  index: 4,
                  icon: isListView ? LucideIcons.layoutGrid : LucideIcons.list,
                  label: isListView ? '网格视图' : '列表视图',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () {
                    _onFabSubAction(() {
                      fileManager.setViewType(
                        isListView ? FileViewType.grid : FileViewType.list,
                      );
                    });
                  },
                );
              },
            ),

            // 主按钮：与子按钮同风格同尺寸
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: AnimatedScale(
                scale: _isFabExpanded ? 1.0 : 1.08,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _buildFabButton(
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: _toggleFabExpanded,
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      LucideIcons.plus,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabSubItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final staggerDelay = Duration(milliseconds: 50 * index);

    return AnimatedSlide(
      offset: _isFabExpanded ? Offset.zero : const Offset(0, 1.2),
      duration: const Duration(milliseconds: 250) + staggerDelay,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isFabExpanded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200) + staggerDelay,
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _isFabExpanded ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 250) + staggerDelay,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFabButton(
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: onTap,
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 统一的毛玻璃圆形按钮
  Widget _buildFabButton({
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required Widget child,
  }) {
    const size = 44.0;
    const radius = 22.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Body ----

  Widget _buildBody(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final fileManager = Provider.of<FileManagerProvider>(context);
    final child = _buildFileList(context);

    if (!isDesktop || !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return child;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        _handleDroppedFiles(details.files);
      },
      child: Stack(
        children: [
          child,
          if (_isDraggingOver)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.upload, size: 28, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '释放文件以上传到当前目录',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileManager.currentPath,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleDroppedFiles(List<XFile> droppedFiles) {
    final files = <File>[];
    for (final xFile in droppedFiles) {
      final path = xFile.path;
      if (path.isNotEmpty) {
        files.add(File(path));
      }
    }
    if (files.isEmpty) return;

    final uploadManager = Provider.of<UploadManagerProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    uploadManager.markShouldShowDialog();
    uploadManager.startUpload(files, fileManager.currentPath);
    ToastHelper.info('已添加 ${files.length} 个文件到上传队列');
  }

  Widget _buildFileList(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        if (fileManager.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (fileManager.errorMessage != null) {
          return _buildErrorView(context, fileManager);
        }

        if (fileManager.files.isEmpty) {
          return EmptyFolderView(currentPath: fileManager.currentPath);
        }

        // Summary panel 已移至 AppBar 中，body 只显示文件列表
        if (fileManager.viewType == FileViewType.list) {
          return _buildListView(context, fileManager);
        }

        return _buildGridView(context, fileManager);
      },
    );
  }

  // ---- Desktop Home Summary Panel ----

  Widget _buildDesktopSummaryPanel(BuildContext context, FileManagerProvider fileManager) {
    final theme = Theme.of(context);

    final recentFiles = List<FileModel>.from(fileManager.files)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final displayFiles = recentFiles.take(20).toList();
    final transferFiles = fileManager.transferredFiles.take(20).toList();

    final dividerColor = theme.dividerColor.withValues(alpha: 0.28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1180;
          final gap = compact ? 16.0 : 24.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：最近文件
              Expanded(
                flex: compact ? 5 : 7,
                child: _buildSummarySection(
                  context,
                  title: '最近文件',
                  files: displayFiles,
                  onMore: fileManager.activeCategory == null
                      ? () {
                          setState(() => _desktopCategoryIndex = 1);
                          fileManager.setActiveCategory('recent');
                        }
                      : null,
                ),
              ),
              SizedBox(width: gap),
              Container(
                width: 1,
                height: 118,
                margin: const EdgeInsets.only(top: 34),
                color: dividerColor,
              ),
              SizedBox(width: gap),
              // 右侧：转存文件
              Expanded(
                flex: compact ? 4 : 3,
                child: _buildSummarySection(
                  context,
                  title: '转存文件',
                  files: transferFiles,
                  onMore: () => Navigator.of(context).pushNamed(RouteNames.transferredFiles),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context, {
    required String title,
    required List<FileModel> files,
    VoidCallback? onMore,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (onMore != null)
              TextButton.icon(
                onPressed: onMore,
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('查看更多'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          SizedBox(
            height: 110,
            child: Center(
              child: Text('暂无文件', style: TextStyle(color: theme.hintColor)),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: _HorizontalScrollListView(
              itemCount: files.length,
              itemBuilder: (context, index) {
                return _buildRecentFileCard(context, files[index], colorScheme);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentFileCard(BuildContext context, FileModel file, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final isThumbnailable = !file.isFolder && FileUtils.isThumbnailableFile(file.name);

    return Tooltip(
      message: '${file.name}\n'
          '${app_date_utils.DateUtils.formatFileSize(file.size)}  |  '
          '${app_date_utils.DateUtils.formatDateTime(file.updatedAt)}',
      preferBelow: true,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            if (file.isFolder) {
              Provider.of<FileManagerProvider>(context, listen: false).enterFolder(file.relativePath);
            } else {
              _openFile(context, file);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail / icon
                Expanded(
                  child: isThumbnailable
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ThumbnailImage(
                            file: file,
                            contextHint: Provider.of<FileManagerProvider>(context, listen: false).contextHint,
                            borderRadius: 8,
                          ),
                        )
                      : Center(
                          child: Icon(
                            file.isFolder ? LucideIcons.folder : LucideIcons.file,
                            size: 32,
                            color: colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                // File name
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, FileManagerProvider fileManager) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(
            fileManager.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => fileManager.loadFiles(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh(FileManagerProvider fileManager) async {
    final result = await fileManager.refreshFiles();
    if (!mounted) return;
    if (fileManager.errorMessage != null) {
      ToastHelper.error(fileManager.errorMessage!);
      return;
    }
    if (result.isUnchanged) {
      ToastHelper.info('列表已是最新');
    } else {
      final parts = <String>[];
      if (result.added > 0) parts.add('新增 ${result.added} 项');
      if (result.removed > 0) parts.add('移除 ${result.removed} 项');
      if (result.updated > 0) parts.add('更新 ${result.updated} 项');
      ToastHelper.success('已刷新：${parts.join('，')}');
    }
  }

  Widget _buildListView(BuildContext context, FileManagerProvider fileManager) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final showCheckbox = fileManager.hasSelection;
    final itemCount = fileManager.files.length + (fileManager.hasMore || fileManager.isLoadingMore ? 1 : 0);

    // 高亮文件时滚动到对应位置
    if (fileManager.highlightPath != null) {
      final idx = fileManager.files.indexWhere((f) => f.path == fileManager.highlightPath);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            const itemHeight = 52.0;
            final offset = (idx * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
          }
        });
      }
    }

    return Column(
      children: [
        if (isDesktop) FileListHeader(
          showCheckbox: showCheckbox,
          currentSort: fileManager.sortOption,
          onSort: (option) => fileManager.setSortOption(option),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _onRefresh(fileManager),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                key: PageStorageKey('files_list_${fileManager.currentPath}'),
                cacheExtent: 900,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index >= fileManager.files.length) {
                    return _buildLoadMoreIndicator(context, fileManager);
                  }
                  final file = fileManager.files[index];
                  final isSelected = fileManager.selectedFiles.contains(file.path);

                  return FileListItem(
                    key: ValueKey('file_${file.id}'),
                    file: file,
                    isSelected: isSelected,
                    isHighlighted: file.path == fileManager.highlightPath,
                    showCheckbox: showCheckbox,
                    index: index,
                    isDesktop: isDesktop,
                    onTap: () {
                      _hideFab();
                      _scheduleShowFab();
                      if (showCheckbox) {
                        fileManager.toggleSelection(file.path);
                      } else if (file.isFolder) {
                        fileManager.enterFolder(file.relativePath);
                      } else {
                        _openFile(context, file);
                      }
                    },
                    onSelect: () => fileManager.toggleSelection(file.path),
                    onDownload: !file.isFolder ? () => _downloadFile(context, fileManager, file) : null,
                    onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
                    onOpenInCloudreveApp: !file.isFolder ? () => _openInCloudreveApp(context, file) : null,
                    onRename: () => FileOperationDialogs.showRenameDialog(context, fileManager, file),
                    onMove: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, false),
                    onCopy: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, true),
                    onShare: () => FileOperationDialogs.showShareDialog(context, file),
                    onDelete: () => FileOperationDialogs.showDeleteSingleConfirmation(context, fileManager, file),
                    onInfo: () => _showFileInfo(file),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(BuildContext context, FileManagerProvider fileManager) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final padding = 16.0;
    final spacing = 16.0;
    final availableWidth = screenWidth - padding * 2;

    int crossAxisCount;
    if (screenWidth < 400) {
      crossAxisCount = 2;
    } else if (screenWidth < 600) {
      crossAxisCount = 3;
    } else if (screenWidth < 900) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    final itemWidth = (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final childAspectRatio = itemWidth / 160;
    final showCheckbox = fileManager.hasSelection;
    final itemCount = fileManager.files.length + (fileManager.hasMore || fileManager.isLoadingMore ? 1 : 0);

    // 高亮文件时滚动到对应位置
    if (fileManager.highlightPath != null) {
      final idx = fileManager.files.indexWhere((f) => f.path == fileManager.highlightPath);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final row = idx ~/ crossAxisCount;
            final itemHeight = itemWidth / childAspectRatio + spacing / 2;
            final offset = (row * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
          }
        });
      }
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(fileManager),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: GridView.builder(
          controller: _scrollController,
          key: PageStorageKey('files_grid_${fileManager.currentPath}'),
          cacheExtent: 1100,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing / 2,
            crossAxisSpacing: spacing / 2,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= fileManager.files.length) {
              return _buildGridLoadMoreIndicator(context, fileManager);
            }
            final file = fileManager.files[index];
            final isSelected = fileManager.selectedFiles.contains(file.path);

            return FileGridItem(
              key: ValueKey('file_grid_${file.id}'),
              file: file,
              isSelected: isSelected,
              isHighlighted: file.path == fileManager.highlightPath,
              showCheckbox: showCheckbox,
              contextHint: fileManager.contextHint,
              onTap: () {
                _hideFab();
                _scheduleShowFab();
                if (showCheckbox) {
                  fileManager.toggleSelection(file.path);
                } else if (file.isFolder) {
                  fileManager.enterFolder(file.relativePath);
                } else {
                  _openFile(context, file);
                }
              },
              onSelect: () => fileManager.toggleSelection(file.path),
              onDownload: !file.isFolder ? () => _downloadFile(context, fileManager, file) : null,
              onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
              onOpenInCloudreveApp: !file.isFolder ? () => _openInCloudreveApp(context, file) : null,
              onRename: () => FileOperationDialogs.showRenameDialog(context, fileManager, file),
              onMove: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, false),
              onCopy: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, true),
              onShare: () => FileOperationDialogs.showShareDialog(context, file),
              onDelete: () => FileOperationDialogs.showDeleteSingleConfirmation(context, fileManager, file),
              onInfo: () => _showFileInfo(file),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(BuildContext context, FileManagerProvider fileManager) {
    if (fileManager.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => fileManager.loadMoreFiles(),
          icon: const Icon(LucideIcons.chevronsDown, size: 16),
          label: const Text('加载更多'),
        ),
      ),
    );
  }

  Widget _buildGridLoadMoreIndicator(BuildContext context, FileManagerProvider fileManager) {
    if (fileManager.isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: OutlinedButton.icon(
          onPressed: () => fileManager.loadMoreFiles(),
          icon: const Icon(LucideIcons.chevronsDown, size: 16),
          label: const Text('加载更多'),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        if (fileManager.hasSelection) {
          return SelectionToolbar(
            selectionCount: fileManager.selectedFiles.length,
            totalCount: fileManager.files.length,
            onCancel: () => fileManager.clearSelection(),
            onSelectAll: () => fileManager.selectAll(),
            onMore: fileManager.selectedFiles.length == 1
                ? () => _showSelectionMore(
                      fileManager.files.firstWhere(
                        (f) => f.path == fileManager.selectedFiles.first,
                      ),
                      fileManager,
                    )
                : null,
            onMove: () => FileOperationDialogs.showBatchMoveDialog(
                  context,
                  fileManager,
                  fileManager.selectedFiles,
                  false,
                ),
            onCopy: () => FileOperationDialogs.showBatchMoveDialog(
                  context,
                  fileManager,
                  fileManager.selectedFiles,
                  true,
                ),
            onDelete: () => FileOperationDialogs.showDeleteConfirmation(
                  context,
                  fileManager,
                  fileManager.selectedFiles,
                ),
          );
        }

        if (!isDesktop) return const SizedBox.shrink();

        return FileBreadcrumb(
          currentPath: fileManager.currentPath,
          onPathTap: (path) => fileManager.enterFolder(path),
        );
      },
    );
  }

  void _openFile(BuildContext context, FileModel file) {
    if (FileTypeUtils.isImage(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.imagePreview, arguments: file);
    } else if (FileTypeUtils.isPdf(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.pdfPreview, arguments: file);
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

  // ---- Download handling ----

  Future<void> _downloadFile(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    if (isDesktop && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await _showDesktopDownloadDialog(fileManager, [file]);
    } else {
      final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);
      final task = await downloadManager.addDownloadTask(
        fileName: file.name,
        fileUri: file.relativePath,
        fileSize: file.size,
      );

      if (task != null) {
        if (context.mounted) {
          ToastHelper.info('文件已在下载列表中');
        }
        return;
      }

      if (context.mounted) {
        ToastHelper.info('开始下载，查看任务页');
      }
    }
  }

  /// Download all currently selected files (desktop action bar).
  Future<void> _downloadSelectedFiles(FileManagerProvider fileManager) async {
    final selectedPaths = fileManager.selectedFiles;
    if (selectedPaths.isEmpty) return;
    final files = fileManager.files.where((f) => selectedPaths.contains(f.path)).toList();
    await _showDesktopDownloadDialog(fileManager, files);
  }

  /// Desktop download target dialog.
  Future<void> _showDesktopDownloadDialog(
    FileManagerProvider fileManager,
    List<FileModel> files,
  ) async {
    final shouldArchive = files.length > 1 || files.any((f) => f.isFolder);
    final theme = Theme.of(context);

    String? selectedDirectory;
    bool setAsDefault = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(shouldArchive ? '下载为压缩包' : '下载文件'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shouldArchive) ...[
                      Text(
                        '已选择 ${files.length} 项，将打包为 ZIP 压缩包下载。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Text(
                        files.first.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app_date_utils.DateUtils.formatFileSize(files.first.size)}  |  '
                        '${app_date_utils.DateUtils.formatDateTime(files.first.updatedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Directory picker
                    OutlinedButton.icon(
                      onPressed: () async {
                        final dir = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: '选择下载目录',
                        );
                        if (dir != null) {
                          setDialogState(() => selectedDirectory = dir);
                        }
                      },
                      icon: Icon(
                        selectedDirectory != null
                            ? LucideIcons.folderCheck
                            : LucideIcons.folderOpen,
                        size: 18,
                      ),
                      label: Text(
                        selectedDirectory != null
                            ? selectedDirectory!
                            : '选择保存目录',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Set as default checkbox
                    CheckboxListTile(
                      value: setAsDefault,
                      onChanged: (v) => setDialogState(() => setAsDefault = v ?? false),
                      title: const Text('设为默认路径'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('下载'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    // If "set as default" is checked, save the directory
    if (setAsDefault && selectedDirectory != null) {
      // Store for future use (implementation depends on StorageService)
    }

    final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);

    if (shouldArchive) {
      // Download as archive
      try {
        final uris = files.map((f) => f.path).toList();
        final response = await FileService().getDownloadUrls(
          uris: uris,
          download: true,
          archive: true,
          contextHint: fileManager.contextHint,
        );

        final url = _extractFirstDownloadUrl(response);
        if (url == null || url.isEmpty) {
          if (mounted) ToastHelper.error('服务端没有返回下载链接');
          return;
        }

        final archiveName = _archiveNameFor(files);
        final archiveUri = files.length == 1
            ? files.first.path
            : 'archive:${DateTime.now().millisecondsSinceEpoch}:${uris.join('|')}';

        final task = await downloadManager.addDownloadTask(
          fileName: archiveName,
          fileUri: archiveUri,
          fileSize: 0,
        );
        if (!mounted) return;
        if (task != null) {
          ToastHelper.info('下载任务已存在');
        } else {
          ToastHelper.success('已添加压缩包下载任务');
        }
      } catch (e) {
        if (mounted) ToastHelper.failure('添加下载任务失败: $e');
      }
    } else {
      // Single file download
      final file = files.first;
      final task = await downloadManager.addDownloadTask(
        fileName: file.name,
        fileUri: file.relativePath,
        fileSize: file.size,
      );
      if (!mounted) return;
      if (task != null) {
        ToastHelper.info('文件已在下载列表中');
      } else {
        ToastHelper.info('开始下载，查看任务页');
      }
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

  String _archiveNameFor(List<FileModel> files) {
    if (files.length == 1) {
      final name = files.first.name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
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
    return '下载文件_$stamp.zip';
  }

  Future<void> _openInBrowser(BuildContext context, FileModel file) async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [file.relativePath],
        download: true,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isNotEmpty) {
        final urlData = urls[0] as Map<String, dynamic>;
        final url = urlData['url'] as String;

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          if (context.mounted) {
            ToastHelper.error('无法打开链接: $uri');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.failure('获取下载链接失败: $e');
      }
    }
  }

  void _openInCloudreveApp(BuildContext context, FileModel file) {
    Navigator.of(context).pushNamed(
      RouteNames.cloudreveFileApp,
      arguments: {
        'file': file,
      },
    );
  }

  /// Build the desktop AppBar content (called from [_DesktopAppBarWrapper]).
  Widget _buildDesktopTopBar(BuildContext context, FileManagerProvider fileManager) {
    final theme = Theme.of(context);
    final isAtRoot = fileManager.currentPath == '/';
    final hasSelection = fileManager.hasSelection;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          if (!isAtRoot)
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
              onPressed: () => fileManager.goBack(),
              tooltip: '返回上一级',
              visualDensity: VisualDensity.compact,
            ),
          Text(
            isAtRoot ? '文件' : _decodePathSegment(
              fileManager.currentPath.split('/').where((s) => s.isNotEmpty).last,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (hasSelection) ...[
            _buildDesktopSelectionActions(fileManager),
            const SizedBox(width: 4),
            const VerticalDivider(width: 1, indent: 14, endIndent: 14),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(LucideIcons.search, size: 20),
            onPressed: () => SearchDialog.show(context),
            tooltip: '搜索',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(fileManager.isLoading ? Icons.hourglass_empty : Icons.refresh, size: 20),
            onPressed: () => fileManager.refreshFiles(),
            tooltip: '刷新',
            visualDensity: VisualDensity.compact,
          ),
          _buildSortMenu(fileManager),
          Consumer<FileManagerProvider>(
            builder: (context, fm, _) {
              final icon = fm.viewType == FileViewType.list
                  ? Icons.grid_view
                  : Icons.view_list;
              return IconButton(
                icon: Icon(icon, size: 20),
                onPressed: () {
                  fm.setViewType(
                    fm.viewType == FileViewType.list
                        ? FileViewType.grid
                        : FileViewType.list,
                  );
                },
                tooltip: fm.viewType == FileViewType.list ? '网格视图' : '列表视图',
                visualDensity: VisualDensity.compact,
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.upload, size: 20),
            onPressed: () => showUploadDialog(context),
            tooltip: '上传',
            visualDensity: VisualDensity.compact,
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.folderPlus, size: 20),
            tooltip: '新建',
            padding: const EdgeInsets.all(8),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'folder') {
                FileOperationDialogs.showCreateDialog(context, fileManager);
              } else if (value == 'file') {
                _showCreateTextFileDialog(context, fileManager);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'folder', child: Row(children: [Icon(LucideIcons.folderPlus, size: 18), SizedBox(width: 10), Text('新建文件夹')])),
              const PopupMenuItem(value: 'file', child: Row(children: [Icon(Icons.note_add_outlined, size: 18), SizedBox(width: 10), Text('新建文件')])),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateTextFileDialog(BuildContext context, FileManagerProvider fileManager) async {
    final controller = TextEditingController(text: '新建文件.txt');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件名',
            prefixIcon: Icon(Icons.note_add_outlined),
          ),
          onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    if (confirmed != true || name.isEmpty) return;

    try {
      final base = fileManager.currentPath == '/' || fileManager.currentPath.isEmpty ? '' : fileManager.currentPath;
      final uri = base.isEmpty ? '/$name' : base.endsWith('/') ? '$base$name' : '$base/$name';
      await FileService().createFile(uri: uri, type: 'file', errOnConflict: true);
      await fileManager.loadFiles(refresh: true);
      if (context.mounted) ToastHelper.success('文件创建成功');
    } catch (e) {
      if (context.mounted) ToastHelper.failure('创建文件失败: $e');
    }
  }

  Widget _buildDesktopFileList(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, _) {
        if (fileManager.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (fileManager.errorMessage != null) {
          return _buildErrorView(context, fileManager);
        }
        if (fileManager.files.isEmpty) {
          return EmptyFolderView(currentPath: fileManager.currentPath);
        }
        return fileManager.viewType == FileViewType.list
            ? _buildListView(context, fileManager)
            : _buildGridView(context, fileManager);
      },
    );
  }
}

/// 水平 ListView，桌面端响应鼠标滚轮横向滚动。
class _HorizontalScrollListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _HorizontalScrollListView({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_HorizontalScrollListView> createState() => _HorizontalScrollListViewState();
}

class _HorizontalScrollListViewState extends State<_HorizontalScrollListView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _controller.hasClients) {
          final maxExt = _controller.position.maxScrollExtent;
          if (maxExt > 0) {
            _controller.jumpTo(
              (_controller.offset + event.scrollDelta.dy).clamp(0.0, maxExt),
            );
          }
        }
      },
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}
