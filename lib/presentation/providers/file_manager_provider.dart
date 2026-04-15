import 'package:flutter/foundation.dart';
import '../../data/models/file_model.dart';
import '../../services/file_service.dart';

/// 文件视图类型
enum FileViewType { list, grid, gallery }

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

  String get currentPath => _currentPath;
  List<FileModel> get files => _files;
  List<String> get selectedFiles => _selectedFiles;
  FileViewType get viewType => _viewType;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get contextHint => _contextHint;
  bool get hasSelection => _selectedFiles.isNotEmpty;

  /// 加载文件列表
  Future<void> loadFiles({bool refresh = false}) async {
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
      );

      // ApiService._parseResponse 已经返回了 data 字段的内容
      // response 是包含 files, parent, pagination 等字段的对象
      final List<dynamic> filesData = response['files'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      debugPrint("获取files列表: $filesData");
      setState(() {
        _files = filesData
            .map((f) => FileModel.fromJson(f as Map<String, dynamic>))
            .toList();
        _hasMore = pagination['next_token'] != null;
        _contextHint = response['context_hint'] as String?;
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
    notifyListeners();
    await loadFiles();
  }

  /// 选择/取消选择文件
  void toggleSelection(String uri) {
    if (_selectedFiles.contains(uri)) {
      _selectedFiles.remove(uri);
    } else {
      _selectedFiles.add(uri);
    }
    notifyListeners();
  }

  /// 选择所有
  void selectAll() {
    _selectedFiles = _files.map((f) => f.id).toList();
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
  Future<void> deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    try {
      await FileService().deleteFiles(uris: _selectedFiles);
      clearSelection();
      await loadFiles();
    } catch (e) {
      setErrorMessage(e.toString());
    }
  }

  /// 创建文件夹
  Future<void> createFolder(String name) async {
    try {
      // 构建 uri，将新文件夹名添加到当前路径
      String uri;
      if (_currentPath == '/' || _currentPath.isEmpty) {
        uri = '/$name';
      } else {
        uri = '$_currentPath/$name';
      }

      await FileService().createFile(
        uri: uri,
        type: 'folder',
        errOnConflict: 'true',
      );
      await loadFiles();
    } catch (e) {
      setErrorMessage(e.toString());
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

  /// 清空文件列表
  void clearFiles() {
    setState(() {
      _files = [];
      _selectedFiles = [];
      _currentPath = '/';
      _errorMessage = null;
    });
  }
}
