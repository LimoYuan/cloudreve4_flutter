import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/storage_keys.dart';
import '../data/models/server_model.dart';

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

  /// 设置
  Future<String?> get themeMode => getString(StorageKeys.themeMode);
  Future<bool> setThemeMode(String value) => setString(StorageKeys.themeMode, value);

  /// 服务器地址配置
  Future<String?> get customBaseUrl => getString(StorageKeys.customBaseUrl);
  Future<bool> setCustomBaseUrl(String? value) => setString(StorageKeys.customBaseUrl, value);
  Future<bool> removeCustomBaseUrl() => remove(StorageKeys.customBaseUrl);

  /// 服务器列表
  Future<List<ServerModel>> get servers async {
    final serversJson = await getString(StorageKeys.servers);
    if (serversJson == null || serversJson.isEmpty) {
      return [];
    }

    try {
      final serversList = jsonDecode(serversJson) as List<dynamic>;
      return serversList
          .map((e) => ServerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> setServers(List<ServerModel> servers) async {
    try {
      final serversJson = jsonEncode(servers.map((s) => s.toJson()).toList());
      return await setString(StorageKeys.servers, serversJson);
    } catch (e) {
      return false;
    }
  }

  /// 上次选中的服务器 label
  Future<String?> get lastSelectedServerLabel => getString(StorageKeys.lastSelectedServer);
  Future<bool> setLastSelectedServerLabel(String? value) => setString(StorageKeys.lastSelectedServer, value);
}
