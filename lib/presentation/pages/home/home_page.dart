import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/file_grid_item.dart';

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
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 实现设置功能
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _buildFileList(context),
      floatingActionButton: Consumer<FileManagerProvider>(
        builder: (context, fileManager, child) {
          return FloatingActionButton(
            onPressed: () {
              _showCreateDialog(context, fileManager);
            },
            child: const Icon(Icons.add),
          );
        },
      )
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

    return Drawer(
      child: ListView(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.user;
              return UserAccountsDrawerHeader(
                accountName: Text(user?.nickname ?? '用户'),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  child: Text(
                    (user?.nickname ?? '').isNotEmpty
                        ? user!.nickname[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
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
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
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
      )
    );
  }

  Widget _buildListView(BuildContext context, FileManagerProvider fileManager) {
    return Column(
      children: [
        _buildBreadcrumb(context, fileManager),
        if (fileManager.hasSelection)
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
                    fileManager.enterFolder(file.path);
                  } else {
                    // TODO: 打开文件
                  }
                },
                onLongPress: () {
                  fileManager.toggleSelection(file.id);
                },
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
        if (fileManager.hasSelection)
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
                    fileManager.enterFolder(file.path);
                  } else {
                    // TODO: 打开文件
                  }
                },
                onLongPress: () {
                  fileManager.toggleSelection(file.id);
                },
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
                  ]
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
}
