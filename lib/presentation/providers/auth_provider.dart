import 'package:cloudreve4_flutter/presentation/widgets/toast_helper.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/server_model.dart';
import '../../data/models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/server_service.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/app_logger.dart';

/// 认证状态
enum AuthState { loading, authenticated, unauthenticated, error }

/// 认证Provider
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unauthenticated;
  UserModel? _user;
  String? _errorMessage;
  bool _hasRefreshTokenExpired = false;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get hasRefreshTokenExpired => _hasRefreshTokenExpired;
  bool get isAdmin {
    final name = _user?.group?.name.toLowerCase();
    return name == 'admin' || name == '管理员';
  }

  /// 当前选中的服务器
  ServerModel? get currentServer => ServerService.instance.currentServer;

  /// 获取当前用户的 token
  TokenModel? get token => _user?.token;

  /// 初始化
  Future<void> init() async {
    try {
      setState(AuthState.loading);

      // 初始化服务器服务
      await ServerService.instance.init();

      // 获取当前服务器
      final server = ServerService.instance.currentServer;
      if (server == null) {
        setState(AuthState.unauthenticated);
        return;
      }

      // 设置 API 的 baseUrl
      await _setApiBaseUrl(server.baseUrl);

      // 设置 ApiService 的认证回调
      _setupApiCallbacks();

      // 检查是否有保存的登录信息
      if (server.user != null && server.user!.token != null) {
        // 有保存的用户信息，检查 token 是否过期
        if (!server.user!.token!.isRefreshTokenExpired) {
          // Refresh token 未过期，设置用户信息
          setUser(server.user);
          setState(AuthState.authenticated);
          return;
        } else {
          // Refresh token 已过期，清除登录信息
          await ServerService.instance.clearCurrentServerLogin();
        }
      }

      _user = null;
      setState(AuthState.unauthenticated);
    } catch (e) {
      AppLogger.d('AuthProvider 初始化失败: $e');
      _user = null;
      setState(AuthState.unauthenticated);
    }
  }

  /// 设置 ApiService 的认证回调
  void _setupApiCallbacks() {
    ApiService.setAuthCallbacks(
      getToken: () async {
        // 返回当前的 access token
        return _user?.token?.accessToken;
      },
      refreshToken: () async {
        // 刷新 token
        try {
          await refreshToken();
        } catch (e) {
          // 刷新失败，设置过期标志
          if (e is RefreshTokenExpiredException) {
            setRefreshTokenExpired();
          }
          rethrow;
        }
      },
      clearAuth: () async {
        // 清除认证数据
        await ServerService.instance.clearCurrentServerLogin();
        setRefreshTokenExpired();
      },
    );
  }

  /// 设置 API baseUrl
  Future<void> _setApiBaseUrl(String baseUrl) async {
    // 同时更新存储和 ApiService 的 baseUrl
    final storageService = StorageService.instance;
    await storageService.setCustomBaseUrl(baseUrl);
    await ApiService.instance.setBaseUrl(baseUrl);
  }

  /// 密码登录
  Future<bool> passwordLogin({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      setState(AuthState.loading);

      // 获取当前服务器
      final server = ServerService.instance.currentServer;
      if (server == null) {
        _errorMessage = '请先选择服务器';
        _user = null;
        setState(AuthState.error);
        return false;
      }

      // 每次登录时都重新设置 API 的 baseUrl，确保使用最新的服务器地址
      await _setApiBaseUrl(server.baseUrl);

      // 执行登录
      final response = await AuthService.instance.passwordLogin(
        email: email,
        password: password,
      );
      AppLogger.d('AuthProvider 登录成功: $response');
      // 保存登录信息到当前服务器（包含完整 user 和 token）
      await ServerService.instance.updateCurrentServerLogin(
        email: rememberMe ? email : null,
        password: rememberMe ? password : null,
        user: response.user,
        rememberMe: rememberMe,
      );

      setUser(response.user);
      setState(AuthState.authenticated);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _user = null;
      setState(AuthState.error);
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      // 调用登出 API（需要 token）
      if (token?.refreshToken != null) {
        try {
          await AuthService.instance.logout();
        } catch (e) {
          // 登出 API 调用失败不影响本地清理
          AppLogger.d('登出 API 调用失败: $e');
        }
      }

      // 清除当前服务器的登录信息
      await ServerService.instance.clearCurrentServerLogin();

      _clearUserData();
      setState(AuthState.unauthenticated);
    } catch (e) {
      // 即使出错也要清除本地状态
      _clearUserData();
      setState(AuthState.unauthenticated);
      _errorMessage = e.toString();
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    try {
      final user = await AuthService.instance.getCurrentUser();
      setUser(user);

      // 更新服务器中的用户信息（保留 token）
      final server = ServerService.instance.currentServer;
      if (server != null && token != null) {
        await ServerService.instance.updateCurrentServerLogin(
          user: user.copyWith(token: token),
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  /// 刷新 token
  Future<void> refreshToken() async {
    try {
      final currentToken = token;
      if (currentToken == null || currentToken.isRefreshTokenExpired) {
        ToastHelper.failure('已注销或Refresh token 已过期，需要重新登录');
        throw Exception('Refresh token 已过期，需要重新登录');
      }

      // 调用刷新 token 接口
      final newToken = await AuthService.instance.refreshToken(currentToken.refreshToken);

      // 更新用户信息中的 token
      final updatedUser = _user!.copyWith(token: newToken);

      // 保存到服务器
      await ServerService.instance.updateCurrentServerLogin(user: updatedUser);

      setUser(updatedUser);
    } catch (e) {
      ToastHelper.error('刷新 token 失败: $e');
      AppLogger.d('刷新 token 失败: $e');
      _user = null;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 设置用户
  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  /// 设置状态
  void setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 清除用户数据
  void _clearUserData() {
    _user = null;
    _errorMessage = null;
    _hasRefreshTokenExpired = false;
    notifyListeners();
  }

  /// 处理 RefreshTokenExpiredException
  void setRefreshTokenExpired() {
    _hasRefreshTokenExpired = true;
    notifyListeners();
  }

  void clearRefreshTokenExpired() {
    _hasRefreshTokenExpired = false;
    notifyListeners();
  }

  /// 获取上次登录的邮箱（用于填充输入框）
  String? get rememberedEmail {
    final server = ServerService.instance.currentServer;
    return server?.email;
  }

  /// 获取上次登录的密码（用于填充输入框）
  String? get rememberedPassword {
    final server = ServerService.instance.currentServer;
    return server?.password;
  }

  /// 是否记住密码
  bool get rememberMe {
    final server = ServerService.instance.currentServer;
    return server?.rememberMe ?? false;
  }
}
