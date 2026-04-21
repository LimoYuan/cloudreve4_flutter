import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<FileModel> _files = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _caseFolding = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: '搜索文件...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => _performSearch(value.trim()),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _performSearch(_searchController.text.trim()),
          tooltip: '搜索',
        ),
        IconButton(
          icon: Icon(Icons.text_fields, color: _caseFolding ? Colors.blue : null),
          onPressed: () {
            setState(() {
              _caseFolding = !_caseFolding;
            });
            if (_searchController.text.trim().isNotEmpty) {
              _performSearch(_searchController.text.trim());
            }
          },
          tooltip: '忽略大小写',
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
              onPressed: () => _performSearch(_searchController.text.trim()),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_files.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索文件',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            if (_caseFolding)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: const Text('忽略大小写'),
                  avatar: const Icon(Icons.text_fields, size: 16),
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _performSearch(_searchController.text.trim()),
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return _buildFileItem(context, file);
        },
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, FileModel file) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: file.isFolder ? Colors.orange.shade100 : Colors.blue.shade100,
        child: Icon(
          file.isFolder ? Icons.folder : Icons.description,
          color: file.isFolder ? Colors.orange : Colors.blue,
        ),
      ),
      title: Text(file.name),
      subtitle: Text(
        Uri.decodeComponent(file.relativePath),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Text(
        file.isFolder ? '文件夹' : _formatFileSize(file),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      onTap: () {
        // 点击搜索结果，导航到对应位置所在文件夹
        _navigateToParentFolder(context, file);
      },
    );
  }

  String _formatFileSize(FileModel file) {
    final size = file.size;
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _files = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().searchFiles(
        name: query,
        caseFolding: _caseFolding,
      );

      final filesData = response['files'] as List<dynamic>? ?? [];
      final files = filesData
          .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _navigateToParentFolder(BuildContext context, FileModel file) {
    // 从文件的 path 中提取父目录
    // cloudreve://my/file.txt -> /
    // cloudreve://my/sub/file.txt -> /sub
    // cloudreve://my/a/b/file.txt -> /a/b

    final path = file.path;
    final prefix = 'cloudreve://my';

    if (!path.startsWith(prefix)) {
      return;
    }

    // 去掉前缀
    final relativePath = path.substring(prefix.length);
    if (relativePath.isEmpty) {
      // 只有前缀，没有文件
      return;
    }

    final parts = relativePath.split('/');
    // 移除最后一个文件名/文件夹名，得到父目录路径
    if (parts.length > 1) {
      parts.removeLast();
    }

    final parentPath = parts.isEmpty ? '/' : parts.join('/');

    // 使用 popUntil 返回到主页，然后使用 replacement 设置新路径
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) {
      final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
      fileManager.enterFolder(parentPath);
    }
  }
}
