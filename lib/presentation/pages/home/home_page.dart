import 'dart:io';
import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/upload_manager_provider.dart';
import '../../providers/download_manager_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/upload_progress_dialog.dart';
import '../../widgets/download_progress_dialog.dart';
import '../../../router/app_router.dart';

/// 主页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastSwipeTime;
  OverlayEntry? _exitHintOverlay;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final fileManager = Provider.of<FileManagerProvider>(
          context,
          listen: false,
        );
        fileManager.loadFiles();

        // 初始化下载管理器，加载持久化的任务
        final downloadManager = Provider.of<DownloadManagerProvider>(
          context,
          listen: false,
        );
        downloadManager.initialize();
      }
    });
  }

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
          await _handleBackPress(context, fileManager);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.user;
            final displayName = user?.nickname ?? 'Cloudreve';
            return Text(displayName);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 实现搜索功能
            },
            tooltip: '搜索',
          ),
          // 视图切换按钮
          Consumer<FileManagerProvider>(
            builder: (context, fileManager, child) {
              final icon = fileManager.viewType == FileViewType.list
                  ? Icons.grid_view
                  : Icons.view_list;
              return IconButton(
                icon: Icon(icon),
                onPressed: () {
                  _toggleView(context, fileManager);
                },
                tooltip: fileManager.viewType == FileViewType.list ? '网格视图' : '列表视图',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              _showUploadDialog(context);
            },
            tooltip: '上传',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: () {
              showDownloadDialog(context);
            },
            tooltip: '下载',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 实现设置功能
            },
            tooltip: '设置',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _handleLogout(context);
            },
            tooltip: '退出登录',
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Stack(
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
                      child: const UploadProgressDialog(),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
      floatingActionButton: Column(
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
                  onPressed: () {
                    fileManager.refreshFiles();
                  },
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
                onPressed: () {
                  _showCreateDialog(context, fileManager);
                },
                child: const Icon(Icons.add),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  /// 带手势检测的文件列表
  Widget _buildFileListWithGesture(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        return GestureDetector(
          onHorizontalDragEnd: (details) => _handleSwipe(context, fileManager, details),
          child: _buildFileList(context),
        );
      },
    );
  }

  /// 处理左滑手势
  void _handleSwipe(
    BuildContext context,
    FileManagerProvider fileManager,
    DragEndDetails details,
  ) {
    if (details.primaryVelocity == null) return;
    // primaryVelocity 是 double，负值表示向左滑动
    if (details.primaryVelocity! < 0) {
      if (fileManager.currentPath == '/') {
        _checkExitApp(context);
      } else {
        _navigateBack(context, fileManager);
      }
    }
  }

  /// 处理返回键
  Future<void> _handleBackPress(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    if (fileManager.currentPath == '/') {
      await _checkExitApp(context);
    } else {
      await _navigateBack(context, fileManager);
    }
  }

  /// 返回上一级
  Future<void> _navigateBack(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    await fileManager.goBack();
  }

  /// 检查退出应用
  Future<void> _checkExitApp(BuildContext context) async {
    final now = DateTime.now();
    if (_lastSwipeTime != null && now.difference(_lastSwipeTime!).inSeconds < 2) {
      SystemNavigator.pop();
    } else {
      _lastSwipeTime = now;
      _showExitHint();
      Future.delayed(const Duration(seconds: 2), () {
        _removeExitHint();
      });
    }
  }

  /// 显示退出提示
  void _showExitHint() {
    _removeExitHint();
    _exitHintOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '再次左滑退出应用',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_exitHintOverlay!);
  }

  /// 移除退出提示
  void _removeExitHint() {
    _exitHintOverlay?.remove();
    _exitHintOverlay = null;
  }

  /// 构建底部导航栏
  Widget _buildBottomBar(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        if (fileManager.hasSelection) {
          return _buildSelectionToolbar(context, fileManager);
        }
        return _buildBreadcrumb(context, fileManager);
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(authProvider.user?.nickname ?? '用户'),
            accountEmail: Text(authProvider.user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              child: Text(
                (authProvider.user?.nickname ?? '').isNotEmpty
                    ? authProvider.user!.nickname[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('我的文件'),
            selected: fileManager.currentPath == '/',
            onTap: () {
              fileManager.enterFolder('/');
              Navigator.of(context).pop();
            },
          ),

          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('我的分享'),
            onTap: () {
              // TODO: 导航到分享页面
              Navigator.of(context).pop();
            },
          ),

          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('回收站'),
            onTap: () {
              // TODO: 导航到回收站
              Navigator.of(context).pop();
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              // TODO: 导航到设置页面
              Navigator.of(context).pop();
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () async {
              Navigator.of(context).pop();
              await _handleLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, fileManager, child) {
        if (fileManager.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (fileManager.errorMessage != null) {
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
                  onPressed: () {
                    fileManager.loadFiles();
                  },
                  child: const Text('重试&刷新Token'),
                ),
              ],
            ),
          );
        }

        if (fileManager.files.isEmpty) {
          return _buildEmptyFolder(context, fileManager);
        }

        if (fileManager.viewType == FileViewType.list) {
          return _buildListView(context, fileManager);
        }

        return _buildGridView(context, fileManager);
      },
    );
  }

  Widget _buildEmptyFolder(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            fileManager.currentPath == '/' ? '文件夹为空' : '暂无文件',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (fileManager.currentPath == '/') const SizedBox(height: 8),
          if (fileManager.currentPath == '/')
            Text(
              '点击 + 按钮创建新文件夹',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, FileManagerProvider fileManager) {
    final showCheckbox = fileManager.hasSelection;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
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
                    // TODO: 打开文件
                  }
                },
                onSelect: () => fileManager.toggleSelection(file.path),
                onDownload: !file.isFolder ? () => _downloadFile(context, fileManager, file) : null,
                onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
                onRename: () => _showRenameSingleDialog(context, fileManager, file),
                onMove: () => _showMoveSingleDialog(context, fileManager, file, false),
                onCopy: () => _showMoveSingleDialog(context, fileManager, file, true),
                onDelete: () => _showDeleteSingleConfirmation(context, fileManager, file),
              );
            },
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

    // 计算每项宽度（包括间距）
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

    // 计算每项的实际宽度
    final itemWidth = (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
    // 宽高比设置为正方形，避免溢出
    final childAspectRatio = itemWidth / 140;
    final showCheckbox = fileManager.hasSelection;

    return Expanded(
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
            showCheckbox: showCheckbox,
            onTap: () {
              if (showCheckbox) {
                fileManager.toggleSelection(file.path);
              } else if (file.isFolder) {
                fileManager.enterFolder(file.relativePath);
              } else {
                // TODO: 打开文件
              }
            },
            onSelect: () => fileManager.toggleSelection( file.path),
            onDownload: !file.isFolder ? () => _downloadFile(context, fileManager, file) : null,
            onOpenInBrowser: !file.isFolder ? () => _openInBrowser(context, file) : null,
            onRename: () => _showRenameSingleDialog(context, fileManager, file),
            onMove: () => _showMoveSingleDialog(context, fileManager, file, false),
            onCopy: () => _showMoveSingleDialog(context, fileManager, file, true),
            onDelete: () => _showDeleteSingleConfirmation(context, fileManager, file),
          );
        },
      ),
    );
  }

  Widget _buildBreadcrumb(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    final pathParts = fileManager.currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                onTap: () {
                  fileManager.enterFolder('/');
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.home, size: 18, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '首页',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            for (int i = 0; i < pathParts.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: InkWell(
                  onTap: () {
                    final path = '/${pathParts.sublist(0, i + 1).join('/')}';
                    fileManager.enterFolder(path);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      pathParts[i],
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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

  Widget _buildSelectionToolbar(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    final selectionCount = fileManager.selectedFiles.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '已选择 $selectionCount 项',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              fileManager.clearSelection();
            },
            tooltip: '取消选择',
          ),
          if (selectionCount == 1)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showRenameDialog(context, fileManager);
              },
              tooltip: '重命名',
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _showDeleteConfirmation(context, fileManager);
            },
            tooltip: '删除',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '文件夹名称',
            prefixIcon: Icon(Icons.folder),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;

              Navigator.of(dialogContext).pop();

              final error = await fileManager.createFolder(controller.text);
              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('创建文件夹失败: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('文件夹创建成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    if (fileManager.selectedFiles.length != 1) return;

    final filePath = fileManager.selectedFiles.first;
    final file = fileManager.files.firstWhere((f) => f.path == filePath);
    final controller = TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '新名称',
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;

              Navigator.of(context).pop();
              await fileManager.renameFile(file.path, controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除这 ${fileManager.selectedFiles.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final error = await fileManager.deleteSelectedFiles();
              if (error != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('删除成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 切换视图类型
  void _toggleView(BuildContext context, FileManagerProvider fileManager) {
    final newType = fileManager.viewType == FileViewType.list
        ? FileViewType.grid
        : FileViewType.list;
    fileManager.setViewType(newType);
  }

  void _showUploadDialog(BuildContext context) {
    // 显示上传进度对话框
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '选择要上传的文件',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // 文件选择按钮
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择图片'),
                      onPressed: () {
                        _pickFiles(context, FileType.image);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.video_library),
                      label: const Text('选择视频'),
                      onPressed: () {
                        _pickFiles(context, FileType.video);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: const Text('选择所有文件'),
                      onPressed: () {
                        _pickFiles(context, FileType.any);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 查看上传任务按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text('查看上传任务'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showUploadTaskDialog(context);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示上传任务对话框
  void _showUploadTaskDialog(BuildContext context) {
    showUploadDialogWidget(context);
  }

  Future<void> _pickFiles(BuildContext context, FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
      );
      debugPrint('上传文件1 -> 选择文件: $result');

      // 关闭选择对话框（在选择文件成功后）
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未选择文件')));
        debugPrint('上传图片->未选择文件: $result');
        return;
      }

      // Convert PlatformFile to File objects
      final files = <File>[];
      for (final file in result.files) {
        if (file.path != null) {
          files.add(File(file.path!));
        }
      }

      if (files.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法获取文件路径')));
        return;
      }

      final uploadManager = Provider.of<UploadManagerProvider>(
        context,
        listen: false,
      );
      final fileManager = Provider.of<FileManagerProvider>(
        context,
        listen: false,
      );

      debugPrint('_pickFiles: 准备上传 ${files.length} 个文件到路径 ${fileManager.currentPath}');

      // 开始上传
      await uploadManager.startUpload(files, fileManager.currentPath);

      debugPrint('_pickFiles: 上传已启动');

      // 显示上传任务对话框
      if (context.mounted) {
        _showUploadTaskDialog(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择文件失败: $e')));
    }
  }

  /// 处理退出登录
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(
      context,
      listen: false,
    );

    // 显示确认对话框
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
      // 执行登出
      await authProvider.logout();

      // 清空文件列表
      fileManager.clearFiles();

      // 跳转到登录页
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
      }
    }
  }

  /// 下载文件
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文件已在下载列表中')));
      }
      return;
    }

    // 显示下载对话框
    if (context.mounted) {
      showDownloadDialog(context);
    }
  }

  /// 在浏览器中打开文件
  Future<void> _openInBrowser(BuildContext context, FileModel file) async {
    try {
      final fileService = FileService();
      final response = await fileService.getDownloadUrls(
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
            debugPrint('无法打开链接: $uri');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('无法打开链接: $uri')));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取下载链接失败: $e')));
      }
    }
  }

  /// 显示单个文件移动对话框
  void _showMoveSingleDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
    bool copy,
  ) {
    // 创建文件夹选择器对话框
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy ? '复制文件' : '移动文件'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: _FolderPicker(
            currentPath: fileManager.currentPath,
            onFolderSelected: (selectedPath) async {
              Navigator.of(dialogContext).pop();

              try {
                await FileService().moveFiles(
                  uris: [file.path],
                  dst: selectedPath,
                  copy: copy,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(copy ? '复制成功' : '移动成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await fileManager.loadFiles();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${copy ? '复制' : '移动'}失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示单个文件重命名对话框
  void _showRenameSingleDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) {
    final controller = TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '新名称',
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;

              Navigator.of(dialogContext).pop();
              await fileManager.renameFile(file.path, controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示单个文件删除确认对话框
  void _showDeleteSingleConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除文件 "${file.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await FileService().deleteFiles(uris: [file.path]);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('删除成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await fileManager.loadFiles();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

}

/// 文件夹选择器
class _FolderPicker extends StatefulWidget {
  final String currentPath;
  final void Function(String path) onFolderSelected;

  const _FolderPicker({
    required this.currentPath,
    required this.onFolderSelected,
  });

  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  String _currentPath = '/';
  List<FileModel> _folders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.currentPath;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 100,
      );

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      setState(() {
        _folders = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .where((f) => f.isFolder)
            .toList();
      });
    } catch (e) {
      debugPrint('加载文件夹失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enterFolder(FileModel folder) {
    setState(() {
      _currentPath = folder.path;
    });
    _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // 面包屑导航
        _buildBreadcrumb(context, primaryColor),

        const Divider(height: 1),

        // 文件夹列表
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _folders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '此文件夹为空',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _folders.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        return InkWell(
                          onTap: () => _enterFolder(folder),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.folder,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    folder.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(BuildContext context, Color primaryColor) {
    final pathParts = _currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBreadcrumbItem(
                        context,
                        name: '首页',
                        path: '/',
                        isLast: pathParts.isEmpty,
                        primaryColor: primaryColor,
                      ),
                      ...pathParts.asMap().entries.expand((entry) {
                        final index = entry.key;
                        final part = entry.value;
                        final path = '/${pathParts.sublist(0, index + 1).join('/')}';

                        return [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          _buildBreadcrumbItem(
                            context,
                            name: part,
                            path: path,
                            isLast: index == pathParts.length - 1,
                            primaryColor: primaryColor,
                          ),
                        ];
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () => widget.onFolderSelected(_currentPath),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('选择'),
              ),
            ],
          ),
        ),
        Divider(height: 1),
      ],
    );
  }

  Widget _buildBreadcrumbItem(
    BuildContext context, {
    required String name,
    required String path,
    required bool isLast,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: isLast ? null : () {
        setState(() {
          _currentPath = path;
        });
        _loadFolders();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isLast
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name == '首页')
              Icon(
                Icons.home_filled,
                size: 16,
                color: isLast ? primaryColor : Colors.grey.shade600,
              ),
            if (name == '首页') const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                color: isLast ? primaryColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
