import '../data/models/user_model.dart';
import 'api_service.dart';
import '../core/utils/app_logger.dart';
import '../core/exceptions/app_exception.dart';

/// 认证服务
class AuthService {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

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

  /// 获取图形验证码
  Future<Map<String, String>> getCaptcha() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/site/captcha',
      noAuth: true,
    );

    // 兼容 ApiService 已经解包 data 的情况，以及未解包的原始响应。
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;

    return {
      'image': data['image'] as String? ?? '',
      'ticket': data['ticket'] as String? ?? '',
    };
  }


  /// 获取站点基础配置
  ///
  /// 登录页用这个接口读取验证码类型：
  /// - captcha_type: normal / recaptcha / turnstile / cap
  /// - captcha_ReCaptchaKey
  /// - turnstile_site_id
  /// - captcha_cap_instance_url
  /// - captcha_cap_site_key
  /// - captcha_cap_asset_server
  Future<Map<String, dynamic>> getBasicSiteConfig() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/site/config/basic',
      noAuth: true,
    );

    AppLogger.d('AuthService -> 站点基础配置响应: $response');

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    // 兼容 ApiService 已经解包 data 的情况。
    return response;
  }

  /// 密码登录
  Future<LoginResponseModel> passwordLogin({
    required String email,
    required String password,
    String? captcha,
    String? ticket,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      if (captcha != null && captcha.isNotEmpty) 'captcha': captcha,
      if (ticket != null && ticket.isNotEmpty) 'ticket': ticket,
    };

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/session/token',
      data: data,
      noAuth: true,
    );

    AppLogger.d('AuthService -> 登录响应: $response');


  // code 203 表示需要两步验证
  final code = response['code'] as int?;
  if (code == 203) {
    final sessionId = response['data'] as String;
    throw TwoFactorRequiredException(sessionId);
  }

  // 下面你原来的代码保持不变

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

  /// 用户注册
  Future<SignUpResponse> signUp({
    required String email,
    required String password,
    String? language,
    String? captcha,
    String? ticket,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      ...language != null ? {'language': language} : {},
      ...captcha != null ? {'captcha': captcha} : {},
      ...ticket != null ? {'ticket': ticket} : {},
    };

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/user',
      data: data,
      noAuth: true,
    );

    final code = response['code'] as int?;
    final msg = response['msg'] as String?;

    if (code != 0 && code != 203) {
      throw Exception('注册失败: $msg');
    }

    return SignUpResponse(
      code: code ?? 0,
      msg: msg,
      requiresEmailActivation: code == 203,
    );
  }
}

/// 注册响应
class SignUpResponse {
  final int code;
  final String? msg;
  final bool requiresEmailActivation;

  SignUpResponse({
    required this.code,
    this.msg,
    required this.requiresEmailActivation,
  });
}

/// 登录响应模型
/// 这个模型现在将 token 合并到 user 中返回
class LoginResponseModel {
  final UserModel user;

  LoginResponseModel({required this.user});

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    // 检查是否为错误响应（包含 code 和 msg 但没有 data 或 user）
    final code = json['code'] as int?;
    final msg = json['msg'] as String?;
    final Map<String, dynamic>? data = json['data'] as Map<String, dynamic>?;

    // 如果 code 不是 0，说明是错误响应
    if (code != null && code != 0) {
      throw Exception(msg ?? '登录失败');
    }

    // 如果没有 data 且也没有 user，说明是错误响应
    if (data == null && json['user'] == null) {
      throw Exception(msg ?? '登录失败');
    }

    final Map<String, dynamic> userData = data ?? json;
    final userJson = userData['user'] as Map<String, dynamic>;

    // 将 token 合并到 user 中
    userJson['token'] = userData['token'];

    return LoginResponseModel(user: UserModel.fromJson(userJson));
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson()};
  }
}
