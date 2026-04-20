/// 分享模型
class ShareModel {
  final String id;
  final String name;
  final int visited;
  final int? downloaded;
  final int? price;
  final bool unlocked;
  final int sourceType; // 0: 文件, 1: 文件夹
  final ShareOwner owner;
  final DateTime createdAt;
  final bool expired;
  final String url;
  final SharePermissionSetting permissionSetting;
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
    required this.owner,
    required this.createdAt,
    required this.expired,
    required this.url,
    required this.permissionSetting,
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
      visited: json['visited'] as int,
      downloaded: json['downloaded'] as int?,
      price: json['price'] as int?,
      unlocked: json['unlocked'] as bool,
      sourceType: json['source_type'] as int,
      owner: ShareOwner.fromJson(json['owner'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      expired: json['expired'] as bool,
      url: json['url'] as String,
      permissionSetting: SharePermissionSetting.fromJson(json['permission_setting'] as Map<String, dynamic>? ?? {}),
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
    'owner': owner.toJson(),
    'created_at': createdAt.toIso8601String(),
    'expired': expired,
    'url': url,
    'permission_setting': permissionSetting.toJson(),
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

  ShareOwner({
    required this.id,
    this.email,
    required this.nickname,
    required this.createdAt,
  });

  factory ShareOwner.fromJson(Map<String, dynamic> json) {
    return ShareOwner(
      id: json['id'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'created_at': createdAt.toIso8601String(),
    };
  }
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
