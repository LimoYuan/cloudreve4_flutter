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

  /// 创建用户组
  Future<AdminGroupModel> createGroup(String name) async {
    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/admin/group',
      data: {
        'group': {
          'name': name,
          'permissions': 'hA==',
          'max_storage': 1073741824,
          'settings': {
            'compress_size': 1073741824,
            'decompress_size': 1073741824,
            'max_walked_files': 100000,
            'trash_retention': 604800,
            'source_batch': 10,
            'aria2_batch': 1,
            'redirected_source': true,
          },
          'edges': {
            'storage_policies': {'id': 1},
          },
          'id': 0,
        },
      },
    );
    return AdminGroupModel.fromJson(response);
  }

  /// 获取用户组详情（含用户数量）
  Future<AdminGroupModel> getGroupDetail(int groupId) async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/admin/group/$groupId',
      queryParameters: {'countUser': 'true'},
    );
    return AdminGroupModel.fromJson(response);
  }

  /// 删除用户组
  Future<void> deleteGroup(int groupId) async {
    await ApiService.instance.delete<void>(
      '/admin/group/$groupId',
    );
  }

  /// 创建用户
  Future<AdminUserModel> createUser({
    required String email,
    required String nick,
    required String password,
    required int groupId,
  }) async {
    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/admin/user',
      data: {
        'user': {
          'edges': {},
          'id': 0,
          'email': email,
          'nick': nick,
          'password': password,
          'status': 'active',
          'group_users': groupId,
        },
        'password': password,
      },
    );
    return AdminUserModel.fromJson(response);
  }

  /// 批量删除用户
  Future<void> batchDeleteUsers(List<int> ids) async {
    await ApiService.instance.post<void>(
      '/admin/user/batch/delete',
      data: {'ids': ids},
    );
  }
}
