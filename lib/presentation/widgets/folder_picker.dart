import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:flutter/material.dart';
import '../../core/utils/app_logger.dart';

/// 文件夹选择器
class FolderPicker extends StatefulWidget {
  final String currentPath;
  final void Function(String path) onFolderSelected;
  final int? maxVisibleItems;

  const FolderPicker({
    super.key,
    required this.currentPath,
    required this.onFolderSelected,
    this.maxVisibleItems,
  });

  @override
  State<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<FolderPicker> {
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
      AppLogger.d('加载文件夹失败: $e');
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
    final maxHeight = MediaQuery.of(context).size.height * 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBreadcrumb(context, primaryColor),
        const Divider(height: 1),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxVisibleItems != null
                  ? (widget.maxVisibleItems! * 56.0 + 40.0).clamp(80.0, maxHeight)
                  : maxHeight,
            ),
            child: _buildListContent(context, primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(BuildContext context, Color primaryColor) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('此文件夹为空', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _folders.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56, endIndent: 16),
            _buildFolderItem(_folders[i], primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderItem(FileModel folder, Color primaryColor) {
    return InkWell(
      onTap: () => _enterFolder(folder),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(folder.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
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
                onPressed: () {
                  final relative = _currentPath.startsWith('cloudreve://my')
                      ? _currentPath.replaceFirst('cloudreve://my', '')
                      : _currentPath;
                  widget.onFolderSelected(relative.isEmpty ? '/' : relative);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('选择'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
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
      onTap: isLast
          ? null
          : () {
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
