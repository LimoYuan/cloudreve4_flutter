import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

/// 认证状态
enum AuthState { loading, authenticated, unauthenticated, error }

/// 认证Provider
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unauthenticated;
  UserModel? _user;
  String? _errorMessage;
  String? _rememberedEmail;
  String? _rememberedPassword;
  bool _rememberMe = false;
  bool _hasRefreshTokenExpired = false;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get rememberMe => _rememberMe;
  String? get rememberedEmail => _rememberedEmail;
  String? get rememberedPassword => _rememberedPassword;
  bool get hasRefreshTokenExpired => _hasRefreshTokenExpired;

  /// 初始化
  Future<void> init() async {
    try {
      setState(AuthState.loading);
      await _loadRememberedInfo();
      final user = await AuthService.instance.autoLogin();
      if (user != null) {
        setUser(user);
        setState(AuthState.authenticated);
      } else {
        setState(AuthState.unauthenticated);
      }
    } catch (e) {
      setState(AuthState.unauthenticated);
    }
  }

  /// 密码登录
  Future<bool> passwordLogin({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      setState(AuthState.loading);
      final response = await AuthService.instance.passwordLogin(
        email: email,
        password: password,
      );

      await AuthService.instance.saveLoginInfo(response);

      _rememberMe = rememberMe;
      if (rememberMe) {
        _rememberedEmail = email;
        _rememberedPassword = password;
      } else {
        _rememberedEmail = null;
        _rememberedPassword = null;
      }
      await _saveRememberedInfo();

      setUser(response.user);
      setState(AuthState.authenticated);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      setState(AuthState.error);
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      await AuthService.instance.logout();
      _clearUserData();
      setState(AuthState.unauthenticated);
    } catch (e) {
      _errorMessage = e.toString();
      setState(AuthState.error);
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    try {
      final user = await AuthService.instance.getCurrentUser();
      setUser(user);
    } catch (e) {
      _errorMessage = e.toString();
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

  /// 加载记住我信息
  Future<void> _loadRememberedInfo() async {
    _rememberMe = await StorageService.instance.rememberMe;
    if (_rememberMe) {
      _rememberedEmail = await StorageService.instance.userEmail;
      _rememberedPassword = await StorageService.instance.userPasswd;
    }

    // debugPrint("记住我信息: $_rememberMe, $_rememberedEmail, $_rememberedPassword");
  }

  /// 保存记住我信息
  Future<void> _saveRememberedInfo() async {
    await StorageService.instance.setRememberMe(_rememberMe);
    if (_rememberMe) {
      await StorageService.instance.setUserEmail(_rememberedEmail ?? '');
      await StorageService.instance.setUserPasswd(_rememberedPassword ?? '');
    } else {
      await StorageService.instance.removeUserEmail();
    }
  }
}
