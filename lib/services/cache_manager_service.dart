import 'dart:convert';
import 'dart:io';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/cache_settings_model.dart';
import '../core/constants/storage_keys.dart';
import 'storage_service.dart';

/// 缓存管理器服务
class CacheManagerService {
  static CacheManagerService? _instance;
  BaseCacheManager? _manager;
  CacheSettingsModel _settings = CacheSettingsModel();

  CacheManagerService._();

  /// 获取单例
  static CacheManagerService get instance {
    _instance ??= CacheManagerService._();
    return _instance!;
  }

  /// 初始化
  Future<void> initialize() async {
    try {
      await loadSettings();
      await _initializeManager();
    } catch (e) {
      // 忽略初始化错误，使用默认值
      AppLogger.e('CacheManagerService initialize error: $e');
    }
  }

  /// 初始化管理器
  Future<void> _initializeManager() async {
    _manager = CacheManager(
      Config(
        'cloudreve_cache',
        stalePeriod: Duration(milliseconds: _settings.cacheExpireDuration),
        maxNrOfCacheObjects: 1000,
      ),
    );
  }

  /// 获取缓存管理器
  BaseCacheManager get manager {
    if (_manager == null) {
      throw Exception('CacheManagerService 未初始化，请先调用 initialize()');
    }
    return _manager!;
  }

  /// 获取缓存目录
  Future<Directory> getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/cloudreve_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return cacheDir;
  }

  /// 获取当前缓存大小
  Future<int> getCacheSize() async {
    final cacheDir = await getCacheDir();
    if (!cacheDir.existsSync()) {
      return 0;
    }

    try {
      int totalSize = 0;
      final entities = cacheDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            totalSize += entity.lengthSync();
          } catch (e) {
            // 忽略无法读取的文件
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// 清空缓存
  Future<void> clearCache() async {
    final cacheDir = await getCacheDir();
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
    await _manager?.emptyCache();
    await _initializeManager();
  }

  /// 清理过期文件
  Future<void> cleanExpiredFiles() async {
    try {
      await manager.emptyCache();
    } catch (e) {
      // 忽略清理错误
    }
  }

  /// 加载设置
  Future<void> loadSettings() async {
    final settingsJson = await StorageService.instance.getString(
      StorageKeys.cacheSettings,
    );
    if (settingsJson != null && settingsJson.isNotEmpty) {
      try {
        final settings = CacheSettingsModel.fromJson(
          jsonDecode(settingsJson) as Map<String, dynamic>,
        );
        _settings = settings;
      } catch (e) {
        // 使用默认设置
      }
    }
  }

  /// 保存设置
  Future<void> saveSettings(CacheSettingsModel settings) async {
    _settings = settings;
    await StorageService.instance.setString(
      StorageKeys.cacheSettings,
      jsonEncode(settings.toJson()),
    );
    await _initializeManager();
  }

  /// 获取当前设置
  CacheSettingsModel get settings => _settings;

  /// 获取缓存文件信息
  Future<List<CacheFileInfo>> getCacheFiles() async {
    final cacheDir = await getCacheDir();
    final files = <CacheFileInfo>[];

    if (!cacheDir.existsSync()) {
      return files;
    }

    await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          files.add(
            CacheFileInfo(
              path: entity.path,
              name: entity.uri.pathSegments.last,
              size: stat.size,
              lastModified: stat.modified,
            ),
          );
        } catch (e) {
          // 忽略无法读取的文件
        }
      }
    }

    return files;
  }

  /// 删除指定的缓存文件
  Future<void> deleteCacheFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// 自动清理最旧文件（当超过最大缓存大小时）
  Future<void> autoCleanOldFiles() async {
    if (!_settings.autoCleanOldFiles) {
      return;
    }

    final currentSize = await getCacheSize();
    if (currentSize <= _settings.maxCacheSize) {
      return;
    }

    final files = await getCacheFiles();
    // 按最后修改时间排序，最旧的在前
    files.sort((a, b) => a.lastModified.compareTo(b.lastModified));

    int deletedSize = 0;
    for (final file in files) {
      if (currentSize - deletedSize <= _settings.maxCacheSize) {
        break;
      }
      await deleteCacheFile(file.path);
      deletedSize += file.size;
    }
  }
}

/// 缓存文件信息
class CacheFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;

  CacheFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
  });

  String get sizeReadable {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
