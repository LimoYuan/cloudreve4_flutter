import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import '../core/utils/server_url_utils.dart';

/// 桌面标题栏站点品牌缓存服务
///
/// 缓存站点名称 + favicon 图标，避免每次启动重新拉取。
/// - name / icon_url：短字符串，存 SharedPreferences
/// - icon_bytes：存文件系统（`<app_support>/site_brand_cache/<cacheKey>.png`）
///
/// 替代旧版把 base64 图片塞 SharedPreferences 的做法（会让 json 膨胀）。
/// 启动时调用 migrateAllLegacy 可将旧 base64 缓存迁移到文件并清理旧 key。
class SiteBrandCacheService {
  SiteBrandCacheService._();
  static final SiteBrandCacheService instance = SiteBrandCacheService._();

  static const String _cacheVersion = 'v11_once';
  static const String _keyPrefix = 'mkw_desktop_titlebar_site_brand_${_cacheVersion}_';
  static const String _legacyIconBytesSuffix = '_icon_bytes';

  Directory? _cacheDir;

  Future<void> _ensureInit() async {
    if (_cacheDir != null && _cacheDir!.existsSync()) return;
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/site_brand_cache');
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
  }

  String _cacheKey(String baseUrl) {
    final normalized = ServerUrlUtils.toApiBaseUrl(baseUrl)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '$_keyPrefix$normalized';
  }

  String _iconFilePath(String cacheKey) => '${_cacheDir!.path}/$cacheKey.png';

  // ---- name ----

  Future<String?> getName(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_cacheKey(baseUrl)}_name');
  }

  Future<void> saveName(String baseUrl, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_cacheKey(baseUrl)}_name', name);
  }

  // ---- icon_url ----

  Future<String?> getIconUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_cacheKey(baseUrl)}_icon_url');
  }

  Future<void> saveIconUrl(String baseUrl, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_cacheKey(baseUrl)}_icon_url', url);
  }

  // ---- icon_bytes（文件系统） ----

  /// 读图标字节。优先读文件；自动迁移旧 _icon_bytes base64 缓存。
  Future<Uint8List?> getIconBytes(String baseUrl) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(baseUrl);
    final file = File(_iconFilePath(cacheKey));

    if (file.existsSync()) {
      try {
        return Uint8List.fromList(file.readAsBytesSync());
      } catch (e) {
        AppLogger.d('SiteBrandCache: 读图标文件失败，尝试迁移旧缓存: $e');
      }
    }

    // 迁移旧 base64 缓存
    final legacyBase64 = prefs.getString('$cacheKey$_legacyIconBytesSuffix');
    if (legacyBase64 != null && legacyBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(legacyBase64);
        await file.writeAsBytes(bytes);
        await prefs.remove('$cacheKey$_legacyIconBytesSuffix');
        AppLogger.d('SiteBrandCache: 迁移旧 base64 图标到文件系统 ($cacheKey)');
        return bytes;
      } catch (e) {
        AppLogger.d('SiteBrandCache: 旧 base64 迁移失败，清理损坏 key: $e');
        await prefs.remove('$cacheKey$_legacyIconBytesSuffix');
      }
    }

    return null;
  }

  Future<void> saveIconBytes(String baseUrl, Uint8List bytes) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(baseUrl);
    final file = File(_iconFilePath(cacheKey));
    await file.writeAsBytes(bytes);
    // 清理可能残留的旧 base64 key
    final legacyKey = '$cacheKey$_legacyIconBytesSuffix';
    if (prefs.containsKey(legacyKey)) {
      await prefs.remove(legacyKey);
    }
  }

  // ---- 清理 ----

  /// 清理指定服务器的所有缓存（文件 + prefs 所有字段）
  Future<void> evict(String baseUrl) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(baseUrl);

    final file = File(_iconFilePath(cacheKey));
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (e) {
        AppLogger.d('SiteBrandCache: 删除图标文件失败: $e');
      }
    }

    await prefs.remove('${cacheKey}_name');
    await prefs.remove('${cacheKey}_icon_url');
    await prefs.remove('$cacheKey$_legacyIconBytesSuffix');
  }

  /// 批量迁移所有旧 base64 缓存到文件系统（启动时后台调用一次）
  ///
  /// 扫描 SharedPreferences 中所有 `mkw_desktop_titlebar_site_brand_*_icon_bytes` key，
  /// base64 解码后写入文件，然后删除旧 key。损坏的旧 key 也清理。
  Future<void> migrateAllLegacy() async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final legacyKeys = keys.where(
      (k) => k.startsWith(_keyPrefix) && k.endsWith(_legacyIconBytesSuffix),
    );

    int migrated = 0;
    int cleaned = 0;
    for (final key in legacyKeys) {
      final base64Text = prefs.getString(key);
      if (base64Text == null || base64Text.isEmpty) {
        await prefs.remove(key);
        cleaned++;
        continue;
      }

      try {
        final bytes = base64Decode(base64Text);
        final cacheKey = key.substring(0, key.length - _legacyIconBytesSuffix.length);
        final file = File(_iconFilePath(cacheKey));
        if (!file.existsSync()) {
          await file.writeAsBytes(bytes);
        }
        await prefs.remove(key);
        migrated++;
      } catch (e) {
        AppLogger.d('SiteBrandCache: 批量迁移 key=$key 失败，清理: $e');
        await prefs.remove(key);
        cleaned++;
      }
    }

    if (migrated > 0 || cleaned > 0) {
      AppLogger.i('SiteBrandCache: 批量迁移完成，迁移 $migrated 个，清理 $cleaned 个损坏 key');
    }
  }
}
