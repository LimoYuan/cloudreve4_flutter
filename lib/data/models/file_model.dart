import 'share_model.dart';

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
      size: (json['size'] as num?)?.toInt() ?? 0,
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

  FileModel copyWith({
    int? type,
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? size,
    String? path,
    Map<String, dynamic>? metadata,
    String? permission,
    String? primaryEntity,
    String? capability,
    bool? owned,
  }) {
    return FileModel(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      size: size ?? this.size,
      path: path ?? this.path,
      metadata: metadata ?? this.metadata,
      permission: permission ?? this.permission,
      primaryEntity: primaryEntity ?? this.primaryEntity,
      capability: capability ?? this.capability,
      owned: owned ?? this.owned,
    );
  }

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
      size: (json['size'] as num?)?.toInt() ?? 0,
      files: (json['files'] as num?)?.toInt() ?? 0,
      folders: (json['folders'] as num?)?.toInt() ?? 0,
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
  final StoragePolicyModel? storagePolicy;
  final int? storageUsed;
  final List<ShareModel>? shares;
  final List<EntityModel>? entities;
  final List<DirectLinkModel>? directLinks;

  ExtendedInfoModel({
    this.storagePolicy,
    this.storageUsed,
    this.shares,
    this.entities,
    this.directLinks,
  });

  factory ExtendedInfoModel.fromJson(Map<String, dynamic> json) {
    return ExtendedInfoModel(
      storagePolicy: json['storage_policy'] is Map<String, dynamic>
          ? StoragePolicyModel.fromJson(json['storage_policy'] as Map<String, dynamic>)
          : null,
      storageUsed: (json['storage_used'] as num?)?.toInt(),
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
      'storage_policy': storagePolicy?.toJson(),
      'storage_used': storageUsed,
      'shares': shares?.map((e) => e.toJson()).toList(),
      'entities': entities?.map((e) => e.toJson()).toList(),
      'direct_links': directLinks?.map((e) => e.toJson()).toList(),
    };
  }
}


/// 存储策略模型
class StoragePolicyModel {
  final String id;
  final String name;
  final String type;
  final int? maxSize;

  StoragePolicyModel({
    required this.id,
    required this.name,
    required this.type,
    this.maxSize,
  });

  factory StoragePolicyModel.fromJson(Map<String, dynamic> json) {
    return StoragePolicyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      maxSize: (json['max_size'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'max_size': maxSize,
    };
  }
}

/// 实体创建者模型
class EntityCreatedByModel {
  final String id;
  final String nickname;
  final String? avatar;
  final DateTime createdAt;

  EntityCreatedByModel({
    required this.id,
    required this.nickname,
    this.avatar,
    required this.createdAt,
  });

  factory EntityCreatedByModel.fromJson(Map<String, dynamic> json) {
    return EntityCreatedByModel(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      avatar: json['avatar'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 实体模型（文件版本/Blob）
class EntityModel {
  final String id;
  final int type;
  final DateTime createdAt;
  final int size;
  final String? encryptedWith;
  final StoragePolicyModel? storagePolicy;
  final EntityCreatedByModel? createdBy;

  EntityModel({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.size,
    this.encryptedWith,
    this.storagePolicy,
    this.createdBy,
  });

  factory EntityModel.fromJson(Map<String, dynamic> json) {
    return EntityModel(
      id: json['id'] as String,
      type: json['type'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      size: (json['size'] as num?)?.toInt() ?? 0,
      encryptedWith: json['encrypted_with'] as String?,
      storagePolicy: json['storage_policy'] is Map<String, dynamic>
          ? StoragePolicyModel.fromJson(json['storage_policy'] as Map<String, dynamic>)
          : null,
      createdBy: json['created_by'] is Map<String, dynamic>
          ? EntityCreatedByModel.fromJson(json['created_by'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'size': size,
      'encrypted_with': encryptedWith,
      'storage_policy': storagePolicy?.toJson(),
      'created_by': createdBy?.toJson(),
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
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
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

/// 文件详情模型（/file/info 接口返回）
class FileInfoModel {
  final FileModel file;
  final FolderSummaryModel? folderSummary;
  final ExtendedInfoModel? extendedInfo;

  FileInfoModel({
    required this.file,
    this.folderSummary,
    this.extendedInfo,
  });

  factory FileInfoModel.fromJson(Map<String, dynamic> json) {
    return FileInfoModel(
      file: FileModel.fromJson(json),
      folderSummary: json['folder_summary'] is Map<String, dynamic>
          ? FolderSummaryModel.fromJson(json['folder_summary'] as Map<String, dynamic>)
          : null,
      extendedInfo: json['extended_info'] is Map<String, dynamic>
          ? ExtendedInfoModel.fromJson(json['extended_info'] as Map<String, dynamic>)
          : null,
    );
  }
}
