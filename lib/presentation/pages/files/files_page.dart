import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/download_service.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:cloudreve4_flutter/services/storage_service.dart';
import 'package:cloudreve4_flutter/services/upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/constants/sort_options.dart';
import '../../../core/constants/storage_keys.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/download_manager_provider.dart';
import '../../../data/models/download_task_model.dart';
import '../../providers/upload_manager_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/file_list_header.dart';
import '../../widgets/file_breadcrumb.dart';
import '../../widgets/empty_folder_view.dart';
import '../../widgets/upload_dialog.dart';
import '../../widgets/file_operation_dialogs.dart';
import '../../widgets/file_info_dialog.dart';
import '../../widgets/search_dialog.dart';
import '../../widgets/toast_helper.dart';
import '../../../router/app_router.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import 'widgets/file_drop_target.dart';
import 'widgets/speed_dial_fab.dart';
import 'widgets/desktop_summary_panel.dart';
import 'widgets/desktop_action_buttons.dart';

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
  _DesktopCategoryTab(6, '转存', 'transferred'),
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
  final GlobalKey<SpeedDialFabState> _fabKey = GlobalKey<SpeedDialFabState>();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _breadcrumbController = ScrollController();

  // 滑动手势追踪
  Offset? _swipeStartPos;
  DateTime? _swipeStartTime;

  // 桌面端分类 Tab 索引
  int _desktopCategoryIndex = 0;

  // 桌面端首页概览折叠状态
  bool _isSummaryCollapsed = false;

  // 桌面端首页概览区：进入子目录/分类后默认收起；只通过滚轮在顶部拉回，不再显示鼠标悬停锚点。
  String? _lastListAutoScrollHighlightPath;
  String? _lastGridAutoScrollHighlightPath;

  // 文件夹精准拖拽上传：子文件夹 DropTarget 命中时，抑制外层当前目录 DropTarget。
  int _explicitFolderDropSerial = 0;

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
    final shouldCollapse = pixels > 96;
    if (shouldCollapse != _isSummaryCollapsed) {
      setState(() => _isSummaryCollapsed = shouldCollapse);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;

    final nearTop = _scrollController.position.pixels <= 8;
    // 只在文件列表区域监听滚轮。顶部最近/转存模块有横向滚动，不能用它触发展开/收起。
    // 在列表顶部继续向上滚动时，才把最近/转存模块拉下来。
    if (_isSummaryCollapsed && nearTop && event.scrollDelta.dy < 0) {
      setState(() => _isSummaryCollapsed = false);
      return;
    }

    // 在文件列表区域向下浏览时收起顶部概览区。
    if (!_isSummaryCollapsed && event.scrollDelta.dy > 0) {
      setState(() => _isSummaryCollapsed = true);
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

  void _showSelectionMoreMenu({
    required FileManagerProvider fileManager,
    required List<FileModel> selectedFiles,
    FileModel? anchorFile,
  }) {
    final hasFolder = selectedFiles.any((file) => file.isFolder);
    final singleFile = selectedFiles.length == 1 ? (anchorFile ?? selectedFiles.first) : null;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (singleFile != null) ...[
              if (!singleFile.isFolder) ...[
                ListTile(
                  leading: const Icon(Icons.open_in_browser),
                  title: const Text('在浏览器中打开'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openInBrowser(context, singleFile);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.web_asset),
                  title: const Text('在 Cloudreve 中打开'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openInCloudreveApp(context, singleFile);
                  },
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  FileOperationDialogs.showRenameDialog(context, fileManager, singleFile);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('查看详情'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showFileInfo(singleFile);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('移动'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                FileOperationDialogs.showBatchMoveDialog(
                  context,
                  fileManager,
                  selectedFiles.map((file) => file.path).toList(),
                  false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                FileOperationDialogs.showBatchMoveDialog(
                  context,
                  fileManager,
                  selectedFiles.map((file) => file.path).toList(),
                  true,
                );
              },
            ),
            if (hasFolder)
              ListTile(
                leading: const Icon(Icons.drive_folder_upload_outlined),
                title: const Text('导出目录'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _exportSelectedDirectories(fileManager, selectedFiles);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消选择'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                fileManager.clearSelection();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- Desktop category tab handling ----

  void _onDesktopCategoryTap(int index) {
    final tab = _desktopCategories[index];
    if (tab.isNavigation) {
      _handleNavigationTab(tab.key);
      return;
    }

    final shouldShowSummary = tab.key == null;

    setState(() {
      _desktopCategoryIndex = index;
      // “全部”是首页视图，必须直接展开最近文件/转存文件模块；
      // 其它分类仍默认收起，等用户在列表顶部向上滚轮时再拉出。
      _isSummaryCollapsed = !shouldShowSummary;
    });

    if (_scrollController.hasClients) {
      if (shouldShowSummary) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(0);
      }
    }

    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    fileManager.setActiveCategory(tab.key);
  }

  void _handleNavigationTab(String? key) {
    switch (key) {
      case 'shares':
        Navigator.of(context).pushNamed(RouteNames.share);
        break;
      case 'recycle':
        Navigator.of(context).pushNamed(RouteNames.recycleBin);
        break;
    }
  }

  void _enterFolderFromCurrentContext(
    FileManagerProvider fileManager,
    FileModel file,
  ) {
    final path = fileManager.activeCategory == 'transferred'
        ? file.path
        : file.relativePath;
    setState(() => _isSummaryCollapsed = true);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    fileManager.enterFolder(path);
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
        floatingActionButton: isDesktop ? null : _buildSpeedDialFAB(),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          if (fileManager.hasSelection) {
            return AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                tooltip: '取消选择',
                onPressed: () => fileManager.clearSelection(),
              ),
              centerTitle: true,
              title: Text('已选中 ${fileManager.selectedFiles.length} 个文件'),
              actions: [
                TextButton(
                  onPressed: () => fileManager.selectAll(),
                  child: const Text('全选'),
                ),
              ],
            );
          }

          return AppBar(
            title: _buildMobileBreadcrumb(context, fileManager),
            actions: _buildMobileActions(),
          );
        },
      ),
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
        // 顶部概览区：进入子目录/分类时收起，不再生成独立大页面；通过滚轮回到顶部时再展开。
        _buildDesktopSummaryAnchor(context, fileManager),
        // 分类栏始终留在同一页面顶部，子目录只刷新下面的文件列表。
        _buildDesktopCategoryTabs(context, Theme.of(context).colorScheme, fileManager),
        // 上传 / 新建文件夹 / 新建文件 + 右侧工具栏始终固定在第二行。
        _buildDesktopRootMutationRow(context, fileManager),
        // 文件列表
        Expanded(child: _buildDesktopFileList(context)),
      ],
    );

    return FileDropTarget(
      currentPath: fileManager.currentPath,
      onDragDone: _handleDroppedFiles,
      child: column,
    );
  }

  Widget _buildDesktopSummaryAnchor(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    final showSummary = !_isSummaryCollapsed;

    return AnimatedSize(
      duration: const Duration(milliseconds: 620),
      reverseDuration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: showSummary
          ? AnimatedOpacity(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeInOutCubic,
              opacity: 1,
              child: DesktopSummaryPanel(
                onRecentMore: fileManager.activeCategory == null
                    ? () {
                        setState(() {
                          _desktopCategoryIndex = 1;
                          _isSummaryCollapsed = true;
                        });
                        fileManager.setActiveCategory('recent');
                      }
                    : null,
                onTransferredMore: () {
                  setState(() {
                    _desktopCategoryIndex = 6;
                    _isSummaryCollapsed = true;
                  });
                  fileManager.setActiveCategory('transferred');
                },
                onOpenFile: (file) => _openFile(context, file),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Inline selection action buttons for the desktop category action bar.
  ///
  /// Compact Windows-style capsule. The cancel X stays outside the capsule so it
  /// does not replace the old cancel-selection affordance.
  Widget _buildDesktopSelectionActions(FileManagerProvider fileManager) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selectedFiles = fileManager.files
        .where((file) => fileManager.selectedFiles.contains(file.path))
        .toList();
    final selectionCount = selectedFiles.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已选择 ',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            _RollingSelectionCount(
              value: selectionCount,
              color: colorScheme.primary,
            ),
            Text(
              ' 项',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Container(
          height: 26,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDesktopSelectionTextButton(
                icon: LucideIcons.share2,
                label: '分享',
                tooltip: selectionCount == 1 ? '分享' : '只能分享单个文件',
                onPressed: selectionCount == 1
                    ? () => FileOperationDialogs.showShareDialog(
                          context,
                          selectedFiles.first,
                        )
                    : null,
              ),
              _buildDesktopSelectionDivider(),
              _buildDesktopSelectionTextButton(
                icon: LucideIcons.download,
                label: _buildSelectionDownloadLabel(selectedFiles),
                tooltip: '下载选中项',
                onPressed: selectionCount > 0
                    ? () => _downloadSelectedFiles(fileManager)
                    : null,
              ),
              _buildDesktopSelectionDivider(),
              _buildDesktopSelectionTextButton(
                icon: LucideIcons.trash2,
                label: '删除',
                tooltip: '删除选中项',
                foregroundColor: colorScheme.error,
                hoverColor: colorScheme.error.withValues(alpha: 0.08),
                onPressed: selectionCount > 0
                    ? () => FileOperationDialogs.showDeleteConfirmation(
                          context,
                          fileManager,
                          fileManager.selectedFiles,
                        )
                    : null,
              ),
              _buildDesktopSelectionDivider(),
              _buildDesktopSelectionMoreButton(
                fileManager,
                selectedFiles,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Tooltip(
          message: '取消选择',
          waitDuration: const Duration(milliseconds: 450),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: fileManager.clearSelection,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                LucideIcons.x,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSelectionTextButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? foregroundColor,
    Color? hoverColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final effectiveColor = enabled
        ? (foregroundColor ?? colorScheme.onSurfaceVariant)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: InkWell(
        onTap: onPressed,
        hoverColor: hoverColor ?? colorScheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: effectiveColor),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSelectionMoreButton(
    FileManagerProvider fileManager,
    List<FileModel> selectedFiles,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: '更多',
      waitDuration: const Duration(milliseconds: 450),
      child: InkWell(
        onTap: selectedFiles.isEmpty
            ? null
            : () => _showSelectionMoreMenu(
                  fileManager: fileManager,
                  selectedFiles: selectedFiles,
                  anchorFile: selectedFiles.length == 1 ? selectedFiles.first : null,
                ),
        hoverColor: colorScheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.more_horiz,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSelectionDivider() {
    return Builder(
      builder: (context) => SizedBox(
        height: 18,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  String _buildSelectionDownloadLabel(List<FileModel> selectedFiles) {
    if (selectedFiles.isEmpty) return '下载';

    final regularFiles = selectedFiles.where((file) => !file.isFolder).toList();
    if (regularFiles.isEmpty) {
      return '下载(${selectedFiles.length}项)';
    }

    final totalSize = regularFiles.fold<int>(
      0,
      (sum, file) => sum + (file.size < 0 ? 0 : file.size),
    );
    return '下载(${_formatCompactFileSize(totalSize)})';
  }

  String _formatCompactFileSize(int bytes) {
    if (bytes <= 0) return '0B';

    const units = ['B', 'K', 'M', 'G', 'T'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    final fixed = unitIndex == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    final compact = fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
    return '$compact${units[unitIndex]}';
  }


  /// Desktop action row below category tabs and above table header.
  ///
  /// Left side is always upload / create folder / create file. Right side is
  /// search / sort / view / refresh when there is no selection, and is replaced
  /// by selected count / share / download / delete / more / cancel when files
  /// are selected.
  Widget _buildDesktopRootMutationRow(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.fromLTRB(22, 1, 16, 2),
      alignment: Alignment.center,
      child: Row(
        children: [
          _buildDesktopRootMutationButtons(context, fileManager),
          const Spacer(),
          _buildDesktopRightToolbar(context, fileManager),
        ],
      ),
    );
  }

  Widget _buildDesktopRootMutationButtons(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDesktopInlineActionButton(
          context,
          icon: LucideIcons.upload,
          label: '上传',
          filled: true,
          onPressed: () => showUploadDialog(context),
        ),
        const SizedBox(width: 6),
        _buildDesktopInlineActionButton(
          context,
          icon: LucideIcons.folderPlus,
          label: '新建文件夹',
          color: colorScheme.primary,
          onPressed: () => FileOperationDialogs.showCreateDialog(context, fileManager),
        ),
        const SizedBox(width: 6),
        _buildDesktopInlineActionButton(
          context,
          icon: Icons.note_add_outlined,
          label: '新建文件',
          color: colorScheme.primary,
          onPressed: () => _showCreateTextFileDialog(context, fileManager),
        ),
      ],
    );
  }

  Widget _buildDesktopInlineActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool filled = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = color ?? colorScheme.primary;
    final foreground = filled ? colorScheme.onPrimary : baseColor;
    final background = filled ? baseColor : baseColor.withValues(alpha: 0.08);

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16.5, color: foreground),
      label: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDesktopRightToolbar(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        reverseDuration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              ...previousChildren,
              ...?(currentChild == null ? null : <Widget>[currentChild]),
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isSelection = child.key == const ValueKey('desktop-selection-actions');
          final beginOffset = isSelection
              ? const Offset(-0.16, 0)
              : const Offset(0.16, 0);
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return SizeTransition(
            axis: Axis.horizontal,
            axisAlignment: 1.0,
            sizeFactor: curved,
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: beginOffset,
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            ),
          );
        },
        child: fileManager.hasSelection
            ? KeyedSubtree(
                key: const ValueKey('desktop-selection-actions'),
                child: _buildDesktopSelectionActions(fileManager),
              )
            : KeyedSubtree(
                key: const ValueKey('desktop-default-actions'),
                child: DesktopActionButtons(
                  fileManager: fileManager,
                  hasSelection: false,
                  showFileMutations: false,
                  onShowCreateTextFile: () => _showCreateTextFileDialog(context, fileManager),
                ),
              ),
      ),
    );
  }


  /// Compatibility slot used by the legacy desktop AppBar wrapper.
  ///
  /// The active desktop file page now uses [_buildDesktopRightToolbar] for the
  /// right side of the second toolbar row. Some older desktop app-bar code still
  /// calls this method, so keep it as a thin wrapper to avoid analyzer/build
  /// failures while preserving the same animated selection/default toolbar logic.
  Widget _buildDesktopAnimatedSelectionSlot(FileManagerProvider fileManager) {
    return _buildDesktopRightToolbar(context, fileManager);
  }


  /// Desktop category tab bar at root directory.
  ///
  /// This top row contains only category tabs. The right side intentionally
  /// stays empty; all file actions live in the second toolbar row.
  Widget _buildDesktopCategoryTabs(BuildContext context, ColorScheme colorScheme, FileManagerProvider fileManager) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 16, right: 16),
      decoration: const BoxDecoration(),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (int i = 0; i < _desktopCategories.length; i++) ...[
                if (i == 7)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      height: 20,
                      child: VerticalDivider(width: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
                    ),
                  ),
                _buildDesktopCategoryTab(context, _desktopCategories[i], colorScheme),
              ],
            ],
          ),
        ),
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
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
            const SizedBox(height: 3),
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
              Icon(icon, size: 13, color: color),
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

  Widget _buildSpeedDialFAB() {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, _) {
        // 手机端进入多选后隐藏悬浮加号，避免遮挡底部多选工具栏和勾选操作。
        if (fileManager.hasSelection) return const SizedBox.shrink();

        return SpeedDialFab(
          key: _fabKey,
          isListView: fileManager.viewType == FileViewType.list,
          onSearch: () => SearchDialog.show(context),
          onUpload: () => showUploadDialog(context),
          onCreateFolder: () => FileOperationDialogs.showCreateDialog(context, fileManager),
          onRemoteDownload: () => Navigator.of(context).pushNamed(RouteNames.remoteDownload),
          onToggleViewType: () {
            fileManager.setViewType(
              fileManager.viewType == FileViewType.list ? FileViewType.grid : FileViewType.list,
            );
          },
        );
      },
    );
  }

  // ---- Body ----

  Widget _buildBody(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(context);
    final child = _buildFileList(context);

    return FileDropTarget(
      currentPath: fileManager.currentPath,
      onDragDone: _handleDroppedFiles,
      child: child,
    );
  }

  void _handleDroppedFiles(List<XFile> droppedFiles) {
    final serialAtDrop = _explicitFolderDropSerial;

    // Nested folder DropTarget and the page DropTarget can both receive the same
    // desktop drop event. Delay the page-level upload briefly so an exact folder
    // target can mark the event as consumed first.
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted || serialAtDrop != _explicitFolderDropSerial) return;
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
      _startDroppedFileUpload(
        droppedFiles,
        fileManager.currentPath,
        displayTargetName: '当前目录',
      );
    });
  }

  void _handleDroppedFilesToFolder(FileModel folder, List<XFile> droppedFiles) {
    _explicitFolderDropSerial++;
    _startDroppedFileUpload(
      droppedFiles,
      folder.path,
      displayTargetName: folder.name,
    );
  }

  Future<void> _startDroppedFileUpload(
    List<XFile> droppedFiles,
    String targetPath, {
    required String displayTargetName,
  }) async {
    final files = <File>[];
    var skipped = 0;

    for (final xFile in droppedFiles) {
      final path = xFile.path;
      if (path.isEmpty) {
        skipped++;
        continue;
      }

      final entityType = FileSystemEntity.typeSync(path, followLinks: true);
      if (entityType == FileSystemEntityType.file) {
        files.add(File(path));
      } else {
        skipped++;
      }
    }

    if (files.isEmpty) {
      ToastHelper.warning('没有可上传的文件；暂不支持直接拖拽文件夹');
      return;
    }

    try {
      final uploadManager = Provider.of<UploadManagerProvider>(context, listen: false);
      uploadManager.markShouldShowDialog();
      await uploadManager.startUpload(files, targetPath);

      final skippedText = skipped > 0 ? '，已跳过 $skipped 个文件夹或不可读项目' : '';
      ToastHelper.info('已添加 ${files.length} 个文件到「$displayTargetName」上传队列$skippedText');
    } catch (error) {
      ToastHelper.error('拖拽上传失败：$error');
    }
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
    if (fileManager.highlightPath != null &&
        fileManager.highlightPath != _lastListAutoScrollHighlightPath) {
      final highlightPath = fileManager.highlightPath!;
      final idx = fileManager.files.indexWhere((f) => f.path == highlightPath);
      if (idx >= 0) {
        _lastListAutoScrollHighlightPath = highlightPath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            const itemHeight = 52.0;
            final offset = (idx * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
          }
        });
      }
    } else if (fileManager.highlightPath == null) {
      _lastListAutoScrollHighlightPath = null;
    }

    return Column(
      children: [
        if (isDesktop) FileListHeader(
          showCheckbox: showCheckbox,
          currentSort: fileManager.sortOption,
          onSort: (option) => fileManager.setSortOption(option),
          totalCount: fileManager.files.length,
          selectedCount: fileManager.selectedFiles.length,
          onSelectAll: fileManager.selectAll,
          onClearSelection: fileManager.clearSelection,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _onRefresh(fileManager),
            child: NotificationListener<ScrollNotification>(
              onNotification: _fabKey.currentState?.onScrollNotification ?? ((_) => false),
              child: Listener(
                onPointerSignal: _onPointerSignal,
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
                    alwaysShowMobileCheckbox: !isDesktop,
                    index: index,
                    isDesktop: isDesktop,
                    onTap: () {
                      _fabKey.currentState?.hide();
                      _fabKey.currentState?.scheduleShow();
                      if (showCheckbox) {
                        fileManager.toggleSelection(file.path);
                      } else if (file.isFolder) {
                        _enterFolderFromCurrentContext(fileManager, file);
                      } else {
                        _openFile(context, file);
                      }
                    },
                    onSelect: () => fileManager.toggleSelection(file.path),
                    onDownload: () => _downloadFile(context, fileManager, file),
                    onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
                    onOpenInCloudreveApp: !file.isFolder ? () => _openInCloudreveApp(context, file) : null,
                    onRename: () => FileOperationDialogs.showRenameDialog(context, fileManager, file),
                    onMove: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, false),
                    onCopy: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, true),
                    onShare: () => FileOperationDialogs.showShareDialog(context, file),
                    onDelete: () => FileOperationDialogs.showDeleteSingleConfirmation(context, fileManager, file),
                    onInfo: () => _showFileInfo(file),
                    onDropFiles: file.isFolder
                        ? (files) => _handleDroppedFilesToFolder(file, files)
                        : null,
                  );
                },
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(BuildContext context, FileManagerProvider fileManager) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;
    final spacing = screenWidth >= 900 ? 14.0 : 10.0;
    final horizontalPadding = screenWidth >= 900 ? 16.0 : 10.0;
    const maxTileWidth = 176.0;
    const tileHeight = 188.0;

    final availableWidth = screenWidth - horizontalPadding * 2;
    final crossAxisCount = (availableWidth / (maxTileWidth + spacing))
        .floor()
        .clamp(screenWidth < 420 ? 2 : 3, 9);
    final showCheckbox = fileManager.hasSelection;
    final itemCount = fileManager.files.length + (fileManager.hasMore || fileManager.isLoadingMore ? 1 : 0);

    // 高亮文件时滚动到对应位置
    if (fileManager.highlightPath != null &&
        fileManager.highlightPath != _lastGridAutoScrollHighlightPath) {
      final highlightPath = fileManager.highlightPath!;
      final idx = fileManager.files.indexWhere((f) => f.path == highlightPath);
      if (idx >= 0) {
        _lastGridAutoScrollHighlightPath = highlightPath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            final row = idx ~/ crossAxisCount;
            final itemHeight = tileHeight + spacing;
            final offset = (row * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
          }
        });
      }
    } else if (fileManager.highlightPath == null) {
      _lastGridAutoScrollHighlightPath = null;
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(fileManager),
      child: NotificationListener<ScrollNotification>(
        onNotification: _fabKey.currentState?.onScrollNotification ?? ((_) => false),
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: GridView.builder(
            controller: _scrollController,
          key: PageStorageKey('files_grid_${fileManager.currentPath}'),
          cacheExtent: 1100,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: tileHeight,
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
              alwaysShowMobileCheckbox: !isDesktop,
              contextHint: fileManager.contextHint,
              onTap: () {
                _fabKey.currentState?.hide();
                _fabKey.currentState?.scheduleShow();
                if (showCheckbox) {
                  fileManager.toggleSelection(file.path);
                } else if (file.isFolder) {
                  _enterFolderFromCurrentContext(fileManager, file);
                } else {
                  _openFile(context, file);
                }
              },
              onSelect: () => fileManager.toggleSelection(file.path),
              onDownload: () => _downloadFile(context, fileManager, file),
              onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
              onOpenInCloudreveApp: !file.isFolder ? () => _openInCloudreveApp(context, file) : null,
              onRename: () => FileOperationDialogs.showRenameDialog(context, fileManager, file),
              onMove: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, false),
              onCopy: () => FileOperationDialogs.showMoveDialog(context, fileManager, file, true),
              onShare: () => FileOperationDialogs.showShareDialog(context, file),
              onDelete: () => FileOperationDialogs.showDeleteSingleConfirmation(context, fileManager, file),
              onInfo: () => _showFileInfo(file),
              onDropFiles: file.isFolder
                  ? (files) => _handleDroppedFilesToFolder(file, files)
                  : null,
            );
          },
        ),
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

    if (!isDesktop) {
      // 手机端的选择操作不再额外叠加一行底部栏。
      // 进入选择态后，由 AppShell 直接把主底部导航栏替换为
      // 下载 / 分享 / 删除 / 重命名 / 更多。
      return const SizedBox.shrink();
    }

    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
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
    } else if (file.isFolder) {
      await _downloadAsArchive(fileManager, [file]);
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
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    if (isDesktop && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await _showDesktopDownloadDialog(fileManager, files);
    } else {
      await _downloadAsArchive(fileManager, files);
    }
  }

  Future<void> _exportSelectedDirectories(
    FileManagerProvider fileManager,
    List<FileModel> selectedFiles,
  ) async {
    final folders = selectedFiles.where((file) => file.isFolder).toList();
    if (folders.isEmpty) {
      ToastHelper.info('请选择文件夹后再导出目录');
      return;
    }
    await FileOperationDialogs.showExportDirectoryDialog(
      context,
      fileManager,
      folders,
    );
  }

  /// 下载为压缩包（移动端 & 通用路径）
  Future<void> _downloadAsArchive(
    FileManagerProvider fileManager,
    List<FileModel> files, {
    String? customParentDir,
  }) async {
    try {
      final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);
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
        savePath: customParentDir == null
            ? null
            : '$customParentDir${Platform.pathSeparator}$archiveName',
        downloadUrl: url,
        initialStatus: DownloadStatus.archiving,
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
  }

  /// Desktop download target dialog.
  Future<void> _showDesktopDownloadDialog(
    FileManagerProvider fileManager,
    List<FileModel> files,
  ) async {
    final shouldArchive = files.length > 1 || files.any((f) => f.isFolder);
    final downloadManager = Provider.of<DownloadManagerProvider>(
      context,
      listen: false,
    );

    final storedDir = await StorageService.instance.getString(
      StorageKeys.downloadDefaultDirectory,
    );
    final defaultDirectory = await DownloadService().getDownloadDirectory();
    if (!mounted) return;

    String selectedDirectory = storedDir?.trim().isNotEmpty == true
        ? storedDir!.trim()
        : defaultDirectory.path;
    bool setAsDefault = false;
    final title = shouldArchive ? '下载为压缩包' : '下载文件';
    final displayName = shouldArchive
        ? '已选择 ${files.length} 项，将打包为 ZIP 压缩包下载'
        : files.first.name;
    final isFolder = files.length == 1 && files.first.isFolder;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDirectory() async {
              final picked = await FilePicker.platform.getDirectoryPath(
                dialogTitle: '选择下载保存位置',
                initialDirectory: Directory(selectedDirectory).existsSync()
                    ? selectedDirectory
                    : defaultDirectory.path,
              );
              if (picked != null && picked.trim().isNotEmpty) {
                setDialogState(() => selectedDirectory = picked.trim());
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 28,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isFolder
                                ? Icons.folder_rounded
                                : Icons.insert_drive_file_outlined,
                            size: 28,
                            color: isFolder
                                ? const Color(0xFFFFB923)
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!shouldArchive) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            '${app_date_utils.DateUtils.formatFileSize(files.first.size)}  |  '
                            '${app_date_utils.DateUtils.formatDateTime(files.first.updatedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      InkWell(
                        onTap: pickDirectory,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Text(
                                '下载到：',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDirectory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.folder_open_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setDialogState(
                          () => setAsDefault = !setAsDefault,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: setAsDefault,
                                onChanged: (value) => setDialogState(
                                  () => setAsDefault = value ?? false,
                                ),
                              ),
                              Text(
                                '设为默认路径',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 44,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: colorScheme.primary
                                    .withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              onPressed: () => Navigator.of(
                                dialogContext,
                              ).pop(false),
                              child: const Text(
                                '取消',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 150,
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              onPressed: () => Navigator.of(
                                dialogContext,
                              ).pop(true),
                              child: const Text(
                                '下载',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    if (setAsDefault) {
      await StorageService.instance.setString(
        StorageKeys.downloadDefaultDirectory,
        selectedDirectory,
      );
    }

    if (shouldArchive) {
      await _downloadAsArchive(
        fileManager,
        files,
        customParentDir: selectedDirectory,
      );
    } else {
      final file = files.first;
      final task = await downloadManager.addDownloadTask(
        fileName: file.name,
        fileUri: file.relativePath,
        fileSize: file.size,
        savePath: '$selectedDirectory${Platform.pathSeparator}${file.name}',
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
  // ignore: unused_element
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
          _buildDesktopAnimatedSelectionSlot(fileManager),
          if (hasSelection) const SizedBox(width: 6),
          if (!hasSelection)
            DesktopActionButtons(
              fileManager: fileManager,
              hasSelection: false,
              onShowCreateTextFile: () => _showCreateTextFileDialog(context, fileManager),
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



class _RollingSelectionCount extends StatefulWidget {
  final int value;
  final Color color;

  const _RollingSelectionCount({
    required this.value,
    required this.color,
  });

  @override
  State<_RollingSelectionCount> createState() => _RollingSelectionCountState();
}

class _RollingSelectionCountState extends State<_RollingSelectionCount> {
  bool _increasing = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _RollingSelectionCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _increasing = widget.value > oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final begin = _increasing ? const Offset(0, 1) : const Offset(0, -1);
            final outBegin = _increasing ? const Offset(0, -1) : const Offset(0, 1);
            final isCurrent = child.key == ValueKey<int>(widget.value);
            final tween = Tween<Offset>(
              begin: isCurrent ? begin : outBegin,
              end: Offset.zero,
            );
            return SlideTransition(
              position: tween.animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            '${widget.value}',
            key: ValueKey<int>(widget.value),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
