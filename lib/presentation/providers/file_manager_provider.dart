import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../data/models/file_model.dart';
import '../../services/file_service.dart';
import '../../services/storage_service.dart';
import '../../services/thumbnail_service.dart';
import '../../core/constants/sort_options.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/file_utils.dart';

/// 文件视图类型
enum FileViewType { list, grid, gallery }

/// 刷新结果
class RefreshResult {
  final int added;
  final int removed;
  final int updated;
  const RefreshResult({required this.added, required this.removed, required this.updated});
  bool get isUnchanged => added == 0 && removed == 0 && updated == 0;
}

/// 文件管理Provider
class FileManagerProvider extends ChangeNotifier {
  String _currentPath = '/';
  List<FileModel> _files = [];
  List<String> _selectedFiles = [];
  FileViewType _viewType = FileViewType.list;
  SortOption _sortOption = SortOption.default_;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextPageToken;
  String? _errorMessage;
  String? _contextHint;
  String? _highlightPath;
  Timer? _highlightTimer;

  /// 桌面首页"转存文件"列表（shared_with_me）
  List<FileModel> _transferredFiles = [];
  List<FileModel> get transferredFiles => _transferredFiles;

  /// 当前桌面分类 Tab 选中项；null 表示"全部"（默认）。
  /// 可选值: null / 'recent' / 'document' / 'image' / 'video' / 'audio'
  String? _activeCategory;

  String get currentPath => _currentPath;
  List<FileModel> get files => _files;
  List<String> get selectedFiles => _selectedFiles;
  FileViewType get viewType => _viewType;
  SortOption get sortOption => _sortOption;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get nextPageToken => _nextPageToken;
  String? get errorMessage => _errorMessage;
  String? get contextHint => _contextHint;
  bool get hasSelection => _selectedFiles.isNotEmpty;
  String? get highlightPath => _highlightPath;
  String? get activeCategory => _activeCategory;

