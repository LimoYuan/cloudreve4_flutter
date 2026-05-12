/// 分享模型
class ShareModel {
  final String id;
  final String name;
  final int visited;
  final int? downloaded;
  final int? price;
  final bool unlocked;
  final int sourceType;
  final ShareOwner? owner;
  final DateTime createdAt;
  final DateTime? expires;
  final bool expired;
  final String url;
  final int? size;
  final SharePermissionSetting? permissionSetting;
  final bool? isPrivate;
  final String? password;
  final bool? shareView;
  final String? sourceUri;
  final bool? showReadme;
  final bool? passwordProtected;

  ShareModel({
    required this.id,
    required this.name,
    required this.visited,
    this.downloaded,
    this.price,
    required this.unlocked,
    required this.sourceType,
    this.owner,
    required this.createdAt,
    this.expires,
    required this.expired,
    required this.url,
    this.size,
    this.permissionSetting,
    this.isPrivate,
    this.password,
    this.shareView,
    this.sourceUri,
    this.showReadme,
    this.passwordProtected,
  });

  factory ShareModel.fromJson(Map<String, dynamic> json) {
    return ShareModel(
      id: json['id'] as String,
      name: json['name'] as String,
      visited: (json['visited'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt(),
      price: (json['price'] as num?)?.toInt(),
      unlocked: json['unlocked'] as bool? ?? false,
      sourceType: (json['source_type'] as num?)?.toInt() ?? 0,
      owner: json['owner'] is Map<String, dynamic>
          ? ShareOwner.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expires: json['expires'] != null
          ? DateTime.parse(json['expires'] as String)
          : null,
      expired: json['expired'] as bool? ?? false,
      url: json['url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt(),
      permissionSetting: json['permission_setting'] is Map<String, dynamic>
          ? SharePermissionSetting.fromJson(json['permission_setting'] as Map<String, dynamic>)
          : null,
      isPrivate: json['is_private'] as bool?,
      password: json['password'] as String?,
      shareView: json['share_view'] as bool?,
      sourceUri: json['source_uri'] as String?,
      showReadme: json['show_readme'] as bool?,
      passwordProtected: json['password_protected'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visited': visited,
      'downloaded': downloaded,
      'price': price,
      'unlocked': unlocked,
      'source_type': sourceType,
      'owner': owner?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'expires': expires?.toIso8601String(),
      'expired': expired,
      'url': url,
      'size': size,
      'permission_setting': permissionSetting?.toJson(),
      'is_private': isPrivate,
      'password': password,
      'share_view': shareView,
      'source_uri': sourceUri,
      'show_readme': showReadme,
      'password_protected': passwordProtected,
    };
  }

  bool get isFolder => sourceType == 1;
  bool get isFile => sourceType == 0;
}

/// 分享所有者信息
class ShareOwner {
  final String id;
  final String? email;
  final String nickname;
  final DateTime createdAt;
  final ShareOwnerGroup? group;
  final String? shareLinksInProfile;

  ShareOwner({
    required this.id,
    this.email,
    required this.nickname,
    required this.createdAt,
    this.group,
    this.shareLinksInProfile,
  });

  factory ShareOwner.fromJson(Map<String, dynamic> json) {
    return ShareOwner(
      id: json['id'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      group: json['group'] is Map<String, dynamic>
          ? ShareOwnerGroup.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      shareLinksInProfile: json['share_links_in_profile'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'created_at': createdAt.toIso8601String(),
      'group': group?.toJson(),
      'share_links_in_profile': shareLinksInProfile,
    };
  }
}

/// 分享所有者所属组
class ShareOwnerGroup {
  final String id;
  final String name;

  ShareOwnerGroup({required this.id, required this.name});

  factory ShareOwnerGroup.fromJson(Map<String, dynamic> json) {
    return ShareOwnerGroup(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// 权限设置
class SharePermissionSetting {
  final String? sameGroup;
  final String? other;
  final String? anonymous;
  final String? everyone;
  final Map<String, String>? groupExplicit;
  final Map<String, String>? userExplicit;

  SharePermissionSetting({
    this.sameGroup,
    this.other,
    this.anonymous,
    this.everyone,
    this.groupExplicit,
    this.userExplicit,
  });

  factory SharePermissionSetting.fromJson(Map<String, dynamic> json) {
    return SharePermissionSetting(
      sameGroup: json['same_group'] as String?,
      other: json['other'] as String?,
      anonymous: json['anonymous'] as String?,
      everyone: json['everyone'] as String?,
      groupExplicit: (json['group_explicit'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      userExplicit: (json['user_explicit'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'same_group': sameGroup,
      'other': other,
      'anonymous': anonymous,
      'everyone': everyone,
      'group_explicit': groupExplicit,
      'user_explicit': userExplicit,
    };
  }
}
