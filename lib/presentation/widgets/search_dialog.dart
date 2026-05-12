import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/file_icon_utils.dart';
import '../../data/models/file_model.dart';
import '../../services/file_service.dart';
import '../../services/storage_service.dart';
import '../providers/file_manager_provider.dart';
import '../providers/navigation_provider.dart';
import 'glassmorphism_container.dart';

/// 搜索对话框
class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '搜索',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).drive(Tween(begin: 0.92, end: 1.0));
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).drive(Tween(begin: 0.0, end: 1.0));
        return ScaleTransition(
          scale: scaleAnim,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => const SearchDialog(),
    );
  }

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<FileModel> _files = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _caseFolding = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await StorageService.instance.getSearchHistory();
    if (mounted) setState(() => _searchHistory = history);
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _files = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

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

  void _toggleCaseFolding() {
    setState(() => _caseFolding = !_caseFolding);
    final query = _searchController.text.trim();
    if (query.isNotEmpty) _performSearch(query);
  }

  Future<void> _clearHistory() async {
    await StorageService.instance.clearSearchHistory();
    if (mounted) setState(() => _searchHistory = []);
  }

  Future<void> _onResultTap(FileModel file) async {
    final query = _searchController.text.trim();

    // 在 async gap 之前获取所有引用
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final fileManager =
        Provider.of<FileManagerProvider>(context, listen: false);
    final parentPath = _extractParentPath(file.path);
    final filePath = file.path;

    if (query.isNotEmpty) {
      await StorageService.instance.addToSearchHistory(query);
    }

    if (parentPath == null || !mounted) return;

    Navigator.of(context).pop();

    navProvider.setIndex(1);
    fileManager.navigateAndHighlight(parentPath, filePath);
  }

  String? _extractParentPath(String filePath) {
    const prefix = 'cloudreve://my';
    if (!filePath.startsWith(prefix)) return null;

    final relativePath = filePath.substring(prefix.length);
    if (relativePath.isEmpty) return null;

    final parts = relativePath.split('/');
    if (parts.length > 1) parts.removeLast();
    return parts.isEmpty ? '/' : parts.join('/');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth >= 600;
    final dialogWidth = isWide ? 560.0 : screenWidth - 32.0;

    return Center(
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        child: GlassmorphismContainer(
          borderRadius: 16,
          sigmaX: 20,
          sigmaY: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchInput(context),
                  const Divider(height: 1),
                  Flexible(child: _buildBody(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 20, color: theme.hintColor),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '搜索文件...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: theme.hintColor),
              ),
              style: theme.textTheme.bodyLarge,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _debounceTimer?.cancel();
                _performSearch(value.trim());
              },
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.caseSensitive,
              size: 18,
              color: _caseFolding ? colorScheme.primary : theme.hintColor,
            ),
            onPressed: _toggleCaseFolding,
            tooltip: '忽略大小写',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.x, size: 18, color: theme.hintColor),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading && _files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle,
                  size: 40, color: colorScheme.error.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  style: TextStyle(color: theme.hintColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    _performSearch(_searchController.text.trim()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      final query = _searchController.text.trim();
      if (query.isEmpty && _searchHistory.isNotEmpty) {
        return _buildHistorySection(context);
      }
      if (query.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.searchX,
                    size: 40,
                    color: theme.hintColor.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text('未找到匹配文件',
                    style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('输入关键词搜索文件',
              style: TextStyle(color: theme.hintColor)),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: _files.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, indent: 68, endIndent: 20),
        itemBuilder: (context, index) =>
            _buildResultItem(context, _files[index]),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.history, size: 16, color: theme.hintColor),
              const SizedBox(width: 6),
              Text('搜索历史',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.hintColor)),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: Text('清除',
                    style:
                        TextStyle(fontSize: 12, color: colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.map((query) {
              return ActionChip(
                label: Text(query, style: const TextStyle(fontSize: 13)),
                onPressed: () {
                  _searchController.text = query;
                  _onSearchChanged(query);
                },
                avatar: Icon(LucideIcons.search, size: 14),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, FileModel file) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _onResultTap(file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            FileIconUtils.buildIconWidget(context: context, file: file),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Uri.decodeComponent(file.relativePath),
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              file.isFolder
                  ? '文件夹'
                  : date_utils.DateUtils.formatFileSize(file.size),
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
