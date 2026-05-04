/// 用户设置模型 - 对应 GET /user/setting 响应
class UserSettingModel {
  final DateTime? groupExpires;
  final List<OpenIdProvider> openId;
  final bool versionRetentionEnabled;
  final List<String>? versionRetentionExt;
  final int versionRetentionMax;
  final bool passwordless;
  final bool twoFaEnabled;
  final List<PasskeyModel> passkeys;
  final List<LoginActivity> loginActivity;
  final List<StoragePack> storagePacks;
  final int credit;
  final bool disableViewSync;
  final String shareLinksInProfile;
  final List<OAuthGrant> oauthGrants;

  UserSettingModel({
    this.groupExpires,
    this.openId = const [],
    this.versionRetentionEnabled = false,
    this.versionRetentionExt,
    this.versionRetentionMax = 0,
    this.passwordless = false,
    this.twoFaEnabled = false,
    this.passkeys = const [],
    this.loginActivity = const [],
    this.storagePacks = const [],
    this.credit = 0,
    this.disableViewSync = false,
    this.shareLinksInProfile = '',
    this.oauthGrants = const [],
  });

  factory UserSettingModel.fromJson(Map<String, dynamic> json) {
    return UserSettingModel(
      groupExpires: json['group_expires'] != null
          ? DateTime.parse(json['group_expires'] as String)
          : null,
      openId: (json['open_id'] as List?)
              ?.map((e) => OpenIdProvider.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      versionRetentionEnabled: json['version_retention_enabled'] as bool? ?? false,
      versionRetentionExt: (json['version_retention_ext'] as List?)
          ?.map((e) => e as String)
          .toList(),
      versionRetentionMax: json['version_retention_max'] as int? ?? 0,
      passwordless: json['passwordless'] as bool? ?? false,
      twoFaEnabled: json['two_fa_enabled'] as bool? ?? false,
      passkeys: (json['passkeys'] as List?)
              ?.map((e) => PasskeyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      loginActivity: (json['login_activity'] as List?)
              ?.map((e) => LoginActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      storagePacks: (json['storage_packs'] as List?)
              ?.map((e) => StoragePack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      credit: json['credit'] as int? ?? 0,
      disableViewSync: json['disable_view_sync'] as bool? ?? false,
      shareLinksInProfile: json['share_links_in_profile'] as String? ?? '',
      oauthGrants: (json['oauth_grants'] as List?)
              ?.map((e) => OAuthGrant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  UserSettingModel copyWith({
    DateTime? groupExpires,
    List<OpenIdProvider>? openId,
    bool? versionRetentionEnabled,
    List<String>? versionRetentionExt,
    int? versionRetentionMax,
    bool? passwordless,
    bool? twoFaEnabled,
    List<PasskeyModel>? passkeys,
    List<LoginActivity>? loginActivity,
    List<StoragePack>? storagePacks,
    int? credit,
    bool? disableViewSync,
    String? shareLinksInProfile,
    List<OAuthGrant>? oauthGrants,
  }) {
    return UserSettingModel(
      groupExpires: groupExpires ?? this.groupExpires,
      openId: openId ?? this.openId,
      versionRetentionEnabled: versionRetentionEnabled ?? this.versionRetentionEnabled,
      versionRetentionExt: versionRetentionExt ?? this.versionRetentionExt,
      versionRetentionMax: versionRetentionMax ?? this.versionRetentionMax,
      passwordless: passwordless ?? this.passwordless,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      passkeys: passkeys ?? this.passkeys,
      loginActivity: loginActivity ?? this.loginActivity,
      storagePacks: storagePacks ?? this.storagePacks,
      credit: credit ?? this.credit,
      disableViewSync: disableViewSync ?? this.disableViewSync,
      shareLinksInProfile: shareLinksInProfile ?? this.shareLinksInProfile,
      oauthGrants: oauthGrants ?? this.oauthGrants,
    );
  }
}

/// 已关联的外部身份提供商
class OpenIdProvider {
  final int provider;
  final DateTime linkedAt;

  OpenIdProvider({required this.provider, required this.linkedAt});

  factory OpenIdProvider.fromJson(Map<String, dynamic> json) {
    return OpenIdProvider(
      provider: json['provider'] as int,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }

  String get providerName {
    switch (provider) {
      case 0:
        return 'Logto';
      case 1:
        return 'QQ';
      case 2:
        return 'OIDC';
      default:
        return 'Unknown';
    }
  }
}

/// Passkey 模型
class PasskeyModel {
  final String id;
  final String name;
  final DateTime? usedAt;
  final DateTime createdAt;

  PasskeyModel({
    required this.id,
    required this.name,
    this.usedAt,
    required this.createdAt,
  });

  factory PasskeyModel.fromJson(Map<String, dynamic> json) {
    return PasskeyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 登录活动记录
class LoginActivity {
  final DateTime createdAt;
  final String ip;
  final String browser;
  final String device;
  final String os;
  final String loginWith;
  final int? openIdProvider;
  final bool success;
  final bool webdav;

  LoginActivity({
    required this.createdAt,
    required this.ip,
    required this.browser,
    required this.device,
    required this.os,
    required this.loginWith,
    this.openIdProvider,
    required this.success,
    required this.webdav,
  });

  factory LoginActivity.fromJson(Map<String, dynamic> json) {
    return LoginActivity(
      createdAt: DateTime.parse(json['created_at'] as String),
      ip: json['ip'] as String,
      browser: json['browser'] as String,
      device: json['device'] as String,
      os: json['os'] as String,
      loginWith: json['login_with'] as String? ?? '',
      openIdProvider: json['open_id_provider'] as int?,
      success: json['success'] as bool? ?? false,
      webdav: json['webdav'] as bool? ?? false,
    );
  }

  String get loginMethodName {
    if (webdav) return 'WebDAV';
    switch (loginWith) {
      case 'passkey':
        return 'Passkey';
      case 'openid':
        return '第三方登录';
      default:
        return '密码';
    }
  }
}

/// 存储包
class StoragePack {
  final String name;
  final DateTime activeSince;
  final DateTime? expireAt;
  final int size;

  StoragePack({
    required this.name,
    required this.activeSince,
    this.expireAt,
    required this.size,
  });

  factory StoragePack.fromJson(Map<String, dynamic> json) {
    return StoragePack(
      name: json['name'] as String,
      activeSince: DateTime.parse(json['active_since'] as String),
      expireAt: json['expire_at'] != null
          ? DateTime.parse(json['expire_at'] as String)
          : null,
      size: json['size'] as int,
    );
  }

  bool get isExpired => expireAt != null && DateTime.now().isAfter(expireAt!);
}

/// OAuth 授权应用
class OAuthGrant {
  final String clientId;
  final String clientName;
  final String? clientLogo;
  final List<String> scopes;
  final DateTime? lastUsedAt;

  OAuthGrant({
    required this.clientId,
    required this.clientName,
    this.clientLogo,
    this.scopes = const [],
    this.lastUsedAt,
  });

  factory OAuthGrant.fromJson(Map<String, dynamic> json) {
    return OAuthGrant(
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientLogo: json['client_logo'] as String?,
      scopes: (json['scopes'] as List?)?.map((e) => e as String).toList() ?? [],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
    );
  }
}

/// 用户容量模型（扩展版，含存储包）
class UserCapacityModel {
  final int total;
  final int used;
  final int storagePackTotal;

  UserCapacityModel({
    required this.total,
    required this.used,
    this.storagePackTotal = 0,
  });

  factory UserCapacityModel.fromJson(Map<String, dynamic> json) {
    return UserCapacityModel(
      total: json['total'] as int,
      used: json['used'] as int,
      storagePackTotal: json['storage_pack_total'] as int? ?? 0,
    );
  }

  double get usagePercentage => total > 0 ? (used / total) * 100 : 0;
  int get remaining => total - used;
}

/// 积分变动记录
class CreditChange {
  final DateTime changedAt;
  final int diff;
  final String reason;

  CreditChange({
    required this.changedAt,
    required this.diff,
    required this.reason,
  });

  factory CreditChange.fromJson(Map<String, dynamic> json) {
    return CreditChange(
      changedAt: DateTime.parse(json['changed_at'] as String),
      diff: json['diff'] as int,
      reason: json['reason'] as String,
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'share_purchased':
        return '分享被购买';
      case 'pay':
        return '支付';
      case 'adjust':
        return '管理员调整';
      default:
        return reason;
    }
  }
}

/// 积分变动列表响应
class CreditChangeList {
  final List<CreditChange> changes;
  final String? nextToken;

  CreditChangeList({required this.changes, this.nextToken});

  factory CreditChangeList.fromJson(Map<String, dynamic> json) {
    return CreditChangeList(
      changes: (json['changes'] as List?)
              ?.map((e) => CreditChange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextToken: (json['pagination'] as Map<String, dynamic>?)?['next_token'] as String?,
    );
  }

  bool get hasMore => nextToken != null && nextToken!.isNotEmpty;
}
