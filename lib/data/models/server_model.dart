import 'package:cloudreve4_flutter/data/models/user_model.dart';

/// 服务器模型
class ServerModel {
  static const Object _unset = Object();

  final String label;
  final String baseUrl;
  bool rememberMe;
  String? email;
  String? password;
  UserModel? user;

  /// 同一个站点下保存的多个账号。
  ///
  /// 一个 ServerModel 表示一个站点；accounts 表示这个站点下保存的账号列表。
  final List<UserModel> accounts;

  ServerModel({
    required this.label,
    required this.baseUrl,
    this.rememberMe = true,
    this.email,
    this.password,
    this.user,
    List<UserModel>? accounts,
  }) : accounts = accounts ?? const [];

  /// 克隆服务器配置。
  ///
  /// email/password/user/accounts 支持传 null 主动清空。
  ServerModel copyWith({
    String? label,
    String? baseUrl,
    bool? rememberMe,
    Object? email = _unset,
    Object? password = _unset,
    Object? user = _unset,
    Object? accounts = _unset,
  }) {
    return ServerModel(
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      rememberMe: rememberMe ?? this.rememberMe,
      email: identical(email, _unset) ? this.email : email as String?,
      password: identical(password, _unset) ? this.password : password as String?,
      user: identical(user, _unset) ? this.user : user as UserModel?,
      accounts: identical(accounts, _unset)
          ? this.accounts
          : (accounts as List<UserModel>? ?? const []),
    );
  }

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    final parsedUser = json['user'] != null
        ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
        : null;

    final parsedAccounts = <UserModel>[];
    final rawAccounts = json['accounts'];

    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is Map<String, dynamic>) {
          parsedAccounts.add(UserModel.fromJson(item));
        } else if (item is Map) {
          parsedAccounts.add(UserModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 兼容旧数据：旧版本只有 user，没有 accounts。
    if (parsedUser != null && !_containsAccount(parsedAccounts, parsedUser)) {
      parsedAccounts.insert(0, parsedUser);
    }

    return ServerModel(
      label: json['label'] as String,
      baseUrl: json['baseUrl'] as String,
      rememberMe: json['rememberMe'] as bool? ?? true,
      email: json['email'] as String?,
      password: json['password'] as String?,
      user: parsedUser,
      accounts: parsedAccounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'baseUrl': baseUrl,
      'rememberMe': rememberMe,
      'email': email,
      'password': password,
      'user': user?.toJson(),
      'accounts': accounts.map((e) => e.toJson()).toList(),
    };
  }

  static bool _containsAccount(List<UserModel> accounts, UserModel user) {
    return accounts.any(
      (item) => item.id == user.id || (user.email != null && item.email == user.email),
    );
  }
}
