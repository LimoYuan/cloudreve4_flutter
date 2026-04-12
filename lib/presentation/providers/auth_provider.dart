import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../services/auth_service.dart';

/// 认证状态
enum AuthState { loading, authenticated, unauthenticated, error }

/// 认证Provider
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.unauthenticated;
  UserModel? _user;
  String? _errorMessage;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  /// 初始化
  Future<void> init() async {
    try {
      setState(AuthState.loading);
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
  }) async {
    try {
      setState(AuthState.loading);
      final response = await AuthService.instance.passwordLogin(
        email: email,
        password: password,
      );

      await AuthService.instance.saveLoginInfo(response);
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
}