  /// 加载文件列表
  Future<void> loadFiles({bool refresh = false, Duration timeout = const Duration(seconds: 5)}) async {
    if (refresh) {
      _selectedFiles.clear();
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _nextPageToken = null;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 50,
        orderBy: _sortOption.field.apiKey,
        orderDirection: _sortOption.direction.apiKey,
      ).timeout(timeout);

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      AppLogger.d("获取files列表: $filesData");
      setState(() {
        _files = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .toList();
        _nextPageToken = pagination['next_token'] as String?;
        _hasMore = _nextPageToken != null;
        _contextHint = response['context_hint'] as String?;
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = '加载超时，请检查网络后重试';
        _hasMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _hasMore = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载更多文件（分页）
  Future<void> loadMoreFiles({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isLoadingMore || _nextPageToken == null) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 50,
        orderBy: _sortOption.field.apiKey,
        orderDirection: _sortOption.direction.apiKey,
        nextPageToken: _nextPageToken,
      ).timeout(timeout);

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      final newFiles = filesData
          .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
          .toList();

      setState(() {
        final existingIds = _files.map((e) => e.id).toSet();
        _files.addAll(newFiles.where((f) => !existingIds.contains(f.id)));
        _nextPageToken = pagination['next_token'] as String?;
        _hasMore = _nextPageToken != null;
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = '加载更多超时，请重试';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// 进入文件夹
  Future<void> enterFolder(String path) async {
    _currentPath = path;
    _activeCategory = null; // 离开根目录时重置分类
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
    _nextPageToken = null;
    ThumbnailService.instance.clearAll();
    await loadFiles();
  }

  /// 返回上级
  Future<void> goBack() async {
    if (_currentPath == '/' || _currentPath.isEmpty) return;

    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      _currentPath = parts.join('/');
    } else {
      _currentPath = '/';
    }
    if (_currentPath.isEmpty) _currentPath = '/';
    // 返回根目录时重置分类
    _activeCategory = null;
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
    _nextPageToken = null;
    ThumbnailService.instance.clearAll();
    notifyListeners();
    await loadFiles();
  }

  /// 选择/取消选择文件
  void toggleSelection(String path) {
    if (_selectedFiles.contains(path)) {
      _selectedFiles.remove(path);
    } else {
      _selectedFiles.add(path);
    }
    notifyListeners();
  }

  /// 选择所有
  void selectAll() {
    _selectedFiles = _files.map((f) => f.path).toList();
    notifyListeners();
  }

  /// 清除选择
  void clearSelection() {
    _selectedFiles.clear();
    notifyListeners();
  }

  /// 切换视图类型并持久化
  Future<void> setViewType(FileViewType type) async {
    if (_viewType == type) return;
    _viewType = type;
    notifyListeners();
    await StorageService.instance.setString(StorageKeys.fileViewType, type.name);
  }

  /// 从持久化恢复视图偏好
  Future<void> restoreViewType() async {
    final name = await StorageService.instance.getString(StorageKeys.fileViewType);
    if (name != null) {
      final type = FileViewType.values.where((v) => v.name == name).firstOrNull;
      if (type != null && type != _viewType) {
        _viewType = type;
        notifyListeners();
      }
    }
  }

  /// 设置排序选项并重新加载
  Future<void> setSortOption(SortOption option) async {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
    await StorageService.instance.setString(StorageKeys.fileSortOption, option.toKey());
    await loadFiles(refresh: true);
  }

  /// 从持久化恢复排序偏好
  Future<void> restoreSortOption() async {
    final key = await StorageService.instance.getString(StorageKeys.fileSortOption);
    final option = SortOption.fromKey(key);
    if (option != _sortOption) {
      _sortOption = option;
      notifyListeners();
    }
  }

  /// 设置错误信息
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 设置状态
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// 删除选中的文件
  Future<String?> deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return null;

    try {
      AppLogger.d("删除文件: ${_selectedFiles.join(', ')}");
      await FileService().deleteFiles(uris: _selectedFiles);

      setState(() {
        _files.removeWhere((file) => _selectedFiles.contains(file.path));
      });

      clearSelection();
      return null;
    } catch (e) {
      final error = e.toString();
      setErrorMessage(error);
      return error;
    }
  }

  /// 创建文件夹
  Future<String?> createFolder(String name) async {
    try {
      String uri;
      if (_currentPath == '/' || _currentPath.isEmpty) {
        uri = '/$name';
      } else {
        uri = '$_currentPath/$name';
      }

      final response = await FileService().createFile(
        uri: uri,
        type: 'folder',
        errOnConflict: true,
      );

      final newFolder = FileModel.fromJson(response);

      setState(() {
        _files.insert(0, newFolder);
      });

      return null;
    } catch (e) {
      final error = e.toString();
      setErrorMessage(error);
      return error;
    }
  }

  /// 删除单个文件（增量移除）
  Future<String?> deleteFile(String path) async {
    try {
      await FileService().deleteFiles(uris: [path]);
      setState(() {
        _files.removeWhere((file) => file.path == path);
        _selectedFiles.remove(path);
      });
      return null;
    } catch (e) {
      final error = e.toString();
      setErrorMessage(error);
      return error;
    }
  }

  /// 移动文件（增量更新）
  Future<String?> moveFiles(List<String> uris, String destination, {bool copy = false}) async {
    try {
      await FileService().moveFiles(uris: uris, dst: destination);
      clearSelection();

      if (!copy) {
        // 移动：文件离开当前目录，直接从列表移除
        setState(() {
          _files.removeWhere((file) => uris.contains(file.path));
        });
      } else {
        // 复制：仅当目标是当前目录时需要刷新
        final normalizedDst = FileUtils.toCloudreveUri(destination);
        final normalizedCur = FileUtils.toCloudreveUri(_currentPath);
        if (normalizedDst == normalizedCur) {
          await loadFiles();
        }
      }
      return null;
    } catch (e) {
      final error = e.toString();
      setErrorMessage(error);
      return error;
    }
  }

  /// 重命名文件（原地更新，不刷新列表）
  Future<String?> renameFile(String path, String newName) async {
    try {
      final response = await FileService().renameFile(uri: path, newName: newName);
      if (response.isEmpty) {
        await loadFiles();
        return null;
      }
      final updatedFile = FileModel.fromJson(response);
      final index = _files.indexWhere((f) => f.path == path);
      if (index != -1) {
        setState(() {
          _files[index] = updatedFile;
        });
      }
      return null;
    } catch (e) {
      final error = e.toString();
      setErrorMessage(error);
      return error;
    }
  }

  /// 通过 URI 获取文件信息并添加到列表（用于上传完成后）
  Future<void> addFileByUri(String fileUri) async {
    try {
      final response = await FileService().getFileInfo(uri: fileUri);
      final newFile = FileModel.fromJson(response);
      final exists = _files.any((f) => f.id == newFile.id);
      if (!exists) {
        setState(() {
          _files.insert(0, newFile);
        });
      }
    } catch (e) {
      AppLogger.d('获取上传文件信息失败: $e');
    }
  }

  /// 高亮指定文件路径（3 秒后自动清除）
  void setHighlightPath(String? path) {
    _highlightTimer?.cancel();
    _highlightPath = path;
    notifyListeners();
    if (path != null) {
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        _highlightPath = null;
        notifyListeners();
      });
    }
  }

  /// 导航到指定文件夹并高亮目标文件
  Future<void> navigateAndHighlight(String folderPath, String filePath) async {
    _currentPath = folderPath;
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
    await loadFiles();
    setHighlightPath(filePath);
  }

  /// 设置桌面端分类 Tab；切换后自动加载对应文件。
  Future<void> setActiveCategory(String? category) async {
    if (_activeCategory == category) return;
    _activeCategory = category;
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
    notifyListeners();

    if (category == null) {
      // "全部" → 恢复常规目录加载
      await loadFiles();
    } else if (category == 'recent') {
      // "最近" → 加载根目录文件后按 updatedAt 排序
      await loadFiles();
      _sortRecentFiles();
    } else {
      // 按分类加载
      await _loadFilesByCategory(category);
    }
  }

  /// 按 Cloudreve V4 分类加载文件（桌面端 Tab 过滤）。
  Future<void> _loadFilesByCategory(String category, {Duration timeout = const Duration(seconds: 5)}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _nextPageToken = null;
    });

