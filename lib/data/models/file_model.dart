
/// 文件模型
class FileModel {
  final int type; // 0:文件, 1:文件夹
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int size;
  final String path;
  final Map<String, dynamic>? metadata;
  final String? permission;
  final String? primaryEntity;
  final String? capability;
  final bool? owned;

  FileModel({
    required this.type,
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.size,
    required this.path,
    this.metadata,
    this.permission,
    this.primaryEntity,
    this.capability,
    this.owned,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      type: json['type'] as int,
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      size: json['size'] as int,
      path: json['path'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      permission: json['permission'] as String?,
      primaryEntity: json['primary_entity'] as String?,
      capability: json['capability'] as String?,
      owned: json['owned'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'size': size,
      'path': path,
      'metadata': metadata,
      'permission': permission,
      'primary_entity': primaryEntity,
      'capability': capability,
      'owned': owned,
    };
  }

  bool get isFile => type == 0;

  bool get isFolder => type == 1;

  /// 获取相对于 cloudreve://my 的路径
  /// 例如: cloudreve://my/Games -> /Games
  /// cloudreve://my/sub/folder -> /sub/folder
  String get relativePath {
    if (!path.startsWith('cloudreve://my')) {
      // 如果不是 cloudreve://my 开头，返回空
      return '/';
    }
    final prefix = 'cloudreve://my';
    final relative = path.substring(prefix.length);
    return relative.isEmpty ? '/' : relative;
  }
}

/// 文件夹摘要模型
class FolderSummaryModel {
  final int size;
  final int files;
  final int folders;
  final bool completed;
  final DateTime calculatedAt;

  FolderSummaryModel({
    required this.size,
    required this.files,
    required this.folders,
    required this.completed,
    required this.calculatedAt,
  });

  factory FolderSummaryModel.fromJson(Map<String, dynamic> json) {
    return FolderSummaryModel(
      size: json['size'] as int,
      files: json['files'] as int,
      folders: json['folders'] as int,
      completed: json['completed'] as bool,
      calculatedAt: DateTime.parse(json['calculated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'files': files,
      'folders': folders,
      'completed': completed,
      'calculated_at': calculatedAt.toIso8601String(),
    };
  }
}

/// 扩展信息模型
class ExtendedInfoModel {
  final List<ShareModel>? shares;
  final List<EntityModel>? entities;
  final List<DirectLinkModel>? directLinks;

  ExtendedInfoModel({
    this.shares,
    this.entities,
    this.directLinks,
  });

  factory ExtendedInfoModel.fromJson(Map<String, dynamic> json) {
    return ExtendedInfoModel(
      shares: json['shares'] != null
          ? (json['shares'] as List)
              .map((e) => ShareModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      entities: json['entities'] != null
          ? (json['entities'] as List)
              .map((e) => EntityModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      directLinks: json['direct_links'] != null
          ? (json['direct_links'] as List)
              .map((e) => DirectLinkModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shares': shares?.map((e) => e.toJson()).toList(),
      'entities': entities?.map((e) => e.toJson()).toList(),
      'direct_links': directLinks?.map((e) => e.toJson()).toList(),
    };
  }
}

/// 分享模型
class ShareModel {
  final String id;
  final String? name;
  final DateTime? expires;
  final bool? isPrivate;
  final int? remainDownloads;
  final DateTime createdAt;
  final String url;
  final int visited;
  final int downloaded;
  final bool expired;
  final bool unlocked;
  final bool password;

  ShareModel({
    required this.id,
    this.name,
    this.expires,
    this.isPrivate,
    this.remainDownloads,
    required this.createdAt,
    required this.url,
    required this.visited,
    required this.downloaded,
    required this.expired,
    required this.unlocked,
    required this.password,
  });

  factory ShareModel.fromJson(Map<String, dynamic> json) {
    return ShareModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      expires: json['expires'] != null
          ? DateTime.parse(json['expires'] as String)
          : null,
      isPrivate: json['is_private'] as bool?,
      remainDownloads: json['remain_downloads'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      url: json['url'] as String,
      visited: json['visited'] as int,
      downloaded: json['downloaded'] as int,
      expired: json['expired'] as bool,
      unlocked: json['unlocked'] as bool,
      password: json['password'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'expires': expires?.toIso8601String(),
      'is_private': isPrivate,
      'remain_downloads': remainDownloads,
      'created_at': createdAt.toIso8601String(),
      'url': url,
      'visited': visited,
      'downloaded': downloaded,
      'expired': expired,
      'unlocked': unlocked,
      'password': password,
    };
  }
}

/// 实体模型
class EntityModel {
  final String id;
  final int type;
  final DateTime createdAt;
  final int size;
  final String? encryptedWith;

  EntityModel({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.size,
    this.encryptedWith,
  });

  factory EntityModel.fromJson(Map<String, dynamic> json) {
    return EntityModel(
      id: json['id'] as String,
      type: json['type'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      size: json['size'] as int,
      encryptedWith: json['encrypted_with'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'size': size,
      'encrypted_with': encryptedWith,
    };
  }
}

/// 直链模型
class DirectLinkModel {
  final String id;
  final DateTime createdAt;
  final String url;
  final int downloaded;

  DirectLinkModel({
    required this.id,
    required this.createdAt,
    required this.url,
    required this.downloaded,
  });

  factory DirectLinkModel.fromJson(Map<String, dynamic> json) {
    return DirectLinkModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      url: json['url'] as String,
      downloaded: json['downloaded'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'url': url,
      'downloaded': downloaded,
    };
  }
}
