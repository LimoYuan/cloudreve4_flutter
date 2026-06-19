import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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

  /// 编辑器主题 key
  Future<String?> getEditorTheme() => getString(StorageKeys.editorTheme);
  Future<bool> setEditorTheme(String value) => setString(StorageKeys.editorTheme, value);

  /// 搜索历史（最新在前，最多 20 条）
  Future<List<String>> getSearchHistory() async {
    final json = await getString(StorageKeys.searchHistory);
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> setSearchHistory(List<String> history) async {
    try {
      final json = jsonEncode(history);
      return await setString(StorageKeys.searchHistory, json);
    } catch (_) {
      return false;
    }
  }

  Future<void> addToSearchHistory(String query) async {
    final history = await getSearchHistory();
    history.remove(query);
    history.insert(0, query);
    if (history.length > 20) history.removeRange(20, history.length);
    await setSearchHistory(history);
  }

  Future<void> clearSearchHistory() async {
    await remove(StorageKeys.searchHistory);
  }

  // ===== 同步配置持久化 =====

  /// 保存同步配置
  Future<bool> setSyncConfig(Map<String, dynamic> config) async {
    try {
      final json = jsonEncode(config);
      return await setString(StorageKeys.syncConfig, json);
    } catch (_) {
      return false;
    }
  }

  /// 读取同步配置
  Future<Map<String, dynamic>?> getSyncConfig() async {
    final json = await getString(StorageKeys.syncConfig);
    if (json == null || json.isEmpty) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 保存同步状态
  Future<bool> setSyncState(String state) async {
    return await setString(StorageKeys.syncState, state);
  }

  /// 读取同步状态
  Future<String?> getSyncState() async {
    return await getString(StorageKeys.syncState);
  }

  /// 清除同步配置和状态
  Future<void> clearSyncData() async {
    await remove(StorageKeys.syncConfig);
    await remove(StorageKeys.syncState);
    await remove(StorageKeys.syncCumStats);
  }

  /// 保存同步累积统计
  Future<bool> setSyncCumStats(Map<String, int> stats) async {
    final json = jsonEncode(stats);
    return await setString(StorageKeys.syncCumStats, json);
  }

  /// 读取同步累积统计
  Future<Map<String, int>?> getSyncCumStats() async {
    final json = await getString(StorageKeys.syncCumStats);
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return null;
    }
  }

  // ===== client_id 持久化 =====

  /// 获取 client_id，首次调用自动生成并持久化
  Future<String> getOrCreateClientId() async {
    var id = await getString(StorageKeys.clientId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await setString(StorageKeys.clientId, id);
    }
    return id;
  }
}
