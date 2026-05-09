import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../data/models/file_model.dart';
import '../../services/file_service.dart';
import '../../services/thumbnail_service.dart';
import '../../core/utils/app_logger.dart';

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
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _contextHint;
  String? _highlightPath;
  Timer? _highlightTimer;

  String get currentPath => _currentPath;
  List<FileModel> get files => _files;
  List<String> get selectedFiles => _selectedFiles;
  FileViewType get viewType => _viewType;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get contextHint => _contextHint;
  bool get hasSelection => _selectedFiles.isNotEmpty;
  String? get highlightPath => _highlightPath;

  /// 加载文件列表
  Future<void> loadFiles({bool refresh = false, Duration timeout = const Duration(seconds: 5)}) async {
    if (refresh) {
      _selectedFiles.clear();
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 50,
      ).timeout(timeout);

      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      AppLogger.d("获取files列表: $filesData");
      setState(() {
        _files = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .toList();
        _hasMore = pagination['next_token'] != null;
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

  /// 进入文件夹
  Future<void> enterFolder(String path) async {
    _currentPath = path;
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
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
    _selectedFiles.clear();
    _highlightPath = null;
    _highlightTimer?.cancel();
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

  /// 切换视图类型
  void setViewType(FileViewType type) {
    _viewType = type;
    notifyListeners();
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

  /// 移动文件
  Future<void> moveFiles(List<String> uris, String destination) async {
    try {
      await FileService().moveFiles(uris: uris, dst: destination);
      clearSelection();
      await loadFiles();
    } catch (e) {
      setErrorMessage(e.toString());
    }
  }

  /// 重命名文件
  Future<void> renameFile(String path, String newName) async {
    try {
      await FileService().renameFile(uri: path, newName: newName);
      await loadFiles();
    } catch (e) {
      setErrorMessage(e.toString());
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

  /// 清空文件列表
  void clearFiles() {
    setState(() {
      _files = [];
      _selectedFiles = [];
      _currentPath = '/';
      _errorMessage = null;
    });
  }

  /// 智能刷新 - 只更新差异部分
  Future<RefreshResult> refreshFiles({Duration timeout = const Duration(seconds: 5)}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await FileService().listFiles(
        uri: _currentPath,
        pageSize: 50,
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

      setState(() {
        _files = updatedFiles;
        _hasMore = response['pagination']?['next_token'] != null;
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
