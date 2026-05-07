// 管理员相关数据模型

class PaginationModel {
  final int page;
  final int pageSize;
  final int totalItems;

  PaginationModel({
    required this.page,
    required this.pageSize,
    required this.totalItems,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: json['page'] as int? ?? 0,
      pageSize: json['page_size'] as int? ?? 10,
      totalItems: json['total_items'] as int? ?? 0,
    );
  }
}

/// 管理员用户组模型
class AdminGroupModel {
  final int id;
  final String name;
  final String? permissions;
  final Map<String, dynamic>? settings;
  final int? maxStorage;
  final int? storagePolicyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? storagePolicy;

  AdminGroupModel({
    required this.id,
    required this.name,
    this.permissions,
    this.settings,
    this.maxStorage,
    this.storagePolicyId,
    this.createdAt,
    this.updatedAt,
    this.storagePolicy,
  });

  factory AdminGroupModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? storagePolicy;
    if (json['edges'] is Map && json['edges']['storage_policies'] is Map) {
      storagePolicy = json['edges']['storage_policies'] as Map<String, dynamic>;
    }

    return AdminGroupModel(
      id: json['id'] as int,
      name: json['name'] as String,
      permissions: json['permissions'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
      maxStorage: json['max_storage'] as int?,
      storagePolicyId: json['storage_policy_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      storagePolicy: storagePolicy,
    );
  }

  /// 格式化最大存储空间
  String get formattedMaxStorage {
    if (maxStorage == null) return '无限制';
    return _formatBytes(maxStorage!);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 管理员用户模型
class AdminUserModel {
  final int id;
  final String email;
  final String nick;
  final String status;
  final String? avatar;
  final int? storage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? hashId;
  final int? groupUsers;
  final AdminGroupModel? group;

  AdminUserModel({
    required this.id,
    required this.email,
    required this.nick,
    required this.status,
    this.avatar,
    this.storage,
    this.createdAt,
    this.updatedAt,
    this.hashId,
    this.groupUsers,
    this.group,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    AdminGroupModel? group;
    if (json['edges'] is Map && json['edges']['group'] is Map) {
      group = AdminGroupModel.fromJson(
          json['edges']['group'] as Map<String, dynamic>);
    }

    return AdminUserModel(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      nick: json['nick'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      avatar: json['avatar'] as String?,
      storage: json['storage'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      hashId: json['hash_id'] as String?,
      groupUsers: json['group_users'] as int?,
      group: group,
    );
  }

  /// 获取用户头像首字母
  String get initial => nick.isNotEmpty ? nick[0].toUpperCase() : 'U';

  /// 格式化已用存储空间
  String get formattedStorage {
    if (storage == null) return '未知';
    return _formatBytes(storage!);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 管理员用户组列表响应
class AdminGroupListResponse {
  final List<AdminGroupModel> groups;
  final PaginationModel pagination;

  AdminGroupListResponse({required this.groups, required this.pagination});

  factory AdminGroupListResponse.fromJson(Map<String, dynamic> json) {
    return AdminGroupListResponse(
      groups: (json['groups'] as List?)
              ?.map((e) => AdminGroupModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationModel.fromJson(
          json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// 管理员用户列表响应
class AdminUserListResponse {
  final List<AdminUserModel> users;
  final PaginationModel pagination;

  AdminUserListResponse({required this.users, required this.pagination});

  factory AdminUserListResponse.fromJson(Map<String, dynamic> json) {
    return AdminUserListResponse(
      users: (json['users'] as List?)
              ?.map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationModel.fromJson(
          json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}
