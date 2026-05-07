import '../data/models/admin_model.dart';
import 'api_service.dart';

/// 管理员服务
class AdminService {
  AdminService._internal();
  static final AdminService _instance = AdminService._internal();
  static AdminService get instance => _instance;

  /// 获取用户组列表
  Future<AdminGroupListResponse> getGroups({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/admin/group',
      data: {
        'page': page,
        'page_size': pageSize,
        'order_by': '',
        'order_direction': 'desc',
      },
    );
    return AdminGroupListResponse.fromJson(response);
  }

  /// 获取用户列表
  Future<AdminUserListResponse> getUsers({
    int page = 1,
    int pageSize = 10,
    Map<String, dynamic>? conditions,
  }) async {
    final data = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'order_by': '',
      'order_direction': 'desc',
    };
    if (conditions != null) data['conditions'] = conditions;

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/admin/user',
      data: data,
    );
    return AdminUserListResponse.fromJson(response);
  }
}
