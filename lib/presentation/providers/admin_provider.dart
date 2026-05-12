import 'package:flutter/foundation.dart';
import '../../data/models/admin_model.dart';
import '../../services/admin_service.dart';
import '../../core/utils/app_logger.dart';

enum AdminState { idle, loading, error }

/// 管理员数据 Provider
class AdminProvider extends ChangeNotifier {
  AdminState _state = AdminState.idle;
  List<AdminGroupModel> _groups = [];
  List<AdminUserModel> _users = [];
  PaginationModel? _groupsPagination;
  PaginationModel? _usersPagination;
  String? _errorMessage;

  // 用户多选状态
  final Set<int> _selectedUserIds = {};
  bool _isSelectingUsers = false;

  AdminState get state => _state;
  List<AdminGroupModel> get groups => _groups;
  List<AdminUserModel> get users => _users;
  PaginationModel? get groupsPagination => _groupsPagination;
  PaginationModel? get usersPagination => _usersPagination;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AdminState.loading;
  Set<int> get selectedUserIds => _selectedUserIds;
  bool get isSelectingUsers => _isSelectingUsers;
  bool get hasSelectedUsers => _selectedUserIds.isNotEmpty;

  final AdminService _service = AdminService.instance;

  /// 加载用户组列表
  Future<void> loadGroups({int page = 1}) async {
    try {
      final response = await _service.getGroups(page: page);
      _groups = response.groups;
      _groupsPagination = response.pagination;
      notifyListeners();
    } catch (e) {
      AppLogger.d('加载用户组失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 加载用户列表
  Future<void> loadUsers({int page = 1}) async {
    try {
      final response = await _service.getUsers(page: page);
      _users = response.users;
      _usersPagination = response.pagination;
      notifyListeners();
    } catch (e) {
      AppLogger.d('加载用户列表失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// 加载全部管理员数据
  Future<void> loadAll() async {
    _setState(AdminState.loading);
    try {
      await Future.wait([
        loadGroups(),
        loadUsers(),
      ]);
      _setState(AdminState.idle);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AdminState.error);
    }
  }

  /// 创建用户组
  Future<bool> createGroup(String name) async {
    try {
      final group = await _service.createGroup(name);
      _groups.insert(0, group);
      if (_groupsPagination != null) {
        _groupsPagination = PaginationModel(
          page: _groupsPagination!.page,
          pageSize: _groupsPagination!.pageSize,
          totalItems: _groupsPagination!.totalItems + 1,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('创建用户组失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除用户组（会先检查组下是否有用户）
  Future<String?> deleteGroup(int groupId) async {
    try {
      final detail = await _service.getGroupDetail(groupId);
      if ((detail.totalUsers ?? 0) > 0) {
        return '该组下有 ${detail.totalUsers} 个用户，请先删除或迁移用户';
      }
      await _service.deleteGroup(groupId);
      _groups.removeWhere((g) => g.id == groupId);
      if (_groupsPagination != null) {
        _groupsPagination = PaginationModel(
          page: _groupsPagination!.page,
          pageSize: _groupsPagination!.pageSize,
          totalItems: _groupsPagination!.totalItems - 1,
        );
      }
      notifyListeners();
      return null;
    } catch (e) {
      AppLogger.d('删除用户组失败: $e');
      return e.toString();
    }
  }

  /// 创建用户
  Future<bool> createUser({
    required String email,
    required String nick,
    required String password,
    required int groupId,
  }) async {
    try {
      final user = await _service.createUser(
        email: email,
        nick: nick,
        password: password,
        groupId: groupId,
      );
      _users.insert(0, user);
      if (_usersPagination != null) {
        _usersPagination = PaginationModel(
          page: _usersPagination!.page,
          pageSize: _usersPagination!.pageSize,
          totalItems: _usersPagination!.totalItems + 1,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('创建用户失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 批量删除用户
  Future<bool> batchDeleteUsers(List<int> ids) async {
    try {
      await _service.batchDeleteUsers(ids);
      _users.removeWhere((u) => ids.contains(u.id));
      if (_usersPagination != null) {
        _usersPagination = PaginationModel(
          page: _usersPagination!.page,
          pageSize: _usersPagination!.pageSize,
          totalItems: _usersPagination!.totalItems - ids.length,
        );
      }
      exitSelectMode();
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('批量删除用户失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // --- 多选模式 ---

  void toggleSelectMode() {
    _isSelectingUsers = !_isSelectingUsers;
    if (!_isSelectingUsers) {
      _selectedUserIds.clear();
    }
    notifyListeners();
  }

  void exitSelectMode() {
    _isSelectingUsers = false;
    _selectedUserIds.clear();
    notifyListeners();
  }

  void toggleUserSelection(int userId) {
    if (_selectedUserIds.contains(userId)) {
      _selectedUserIds.remove(userId);
    } else {
      _selectedUserIds.add(userId);
    }
    notifyListeners();
  }

  void selectAllUsers() {
    _selectedUserIds.clear();
    _selectedUserIds.addAll(_users.map((u) => u.id));
    notifyListeners();
  }

  void clearUserSelection() {
    _selectedUserIds.clear();
    notifyListeners();
  }

  bool isUserSelected(int userId) => _selectedUserIds.contains(userId);

  void _setState(AdminState state) {
    _state = state;
    notifyListeners();
  }
}
