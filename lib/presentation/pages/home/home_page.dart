import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/upload_manager_provider.dart';
import '../../providers/download_manager_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/upload_progress_dialog.dart' as upload_progress;
import '../../widgets/download_progress_dialog.dart' show showDownloadDialog;
import '../../widgets/file_breadcrumb.dart';
import '../../widgets/selection_toolbar.dart';
import '../../widgets/empty_folder_view.dart';
import '../../widgets/home_drawer.dart';
import '../../widgets/upload_dialog.dart';
import '../../widgets/file_operation_dialogs.dart';
import '../../widgets/gesture_handler_mixin.dart';
import '../../widgets/toast_helper.dart';
import '../../../router/app_router.dart';
import '../../../core/utils/file_type_utils.dart';

/// 主页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with GestureHandlerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final fileManager = Provider.of<FileManagerProvider>(
          context,
          listen: false,
        );

        // 根据屏幕宽度设置默认视图类型
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth >= 1000) {
          fileManager.setViewType(FileViewType.grid);
        } else {
          fileManager.setViewType(FileViewType.list);
        }

        fileManager.loadFiles();

        final downloadManager = Provider.of<DownloadManagerProvider>(
          context,
          listen: false,
        );
        downloadManager.initialize();
      }
    });
  }

  @override
  GlobalKey<ScaffoldState>? get scaffoldKey => _scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final fileManager = Provider.of<FileManagerProvider>(
            context,
            listen: false,
          );
          await handleBackPress(context, fileManager);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(context),
        drawer: _buildDrawer(context),
        body: _buildBody(context),
        bottomNavigationBar: _buildBottomBar(context),
        floatingActionButton: _buildFloatingActionButtons(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

    return AppBar(
      title: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          final displayName = user?.nickname ?? 'Cloudreve';
          return Text(displayName);
        },
      ),
      actions: isDesktop ? _buildDesktopActions() : _buildMobileActions(),
    );
  }

  /// 桌面端操作按钮（宽度 ≥ 1000）
  List<Widget> _buildDesktopActions() {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () {
          Navigator.of(context).pushNamed(RouteNames.search);
        },
        tooltip: '搜索',
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
        icon: const Icon(Icons.cloud_upload),
        onPressed: () => showUploadDialog(context),
        tooltip: '上传',
      ),
      IconButton(
        icon: const Icon(Icons.cloud_download),
        onPressed: () => showDownloadDialog(context),
        tooltip: '下载',
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.of(context).pushNamed(RouteNames.settings);
        },
        tooltip: '设置',
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => _handleLogout(context),
        tooltip: '退出登录',
      ),
    ];
  }

  /// 移动端菜单按钮（宽度 < 1000）
  List<Widget> _buildMobileActions() {
    return [
      Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return PopupMenuButton<String>(
            icon: const Icon(Icons.apps_rounded),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('搜索'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'view_toggle',
                child: ListTile(
                  leading: Icon(
                    fileManager.viewType == FileViewType.list
                        ? Icons.grid_view
                        : Icons.view_list,
                  ),
                  title: Text(
                    fileManager.viewType == FileViewType.list ? '网格视图' : '列表视图',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'upload',
                child: ListTile(
                  leading: Icon(Icons.cloud_upload),
                  title: Text('上传'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.cloud_download),
                  title: Text('下载'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('退出登录', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  /// 处理菜单操作
  void _handleMenuAction(String value) {
    switch (value) {
      case 'search':
        Navigator.of(context).pushNamed(RouteNames.search);
        break;
      case 'view_toggle':
        final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
        fileManager.setViewType(
          fileManager.viewType == FileViewType.list
              ? FileViewType.grid
              : FileViewType.list,
        );
        break;
      case 'upload':
        showUploadDialog(context);
        break;
      case 'download':
        showDownloadDialog(context);
        break;
      case 'settings':
        Navigator.of(context).pushNamed(RouteNames.settings);
        break;
      case 'logout':
        _handleLogout(context);
        break;
    }
  }

  Widget _buildDrawer(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(
      context,
      listen: false,
    );

    return HomeDrawer(
      currentPath: fileManager.currentPath,
      onMyFiles: () {
        fileManager.enterFolder('/');
      },
      onMyShares: () {
        Navigator.of(context).pushNamed(RouteNames.share);
      },
      onRecycleBin: () {
        Navigator.of(context).pushNamed(RouteNames.recycleBin);
      },
      onWebdav: () {
        Navigator.of(context).pushNamed(RouteNames.webdav);
      },
      onRemoteDownload: () {
        Navigator.of(context).pushNamed(RouteNames.remoteDownload);
      },
      onSettings: () {
        Navigator.of(context).pushNamed(RouteNames.settings);
      },
      onLogout: () => _handleLogout(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Stack(
      children: [
        _buildFileListWithGesture(context),
        Consumer<UploadManagerProvider>(
          builder: (context, uploadManager, child) {
            if (uploadManager.showUploadDialog) {
              return Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Material(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: const upload_progress.UploadProgressDialog(),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildFileListWithGesture(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        return GestureDetector(
          onHorizontalDragEnd: (details) => handleSwipe(context, fileManager, details),
          child: _buildFileList(context, fileManager),
        );
      },
    );
  }

  Widget _buildFileList(BuildContext context, FileManagerProvider fileManager) {
    if (fileManager.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fileManager.errorMessage != null) {
      return _buildErrorView(context, fileManager);
    }

    if (fileManager.files.isEmpty) {
      return EmptyFolderView(currentPath: fileManager.currentPath);
    }

    // 根据用户选择的视图类型显示
    if (fileManager.viewType == FileViewType.list) {
      return _buildListView(context, fileManager);
    }

    return _buildGridView(context, fileManager);
  }

  Widget _buildErrorView(BuildContext context, FileManagerProvider fileManager) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            fileManager.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => fileManager.loadFiles(),
            child: const Text('重试&刷新Token'),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, FileManagerProvider fileManager) {
    final showCheckbox = fileManager.hasSelection;

    return ListView.builder(
      itemCount: fileManager.files.length,
      itemBuilder: (context, index) {
        final file = fileManager.files[index];
        final isSelected = fileManager.selectedFiles.contains(file.path);

        return FileListItem(
          key: ValueKey('file_${file.id}'),
          file: file,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          onTap: () {
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
        );
      },
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
    final childAspectRatio = itemWidth / 140;
    final showCheckbox = fileManager.hasSelection;

    return GridView.builder(
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
          showCheckbox: showCheckbox,
          onTap: () {
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
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
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
            onDelete: () => FileOperationDialogs.showDeleteConfirmation(
                  context,
                  fileManager,
                  fileManager.selectedFiles,
                ),
          );
        }

        return FileBreadcrumb(
          currentPath: fileManager.currentPath,
          onPathTap: (path) => fileManager.enterFolder(path),
        );
      },
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Consumer<FileManagerProvider>(
          builder: (context, fileManager, child) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton(
                heroTag: 'refresh',
                onPressed: () => fileManager.refreshFiles(),
                child: fileManager.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            );
          },
        ),
        Consumer<FileManagerProvider>(
          builder: (context, fileManager, child) {
            return FloatingActionButton(
              heroTag: 'add',
              onPressed: () => FileOperationDialogs.showCreateDialog(context, fileManager),
              child: const Icon(Icons.add),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(
      context,
      listen: false,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      fileManager.clearFiles();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
      }
    }
  }

  void _openFile(BuildContext context, FileModel file) {
    if (FileTypeUtils.isImage(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.imagePreview,
        arguments: file,
      );
    } else if (FileTypeUtils.isPdf(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.pdfPreview,
        arguments: file,
      );
    } else if (FileTypeUtils.isVideo(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.videoPreview,
        arguments: file,
      );
    } else if (FileTypeUtils.isAudio(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.audioPreview,
        arguments: file,
      );
    } else if (FileTypeUtils.isMarkdown(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.markdownPreview,
        arguments: file,
      );
    } else if (FileTypeUtils.isTextCode(file.name)) {
      Navigator.of(context).pushNamed(
        RouteNames.documentPreview,
        arguments: file,
      );
    } else {
      ToastHelper.info('暂不支持预览 ${FileTypeUtils.getFileTypeDescription(file.name)}');
    }
  }

  Future<void> _downloadFile(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final downloadManager = Provider.of<DownloadManagerProvider>(
      context,
      listen: false,
    );

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
      showDownloadDialog(context);
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
