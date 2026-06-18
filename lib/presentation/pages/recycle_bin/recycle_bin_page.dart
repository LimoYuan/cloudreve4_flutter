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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_hasSelection) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '取消选择',
          onPressed: _clearSelection,
        ),
        title: Text('已选中 ${_selectedFiles.length} 个文件'),
        actions: [
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(_selectedFiles.length == _files.length ? '取消全选' : '全选'),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('回收站'),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          onPressed: _toggleSelectAll,
          tooltip: '全选',
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

    return RefreshIndicator(
      onRefresh: _refreshFiles,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_errorMessage != null) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
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
            ),
          ),
        ],
      );
    }

    if (_files.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
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
            ),
          ),
        ],
      );
    }

    if (_viewType == FileViewType.list) {
      return _buildListView(context);
    }

    return _buildGridView(context);
  }

  Widget _buildListView(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;
    final showCheckbox = _hasSelection;

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isSelected = _selectedFiles.contains(file.path);

        return FileListItem(
          key: ValueKey('trash_file_${file.id}'),
          file: file,
          isSelected: isSelected,
          showCheckbox: showCheckbox,
          alwaysShowMobileCheckbox: !isDesktop,
          index: index,
          isDesktop: isDesktop,
          tapToShowMenu: !_hasSelection,
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
    final isDesktop = screenWidth >= 1000;
    final showCheckbox = _hasSelection;
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
          showCheckbox: showCheckbox,
          alwaysShowMobileCheckbox: !isDesktop,
          tapToShowMenu: !_hasSelection,
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: !_hasSelection
          ? const SizedBox.shrink(key: ValueKey('trash_no_selection'))
          : Container(
              key: const ValueKey('trash_selection_bar'),
              height: 80 + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _TrashActionItem(
                    icon: Icons.restore_outlined,
                    label: '恢复',
                    onTap: _restoreSelected,
                  ),
                  _TrashActionItem(
                    icon: Icons.delete_forever_outlined,
                    label: '彻底删除',
                    danger: true,
                    onTap: _deleteSelected,
                  ),
                  _TrashActionItem(
                    icon: Icons.select_all,
                    label: _selectedFiles.length == _files.length ? '取消全选' : '全选',
                    onTap: _toggleSelectAll,
                  ),
                  _TrashActionItem(
                    icon: Icons.close,
                    label: '取消',
                    onTap: _clearSelection,
                  ),
                ],
              ),
            ),
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

  void _clearSelection() {
    if (!_hasSelection) return;
    setState(() => _selectedFiles.clear());
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedFiles.length == _files.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles = _files.map((f) => f.path).toSet();
      }
    });
  }

  Future<void> _refreshFiles() async {
    await _loadFiles();
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
      _clearSelection();
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
      _clearSelection();
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


class _TrashActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _TrashActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = danger ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum FileViewType {
  list,
  grid,
}
