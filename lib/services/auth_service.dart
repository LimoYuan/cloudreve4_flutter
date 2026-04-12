import '../data/models/user_model.dart';
import '../core/exceptions/app_exception.dart';
import 'api_service.dart';
import 'storage_service.dart';

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
      if (captcha != null) 'captcha': captcha,
    };

    final response = await ApiService.instance
        .post<Map<String, dynamic>>('/session/token', data: data, noAuth: true);

    return LoginResponseModel.fromJson(response);
  }

  /// 2FA登录
  Future<LoginResponseModel> twoFactorLogin({
    required String otp,
    required String sessionId,
  }) async {
    final data = <String, dynamic>{
      'otp': otp,
      'session_id': sessionId,
    };

    final response = await ApiService.instance
        .post<Map<String, dynamic>>('/session/token/2fa', data: data, noAuth: true);

    return LoginResponseModel.fromJson(response);
  }

  /// 刷新Token
  Future<TokenModel> refreshToken() async {
    final refreshToken = await StorageService.instance.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw TokenExpiredException();
    }

    final data = <String, dynamic>{'refresh_token': refreshToken};

    final response = await ApiService.instance
        .post<Map<String, dynamic>>('/session/token/refresh', data: data, noAuth: true);

    return TokenModel.fromJson(response);
  }

  /// 登出
  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.instance.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await ApiService.instance.delete<void>(
          '/session/token',
          data: <String, dynamic>{'refresh_token': refreshToken},
          noAuth: true,
        );
      }
    } catch (e) {
      // 登出失败也要清除本地数据
      await _clearAuthData();
      rethrow;
    }
  }

  /// 获取当前用户信息
  Future<UserModel> getCurrentUser() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>('/user/me');
    return UserModel.fromJson(response);
  }

  /// 获取用户容量
  Future<CapacityModel> getUserCapacity() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>('/user/capacity');
    return CapacityModel.fromJson(response);
  }

  /// 保存登录信息
  Future<void> saveLoginInfo(LoginResponseModel response) async {
    final storage = StorageService.instance;

    // 保存Token
    await storage.setAccessToken(response.token.accessToken);
    await storage.setRefreshToken(response.token.refreshToken);

    // 保存用户信息
    await storage.setUserId(response.user.id);
    await storage.setUserEmail(response.user.email ?? '');

    // 设置API的Token
    ApiService.instance.setToken(response.token.accessToken);
  }

  /// 清除认证数据
  Future<void> _clearAuthData() async {
    final storage = StorageService.instance;

    await storage.removeAccessToken();
    await storage.removeRefreshToken();
    await storage.removeUserId();
    await storage.removeUserEmail();

    // 清除API的Token
    ApiService.instance.clearToken();
  }

  /// 检查登录状态
  Future<bool> isLoggedIn() async {
    final accessToken = await StorageService.instance.accessToken;
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// 自动登录
  Future<UserModel?> autoLogin() async {
    if (!await isLoggedIn()) {
      return null;
    }

    try {
      return await getCurrentUser();
    } catch (e) {
      // Token可能已过期，清除数据
      if (e is AuthException) {
        await _clearAuthData();
      }
      rethrow;
    }
  }
}

/// 登录响应模型
class LoginResponseModel {
  final UserModel user;
  final TokenModel token;

  LoginResponseModel({
    required this.user,
    required this.token,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: TokenModel.fromJson(json['token'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token.toJson(),
    };
  }
}