    try {
      final response = await FileService().listFilesByCategory(
        category: category,
        pageSize: 50,
        orderBy: _sortOption.field.apiKey,
        orderDirection: _sortOption.direction.apiKey,
      ).timeout(timeout);

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        _files = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .toList();
        _nextPageToken = pagination['next_token'] as String?;
        _hasMore = _nextPageToken != null;
        _contextHint = response['context_hint'] as String?;
      });
    } on TimeoutException {
      setState(() {
        _errorMessage = '加载超时，请检查网络后重试';
        _hasMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _hasMore = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 按 updatedAt 降序排列当前文件列表（用于"最近"Tab）。
  void _sortRecentFiles() {
    final sorted = List<FileModel>.from(_files)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    setState(() {
      _files = sorted;
    });
  }

  /// 加载"转存文件"（shared_with_me），用于桌面首页概览右侧。
  Future<void> loadTransferredFiles() async {
    try {
      final response = await FileService().listSharedWithMeFiles(pageSize: 20);
      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      setState(() {
        _transferredFiles = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // 转存文件加载失败不影响主流程
    }
  }

  /// 清空文件列表
  void clearFiles() {
    setState(() {
      _files = [];
      _selectedFiles = [];
      _currentPath = '/';
      _errorMessage = null;
      _nextPageToken = null;
      _hasMore = true;
    });
  }

  /// 智能刷新 - 只更新差异部分（仅刷新首页）
  Future<RefreshResult> refreshFiles({Duration timeout = const Duration(seconds: 5)}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 50,
        orderBy: _sortOption.field.apiKey,
        orderDirection: _sortOption.direction.apiKey,
      ).timeout(timeout);

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final newFiles = filesData
          .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
          .toList();

      final currentMap = <String, FileModel>{};
      for (final file in _files) {
        currentMap[file.path] = file;
      }

      final newMap = <String, FileModel>{};
      for (final file in newFiles) {
        newMap[file.path] = file;
      }

      int added = 0;
      int removed = 0;
      int updated = 0;

      final updatedFiles = <FileModel>[];

      for (final file in newFiles) {
        final existingFile = currentMap[file.path];
        if (existingFile != null) {
          if (existingFile.updatedAt != file.updatedAt ||
              existingFile.size != file.size) {
            updatedFiles.add(file);
            updated++;
          } else {
            updatedFiles.add(existingFile);
          }
        } else {
          updatedFiles.add(file);
          added++;
        }
      }

      for (final file in _files) {
        if (!newMap.containsKey(file.path)) {
          removed++;
        }
      }

      final pagination = response['pagination'] as Map<String, dynamic>?;
      setState(() {
        _files = updatedFiles;
        _nextPageToken = pagination?['next_token'] as String?;
        _hasMore = _nextPageToken != null;
        _contextHint = response['context_hint'] as String?;
      });

      return RefreshResult(added: added, removed: removed, updated: updated);
    } on TimeoutException {
      setState(() {
        _errorMessage = '加载超时，请检查网络后重试';
      });
      return const RefreshResult(added: 0, removed: 0, updated: 0);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      return const RefreshResult(added: 0, removed: 0, updated: 0);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }
}
