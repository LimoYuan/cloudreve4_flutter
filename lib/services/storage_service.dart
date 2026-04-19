import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/storage_keys.dart';

/// 存储服务
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  /// 获取单例
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取值
  Future<String?> getString(String key) async {
    await init();
    return _prefs!.getString(key);
  }

  /// 设置值
  Future<bool> setString(String key, String? value) async {
    await init();
    if (value == null) {
      return _prefs!.remove(key);
    }
    return _prefs!.setString(key, value);
  }

  /// 获取整数值
  Future<int?> getInt(String key) async {
    await init();
    return _prefs!.getInt(key);
  }

  /// 设置整数值
  Future<bool> setInt(String key, int? value) async {
    await init();
    if (value == null) {
      return _prefs!.remove(key);
    }
    return _prefs!.setInt(key, value);
  }

  /// 获取布尔值
  Future<bool?> getBool(String key) async {
    await init();
    return _prefs!.getBool(key);
  }

  /// 设置布尔值
  Future<bool> setBool(String key, bool? value) async {
    await init();
    if (value == null) {
      return _prefs!.remove(key);
    }
    return _prefs!.setBool(key, value);
  }

  /// 删除值
  Future<bool> remove(String key) async {
    await init();
    return _prefs!.remove(key);
  }

  /// 清空所有数据
  Future<bool> clear() async {
    await init();
    return _prefs!.clear();
  }

  /// Token相关
  Future<String?> get accessToken => getString(StorageKeys.accessToken);
  Future<bool> setAccessToken(String value) => setString(StorageKeys.accessToken, value);
  Future<bool> removeAccessToken() => remove(StorageKeys.accessToken);

  Future<String?> get refreshToken => getString(StorageKeys.refreshToken);
  Future<bool> setRefreshToken(String value) => setString(StorageKeys.refreshToken, value);
  Future<bool> removeRefreshToken() => remove(StorageKeys.refreshToken);

  /// 用户信息
  Future<String?> get userId => getString(StorageKeys.userId);
  Future<bool> setUserId(String value) => setString(StorageKeys.userId, value);
  Future<bool> removeUserId() => remove(StorageKeys.userId);

  Future<String?> get userEmail => getString(StorageKeys.userEmail);
  Future<bool> setUserEmail(String value) => setString(StorageKeys.userEmail, value);

  Future<String?> get userPasswd => getString(StorageKeys.userEmail);
  Future<bool> setUserPasswd(String value) => setString(StorageKeys.userPasswd, value);
  Future<bool> removeUserEmail() => remove(StorageKeys.userEmail);

  /// 设置
  Future<bool> get rememberMe async => await getBool(StorageKeys.rememberMe) ?? false;
  Future<bool> setRememberMe(bool value) => setBool(StorageKeys.rememberMe, value);

  Future<String?> get themeMode => getString(StorageKeys.themeMode);
  Future<bool> setThemeMode(String value) => setString(StorageKeys.themeMode, value);

  Future<String?> get language => getString(StorageKeys.language);
  Future<bool> setLanguage(String value) => setString(StorageKeys.language, value);
}
