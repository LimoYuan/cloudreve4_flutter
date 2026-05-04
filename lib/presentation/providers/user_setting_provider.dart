import 'package:flutter/foundation.dart';
import '../../data/models/user_setting_model.dart';
import '../../services/user_setting_service.dart';
import '../../core/utils/app_logger.dart';

/// 用户设置状态
enum UserSettingState { idle, loading, error }

/// 用户设置 Provider
class UserSettingProvider extends ChangeNotifier {
  UserSettingState _state = UserSettingState.idle;
  UserSettingModel? _settings;
  UserCapacityModel? _capacity;
  String? _errorMessage;

  UserSettingState get state => _state;
  UserSettingModel? get settings => _settings;
  UserCapacityModel? get capacity => _capacity;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == UserSettingState.loading;

  final UserSettingService _service = UserSettingService.instance;

  /// 加载用户设置
  Future<void> loadSettings() async {
    try {
      _setState(UserSettingState.loading);
      _settings = await _service.getUserSetting();
      _setState(UserSettingState.idle);
    } catch (e) {
      AppLogger.d('加载用户设置失败: $e');
      _errorMessage = e.toString();
      _setState(UserSettingState.error);
    }
  }

  /// 加载存储用量
  Future<void> loadCapacity() async {
    try {
      _capacity = await _service.getUserCapacity();
      notifyListeners();
    } catch (e) {
      AppLogger.d('加载存储用量失败: $e');
    }
  }

  /// 同时加载设置和容量
  Future<void> loadAll() async {
    await Future.wait([
      loadSettings(),
      loadCapacity(),
    ]);
  }

  /// 修改昵称
  Future<bool> updateNick(String nick) async {
    try {
      await _service.updateNick(nick);
      // 成功后刷新设置
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('修改昵称失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 修改主题色
  Future<bool> updatePreferredTheme(String themeColor) async {
    try {
      await _service.updatePreferredTheme(themeColor);
      if (_settings != null) {
        _settings = _settings!.copyWith(); // 本地无需维护此字段
      }
      return true;
    } catch (e) {
      AppLogger.d('修改主题色失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 修改语言
  Future<bool> updateLanguage(String language) async {
    try {
      await _service.updateLanguage(language);
      return true;
    } catch (e) {
      AppLogger.d('修改语言失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 修改密码
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      AppLogger.d('修改密码失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 启用2FA
  Future<String?> prepare2FA() async {
    try {
      return await _service.prepare2FA();
    } catch (e) {
      AppLogger.d('准备启用2FA失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> enable2FA(String code) async {
    try {
      await _service.enable2FA(code);
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('启用2FA失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 禁用2FA
  Future<bool> disable2FA(String code) async {
    try {
      await _service.disable2FA(code);
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('禁用2FA失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新版本保留设置
  Future<bool> updateVersionRetention({
    bool? enabled,
    List<String>? ext,
    int? max,
  }) async {
    try {
      await _service.updateUserSetting(
        versionRetentionEnabled: enabled,
        versionRetentionExt: ext,
        versionRetentionMax: max,
      );
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('更新版本保留设置失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新视图同步
  Future<bool> updateViewSync(bool disabled) async {
    try {
      await _service.updateUserSetting(disableViewSync: disabled);
      if (_settings != null) {
        _settings = _settings!.copyWith(disableViewSync: disabled);
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('更新视图同步设置失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 更新分享链接可见性
  Future<bool> updateShareLinksInProfile(String value) async {
    try {
      await _service.updateUserSetting(shareLinksInProfile: value);
      if (_settings != null) {
        _settings = _settings!.copyWith(shareLinksInProfile: value);
      }
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('更新分享链接可见性失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 撤销OAuth授权
  Future<bool> revokeOAuthGrant(String appId) async {
    try {
      await _service.revokeOAuthGrant(appId);
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('撤销OAuth授权失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 解绑OIDC提供商
  Future<bool> unlinkOpenId(int provider) async {
    try {
      await _service.unlinkOpenId(provider);
      await loadSettings();
      return true;
    } catch (e) {
      AppLogger.d('解绑OIDC失败: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setState(UserSettingState state) {
    _state = state;
    notifyListeners();
  }
}
