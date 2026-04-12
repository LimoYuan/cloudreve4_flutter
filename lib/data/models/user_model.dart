/// 用户模型
class UserModel {
  final String id;
  final String? email;
  final String nickname;
  final String? avatar;
  final DateTime createdAt;
  final String? preferredTheme;
  final String? language;
  final bool? anonymous;
  final GroupModel? group;
  final List<PinedFileModel>? pined;

  UserModel({
    required this.id,
    this.email,
    required this.nickname,
    this.avatar,
    required this.createdAt,
    this.preferredTheme,
    this.language,
    this.anonymous,
    this.group,
    this.pined,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String,
      avatar: json['avatar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      preferredTheme: json['preferred_theme'] as String?,
      language: json['language'] as String?,
      anonymous: json['anonymous'] as bool?,
      group: json['group'] != null
          ? GroupModel.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      pined: json['pined'] != null
          ? (json['pined'] as List)
              .map((e) => PinedFileModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
      'preferred_theme': preferredTheme,
      'language': language,
      'anonymous': anonymous,
      'group': group?.toJson(),
      'pined': pined?.map((e) => e.toJson()).toList(),
    };
  }
}

/// 用户组模型
class GroupModel {
  final String id;
  final String name;
  final String? permission;
  final int? directLinkBatchSize;
  final int? trashRetention;

  GroupModel({
    required this.id,
    required this.name,
    this.permission,
    this.directLinkBatchSize,
    this.trashRetention,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      permission: json['permission'] as String?,
      directLinkBatchSize: json['direct_link_batch_size'] as int?,
      trashRetention: json['trash_retention'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'permission': permission,
      'direct_link_batch_size': directLinkBatchSize,
      'trash_retention': trashRetention,
    };
  }
}

/// 固定文件模型
class PinedFileModel {
  final String uri;
  final String? name;

  PinedFileModel({
    required this.uri,
    this.name,
  });

  factory PinedFileModel.fromJson(Map<String, dynamic> json) {
    return PinedFileModel(
      uri: json['uri'] as String,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
    };
  }
}

/// Token模型
class TokenModel {
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpires;
  final DateTime refreshExpires;

  TokenModel({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpires,
    required this.refreshExpires,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessExpires: DateTime.parse(json['access_expires'] as String),
      refreshExpires: DateTime.parse(json['refresh_expires'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_expires': accessExpires.toIso8601String(),
      'refresh_expires': refreshExpires.toIso8601String(),
    };
  }
}

/// 用户容量模型
class CapacityModel {
  final int total;
  final int used;
  double get usagePercentage => total > 0 ? (used / total) * 100 : 0;

  int get remaining => total - used;

  CapacityModel({
    required this.total,
    required this.used,
  });

  factory CapacityModel.fromJson(Map<String, dynamic> json) {
    return CapacityModel(
      total: json['total'] as int,
      used: json['used'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'used': used,
    };
  }
}
