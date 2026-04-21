import 'package:flutter/material.dart';

import '../data/models/user_model.dart';
import 'api_service.dart';

/// 认证服务
class AuthService {
  // 私有化构造函数，防止在外部被直接实例化
  AuthService._internal();

  // 存储单例的静态私有变量
  static final AuthService _instance = AuthService._internal();

  // 公开一个 getter 叫 instance (或者使用工厂构造函数)
  static AuthService get instance => _instance;

  /// 准备登录
  Future<Map<String, bool>> prepareLogin(String email) async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/session/prepare',
      queryParameters: {'email': email},
      noAuth: true,
    );
    return response as Map<String, bool>;
  }

  /// 密码登录
  Future<LoginResponseModel> passwordLogin({
    required String email,
    required String password,
    String? captcha,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      ...captcha != null ? {'captcha': captcha} : {},
    };

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/session/token',
      data: data,
      noAuth: true,
    );

    debugPrint('AuthService -> 登录响应: $response');

    return LoginResponseModel.fromJson(response);
  }

  /// 2FA登录
  Future<LoginResponseModel> twoFactorLogin({
    required String otp,
    required String sessionId,
  }) async {
    final data = <String, dynamic>{'otp': otp, 'session_id': sessionId};

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/session/token/2fa',
      data: data,
      noAuth: true,
    );

    return LoginResponseModel.fromJson(response);
  }

  /// 刷新Token
  /// 这个方法现在由 ApiService 调用，传入当前的 refreshToken
  Future<TokenModel> refreshToken(String refreshToken) async {
    final data = <String, dynamic>{'refresh_token': refreshToken};

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/session/token/refresh',
      data: data,
      noAuth: true,
    );

    return TokenModel.fromJson(response);
  }

  /// 登出
  /// 现在由 ServerService 和 AuthProvider 负责清除本地数据
  Future<void> logout() async {
    try {
      // 登出需要调用 API，但 refreshToken 由调用方提供
      // 这个方法现在主要用于调用登出 API
      await ApiService.instance.delete<void>(
        '/session/token',
        data: <String, dynamic>{},
        noAuth: true,
      );
    } catch (e) {
      // 登出失败也要清除本地数据（由调用方处理）
      rethrow;
    }
  }

  /// 获取当前用户信息
  Future<UserModel> getCurrentUser() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/user/me',
    );
    return UserModel.fromJson(response);
  }

  /// 获取用户容量
  Future<CapacityModel> getUserCapacity() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/user/capacity',
    );
    return CapacityModel.fromJson(response);
  }

  /// 发送重置密码邮件
  Future<void> sendResetPasswordEmail({
    required String email,
    String? captcha,
    String? ticket,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      ...captcha != null ? {'captcha': captcha} : {},
      ...ticket != null ? {'ticket': ticket} : {},
    };

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/user/reset',
      data: data,
      noAuth: true,
      isNoData: true,
    );

    final code = response['code'] as int?;
    if (code != 0) {
      final msg = response['msg'] as String? ?? '发送失败';
      throw Exception(msg);
    }
  }
}

/// 登录响应模型
/// 这个模型现在将 token 合并到 user 中返回
class LoginResponseModel {
  final UserModel user;

  LoginResponseModel({required this.user});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    // debugPrint('AuthProvider 登录成功: ${json}');
    final Map<String, dynamic> data;
    
    if (json['data'] != null) {
      data = json['data'] as Map<String, dynamic>;
    } else {
      data = json;
    }

    // 将 token 合并到 user 中
    final userJson = data['user'] as Map<String, dynamic>;
    userJson['token'] = data['token'];

    return LoginResponseModel(user: UserModel.fromJson(userJson));
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson()};
  }
}
