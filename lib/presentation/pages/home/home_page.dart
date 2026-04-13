import 'dart:io';
import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
        fileManager.loadFiles();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              _showUploadDialog(context);
            },
            tooltip: '上传',
          ),
          IconButton(
            icon: const Icon(Icons.download),
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
          _buildFileList(context),
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
      floatingActionButton: Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return FloatingActionButton(
            onPressed: () {
              _showCreateDialog(context, fileManager);
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
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
          return const Center(
            child: CircularProgressIndicator(),
          );
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
                  child: const Text('重试'),
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

  Widget _buildEmptyFolder(BuildContext context, FileManagerProvider fileManager) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            fileManager.currentPath == '/'
                ? '文件夹为空'
                : '暂无文件',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (fileManager.currentPath == '/')
            const SizedBox(height: 8),
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
    return Column(
      children: [
        _buildBreadcrumb(context, fileManager),
        _buildSelectionToolbar(context, fileManager),
        Expanded(
          child: ListView.builder(
            itemCount: fileManager.files.length,
            itemBuilder: (context, index) {
              final file = fileManager.files[index];
              final isSelected = fileManager.selectedFiles.contains(file.id);

              return FileListItem(
                key: ValueKey('file_${file.id}'),
                file: file,
                isSelected: isSelected,
                onTap: () {
                  if (file.isFolder) {
                    fileManager.enterFolder(file.relativePath);
                  } else {
                    // TODO: 打开文件
                  }
                },
                onLongPress: () {
                  fileManager.toggleSelection(file.id);
                },
                onDownload: () {
                  _downloadFile(context, fileManager, file);
                },
                onOpenInBrowser: !file.isFolder
                    ? () {
                        _openInBrowser(context, file);
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(BuildContext context, FileManagerProvider fileManager) {
    return Column(
      children: [
        _buildBreadcrumb(context, fileManager),
        _buildSelectionToolbar(context, fileManager),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: fileManager.files.length,
            itemBuilder: (context, index) {
              final file = fileManager.files[index];
              final isSelected = fileManager.selectedFiles.contains(file.id);

              return FileGridItem(
                key: ValueKey('file_grid_${file.id}'),
                file: file,
                isSelected: isSelected,
                onTap: () {
                  if (file.isFolder) {
                    fileManager.enterFolder(file.relativePath);
                  } else {
                    // TODO: 打开文件
                  }
                },
                onLongPress: () {
                  fileManager.toggleSelection(file.id);
                },
                onDownload: () {
                  _downloadFile(context, fileManager, file);
                },
                onOpenInBrowser: !file.isFolder
                    ? () {
                        _openInBrowser(context, file);
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(BuildContext context, FileManagerProvider fileManager) {
    final pathParts = fileManager.currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 根目录
            InkWell(
              onTap: () {
                fileManager.enterFolder('/');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(Icons.home, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '首页',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            for (int i = 0; i < pathParts.length; i++)
              ...[
                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                InkWell(
                  onTap: () {
                    final path = '/${pathParts.sublist(0, i + 1).join('/')}';
                    fileManager.enterFolder(path);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      pathParts[i],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
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

  Widget _buildSelectionToolbar(BuildContext context, FileManagerProvider fileManager) {
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

  void _showCreateDialog(BuildContext context, FileManagerProvider fileManager) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;

              Navigator.of(context).pop();
              await fileManager.createFolder(controller.text);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FileManagerProvider fileManager) {
    if (fileManager.selectedFiles.length != 1) return;

    final fileId = fileManager.selectedFiles.first;
    final file = fileManager.files.firstWhere((f) => f.id == fileId);
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

  void _showDeleteConfirmation(BuildContext context, FileManagerProvider fileManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除这 ${fileManager.selectedFiles.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await fileManager.deleteSelectedFiles();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('选择图片'),
              onTap: () {
                _pickFiles(context, FileType.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('选择视频'),
              onTap: () {
                _pickFiles(context, FileType.video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('选择文件'),
              onTap: () {
                _pickFiles(context, FileType.any);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles(BuildContext context, FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
      );

      if (!context.mounted) return;

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择文件')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件路径')),
        );
        return;
      }

      final uploadManager = Provider.of<UploadManagerProvider>(context, listen: false);
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

      await uploadManager.startUpload(files, fileManager.currentPath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e')),
      );
    }
  }

  /// 处理退出登录
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 获取Provider引用（在async操作前）
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

      // 执行登出
      await authProvider.logout();

      // 清空文件列表
      fileManager.clearFiles();

      // 跳转到登录页
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.login,
          (route) => false,
        );
      }
    }
  }

  /// 下载文件
  Future<void> _downloadFile(BuildContext context, FileManagerProvider fileManager, FileModel file) async {
    final downloadManager = Provider.of<DownloadManagerProvider>(context, listen: false);

    final task = await downloadManager.addDownloadTask(
      fileName: file.name,
      fileUri: file.relativePath,
      fileSize: file.size,
    );

    if (task != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件已在下载列表中')),
        );
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
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法打开链接')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取下载链接失败: $e')),
        );
      }
    }
  }
}
