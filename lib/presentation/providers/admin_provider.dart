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

  AdminState get state => _state;
  List<AdminGroupModel> get groups => _groups;
  List<AdminUserModel> get users => _users;
  PaginationModel? get groupsPagination => _groupsPagination;
  PaginationModel? get usersPagination => _usersPagination;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AdminState.loading;

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

  void _setState(AdminState state) {
    _state = state;
    notifyListeners();
  }
}
