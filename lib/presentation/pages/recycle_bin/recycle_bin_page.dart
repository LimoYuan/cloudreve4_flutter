import 'package:flutter/material.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';
import '../../widgets/file_grid_item.dart';
import '../../widgets/file_list_item.dart';
import '../../widgets/gesture_handler_mixin.dart';
import '../../widgets/toast_helper.dart';

/// 回收站页面
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage>
    with GestureHandlerMixin {
  List<FileModel> _files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = false;
  String? _errorMessage;
  FileViewType _viewType = FileViewType.list;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasSelection,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasSelection) {
          setState(() {
            _selectedFiles.clear();
          });
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildBody(context),
        bottomNavigationBar: _buildBottomBar(context),
        floatingActionButton: _buildFloatingActionButton(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('回收站'),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: () {
            if (_hasSelection) {
              setState(() {
                _selectedFiles.clear();
              });
            } else {
              setState(() {
                _selectedFiles =
                    _files.map((f) => f.path).toSet();
              });
            }
          },
          tooltip: _hasSelection ? '取消选择' : '全选',
        ),
        IconButton(
          icon: Icon(
            _viewType == FileViewType.list
                ? Icons.grid_view
                : Icons.view_list,
          ),
          onPressed: () {
            setState(() {
              _viewType = _viewType == FileViewType.list
                  ? FileViewType.grid
                  : FileViewType.list;
            });
          },
          tooltip: _viewType == FileViewType.list ? '网格视图' : '列表视图',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadFiles,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restore_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '回收站为空',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '删除的文件会出现在这里',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_viewType == FileViewType.list) {
      return _buildListView(context);
    }

    return _buildGridView(context);
  }

  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isSelected = _selectedFiles.contains(file.path);

        return FileListItem(
          key: ValueKey('trash_file_${file.id}'),
          file: file,
          isSelected: isSelected,
          showCheckbox: _hasSelection,
          onTap: () {
            if (_hasSelection) {
              _toggleSelection(file.path);
            }
          },
          onSelect: () => _toggleSelection(file.path),
          onRestore: () => _restoreFile(context, file),
          onDelete: () => _deleteFile(context, file),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
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

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing / 2,
        crossAxisSpacing: spacing / 2,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isSelected = _selectedFiles.contains(file.path);

        return FileGridItem(
          key: ValueKey('trash_file_grid_${file.id}'),
          file: file,
          isSelected: isSelected,
          showCheckbox: _hasSelection,
          onTap: () {
            if (_hasSelection) {
              _toggleSelection(file.path);
            }
          },
          onSelect: () => _toggleSelection(file.path),
          onRestore: () => _restoreFile(context, file),
          onDelete: () => _deleteFile(context, file),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (_hasSelection) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Text('已选择 ${_selectedFiles.length} 项'),
              const Spacer(),
              TextButton.icon(
                onPressed: _restoreSelected,
                icon: const Icon(Icons.restore),
                label: const Text('恢复'),
              ),
              TextButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('彻底删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'refresh_trash',
      onPressed: () => _refreshFiles(context),
      child: const Icon(Icons.refresh),
    );
  }

  bool get _hasSelection => _selectedFiles.isNotEmpty;

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedFiles.contains(path)) {
        _selectedFiles.remove(path);
      } else {
        _selectedFiles.add(path);
      }
    });
  }

  Future<void> _refreshFiles(BuildContext context) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listTrashFiles(page: 0);
      final filesData = response['files'] as List<dynamic>? ?? [];
      final files = filesData
          .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
          .toList();

      setState(() {
        _files = files;
        _isLoading = false;
      });

      if (mounted) {
        ToastHelper.success('刷新成功');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        ToastHelper.failure('刷新失败: ${e.toString()}');
      }
    }
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listTrashFiles(page: 0);
      final filesData = response['files'] as List<dynamic>? ?? [];
      final files = filesData
          .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
          .toList();

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _restoreFile(BuildContext context, FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复文件'),
        content: Text('确定要恢复 "${file.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRestore([file.path]);
    }
  }

  Future<void> _restoreSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复文件'),
        content: Text('确定要恢复选中的 ${_selectedFiles.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRestore(_selectedFiles.toList());
      setState(() {
        _selectedFiles.clear();
      });
    }
  }

  Future<void> _performRestore(List<String> uris) async {
    try {
      await FileService().restoreFiles(uris: uris);

      if (mounted) {
        ToastHelper.success('恢复成功');
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.failure('恢复失败: $e');
      }
    }
  }

  Future<void> _deleteFile(BuildContext context, FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text(
          '确定要彻底删除 "${file.name}" 吗？\n此操作不可撤销！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performDelete([file.path]);
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text(
          '确定要彻底删除选中的 ${_selectedFiles.length} 个文件吗？\n此操作不可撤销！',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performDelete(_selectedFiles.toList());
      setState(() {
        _selectedFiles.clear();
      });
    }
  }

  Future<void> _performDelete(List<String> uris) async {
    try {
      await FileService().deleteFiles(
        uris: uris,
        unlink: false,
        skipSoftDelete: true,
      );

      if (mounted) {
        ToastHelper.success('删除成功');
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.failure('删除失败: $e');
      }
    }
  }
}

enum FileViewType {
  list,
  grid,
}
