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
import '../../core/exceptions/app_exception.dart';

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

  String? _readNextPageToken(Map<String, dynamic>? pagination) {
    if (pagination == null || pagination.isEmpty) return null;
    final raw = pagination['next_token'] ??
        pagination['next_page_token'] ??
        pagination['nextPageToken'] ??
        pagination['next'] ??
        pagination['cursor'];
    final token = raw?.toString().trim();
    return token == null || token.isEmpty ? null : token;
  }

  String _fileIdentity(FileModel file) {
    // Prefer path/URI because some API payloads can omit or reuse id across
    // pages. De-duplicating only by id may drop the last visible item/page.
    final path = file.path.trim();
    if (path.isNotEmpty && path != '/') return path;
    final id = file.id.trim();
    if (id.isNotEmpty) return id;
    return file.name;
  }

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
        _nextPageToken = _readNextPageToken(pagination);
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
        final existingKeys = _files.map(_fileIdentity).toSet();
        _files.addAll(newFiles.where((f) => !existingKeys.contains(_fileIdentity(f))));
        _nextPageToken = _readNextPageToken(pagination);
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
  ///
  /// 创建文件夹属于一次性操作错误，不应该污染文件列表的全局
  /// [_errorMessage]。否则服务端返回 40004(Object existed) 时，
  /// 移动端会从正常列表跳到整页错误态。
  Future<String?> createFolder(String name) async {
    final normalizedName = _normalizeCreateName(name);
    if (normalizedName == null) {
      return '文件夹名称不能为空';
    }
    if (!_isSafePathName(normalizedName)) {
      return '文件夹名称不能包含 / 或 \\，也不能使用 . 或 ..';
    }

    final existedLocally = _files.any(
      (file) => file.name.trim() == normalizedName,
    );
    if (existedLocally) {
      return '同名文件或文件夹已存在，请换一个名称';
    }

    final uri = _joinCurrentPath(normalizedName);

    try {
      final response = await FileService().createFile(
        uri: uri,
        type: 'folder',
        errOnConflict: true,
      );

      final newFolder = FileModel.fromJson(response);

      setState(() {
        _errorMessage = null;
        _files.removeWhere((file) => _fileIdentity(file) == _fileIdentity(newFolder));
        _files.insert(0, newFolder);
      });

      return null;
    } catch (e) {
      // Cloudreve V4: code 40004 / Object existed。这里只返回给调用方做
      // toast 提示，不要 setErrorMessage，避免整页显示 AppException。
      if (_isObjectExistedError(e)) {
        unawaited(loadFiles(refresh: true));
        return '同名文件或文件夹已存在，请换一个名称';
      }

      AppLogger.d('Create folder failed: $e');
      return _friendlyCreateFolderError(e);
    }
  }

  String? _normalizeCreateName(String name) {
    final normalized = name.trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool _isSafePathName(String name) {
    if (name == '.' || name == '..') return false;
    return !name.contains('/') && !name.contains('\\');
  }

  String _joinCurrentPath(String childName) {
    final base = _currentPath.trim();
    if (base.isEmpty || base == '/') return '/$childName';
    return base.endsWith('/') ? '$base$childName' : '$base/$childName';
  }

  bool _isObjectExistedError(Object error) {
    if (error is AppException && error.code == 40004) return true;
    final text = error.toString().toLowerCase();
    return text.contains('40004') ||
        text.contains('object existed') ||
        text.contains('object exists') ||
        text.contains('already exists') ||
        text.contains('已存在');
  }

  String _friendlyCreateFolderError(Object error) {
    if (error is AppException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    final text = error.toString();
    return text;
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

  String _fileNameFromUri(String fileUri) {
    final clean = fileUri.split('?').first.replaceAll(RegExp(r'/+$'), '');
    final nameParts = clean
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final rawName = nameParts.isEmpty ? null : nameParts.last;
    if (rawName == null || rawName.trim().isEmpty || rawName == 'my') {
      return '上传文件';
    }
    try {
      return Uri.decodeComponent(rawName);
    } catch (_) {
      return rawName;
    }
  }

  FileModel _optimisticUploadedFile(String fileUri) {
    final now = DateTime.now();
    return FileModel(
      type: 0,
      id: fileUri,
      name: _fileNameFromUri(fileUri),
      createdAt: now,
      updatedAt: now,
      size: 0,
      path: fileUri,
    );
  }

  void _upsertVisibleFile(FileModel file) {
    final key = _fileIdentity(file);
    final index = _files.indexWhere((existing) {
      if (existing.path == file.path) return true;
      if (existing.id.isNotEmpty && existing.id == file.id) return true;
      return _fileIdentity(existing) == key;
    });

    setState(() {
      if (index >= 0) {
        _files[index] = file;
      } else {
        // 上传完成的文件必须立即进入当前可见列表。否则当前目录已有 50 个
        // 文件时，仅刷新第一页会让第 51 个及之后的上传结果看起来“消失”。
        _files.insert(0, file);
      }
    });
  }

  Future<FileModel?> _getUploadedFileInfoWithRetry(String fileUri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }

      try {
        final response = await FileService()
            .getFileInfo(uri: fileUri)
            .timeout(const Duration(seconds: 6));
        return FileModel.fromJson(response);
      } catch (e) {
        lastError = e;
      }
    }

    AppLogger.d('获取上传文件信息失败，将先显示本地占位: $lastError');
    return null;
  }

  Future<void> _replaceUploadedPlaceholderWhenReady(String fileUri) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await FileService()
          .getFileInfo(uri: fileUri)
          .timeout(const Duration(seconds: 6));
      _upsertVisibleFile(FileModel.fromJson(response));
    } catch (e) {
      AppLogger.d('刷新上传文件占位失败: $e');
    }
  }

  /// 通过 URI 获取文件信息并添加到列表（用于上传完成后）
  Future<void> addFileByUri(String fileUri) async {
    final remoteFile = await _getUploadedFileInfoWithRetry(fileUri);
    if (remoteFile != null) {
      _upsertVisibleFile(remoteFile);
      return;
    }

    _upsertVisibleFile(_optimisticUploadedFile(fileUri));
    unawaited(_replaceUploadedPlaceholderWhenReady(fileUri));
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
    _activeCategory = null;
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
    _nextPageToken = null;
    _contextHint = null;
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
        _nextPageToken = _readNextPageToken(pagination);
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
        _nextPageToken = _readNextPageToken(pagination);
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
