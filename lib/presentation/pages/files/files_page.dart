import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:cloudreve4_flutter/services/upload_service.dart';
import '../../../core/utils/file_utils.dart';
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
import '../../../router/app_router.dart';
import '../../../core/utils/file_type_utils.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  bool _isFirstLoad = true;
  FileModel? _infoFile;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // FAB 状态
  bool _isFabVisible = true;
  bool _isFabExpanded = false;
  Timer? _fabShowTimer;

  // 桌面端拖拽状态
  bool _isDraggingOver = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth >= 1000) {
          fileManager.setViewType(FileViewType.grid);
        } else {
          fileManager.setViewType(FileViewType.list);
        }
        if (_isFirstLoad) {
          fileManager.loadFiles();
          _isFirstLoad = false;
        }
        final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);
        downloadManager.initialize();
      }
    });

    // 上传完成 → 自动刷新当前目录文件列表
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
    _fabShowTimer?.cancel();
    UploadService.instance.onUploadCompleted = null;
    super.dispose();
  }

  void _showFileInfo(FileModel file) {
    setState(() => _infoFile = file);
    // 等待下一帧 rebuild 完成，endDrawer 从 null 变为非 null 后再打开
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
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

  // ---- 构建方法 ----

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      bottomNavigationBar: _buildBottomBar(context),
      endDrawer: _infoFile != null ? FileInfoPanel(file: _infoFile!) : null,
      floatingActionButton: isDesktop ? null : _buildSpeedDialFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    return AppBar(
      title: Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          if (isDesktop) {
            if (fileManager.currentPath == '/') {
              return const Text('文件');
            }
            final segments = fileManager.currentPath.split('/').where((s) => s.isNotEmpty).toList();
            return Text(segments.isNotEmpty ? segments.last : '文件');
          }
          return _buildMobileBreadcrumb(context, fileManager);
        },
      ),
      actions: isDesktop ? _buildDesktopActions() : _buildMobileActions(),
    );
  }

  Widget _buildMobileBreadcrumb(BuildContext context, FileManagerProvider fileManager) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pathParts = fileManager.currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);

    return SizedBox(
      height: 40,
      child: ListView(
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
              label: pathParts[i],
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

  List<Widget> _buildDesktopActions() {
    return [
      IconButton(
        icon: const Icon(LucideIcons.search),
        onPressed: () => SearchDialog.show(context),
        tooltip: '搜索',
      ),
      Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return IconButton(
            icon: Icon(fileManager.isLoading ? Icons.hourglass_empty : Icons.refresh),
            onPressed: () => fileManager.refreshFiles(),
            tooltip: '刷新',
          );
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
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: () {
          final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
          FileOperationDialogs.showCreateDialog(context, fileManager);
        },
        tooltip: '新建',
      ),
      IconButton(
        icon: const Icon(Icons.cloud_upload),
        onPressed: () => showUploadDialog(context),
        tooltip: '上传',
      ),
      IconButton(
        icon: const Icon(Icons.cloud_download),
        onPressed: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(2),
        tooltip: '下载',
      ),
    ];
  }

  List<Widget> _buildMobileActions() {
    return [
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
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.upload, size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        '释放文件以上传到当前目录',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

    return Column(
      children: [
        if (isDesktop) FileListHeader(showCheckbox: showCheckbox),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _onRefresh(fileManager),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                itemCount: fileManager.files.length,
                itemBuilder: (context, index) {
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

    return RefreshIndicator(
      onRefresh: () => _onRefresh(fileManager),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing / 2,
            crossAxisSpacing: spacing / 2,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: fileManager.files.length,
          itemBuilder: (context, index) {
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

  Widget _buildBottomBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        if (fileManager.hasSelection) {
          return SelectionToolbar(
            selectionCount: fileManager.selectedFiles.length,
            onCancel: () => fileManager.clearSelection(),
            onRename: fileManager.selectedFiles.length == 1
                ? () => FileOperationDialogs.showRenameDialog(
                      context,
                      fileManager,
                      fileManager.files.firstWhere(
                        (f) => f.path == fileManager.selectedFiles.first,
                      ),
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

  Future<void> _downloadFile(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
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
}
