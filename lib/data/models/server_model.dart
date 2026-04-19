import 'package:cloudreve4_flutter/data/models/user_model.dart';

/// 服务器模型
class ServerModel {
  final String label;
  final String baseUrl;
  bool rememberMe;
  String? email;
  String? password;
  UserModel? user;

  ServerModel({
    required this.label,
    required this.baseUrl,
    this.rememberMe = true,
    this.email,
    this.password,
    this.user,
  });

  ServerModel copyWith({
    String? label,
    String? baseUrl,
    bool? rememberMe,
    String? email,
    String? password,
    UserModel? user,
  }) {
    return ServerModel(
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      rememberMe: rememberMe ?? this.rememberMe,
      email: email ?? this.email,
      password: password ?? this.password,
      user: user ?? this.user,
    );
  }

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      label: json['label'] as String,
      baseUrl: json['baseUrl'] as String,
      rememberMe: json['rememberMe'] as bool? ?? true,
      email: json['email'] as String?,
      password: json['password'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
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
    };
  }
}
