/// 缓存设置模型
class CacheSettingsModel {
  /// 最大缓存大小（字节）
  final int maxCacheSize;

  /// 缓存过期时间（毫秒）
  final int cacheExpireDuration;

  /// 是否自动清理最旧文件
  final bool autoCleanOldFiles;

  CacheSettingsModel({
    this.maxCacheSize = 500 * 1024 * 1024, // 默认500MB
    this.cacheExpireDuration = 7 * 24 * 60 * 60 * 1000, // 默认7天
    this.autoCleanOldFiles = true,
  });

  factory CacheSettingsModel.fromJson(Map<String, dynamic> json) {
    return CacheSettingsModel(
      maxCacheSize: json['max_cache_size'] as int? ?? 500 * 1024 * 1024,
      cacheExpireDuration:
          json['cache_expire_duration'] as int? ?? 7 * 24 * 60 * 60 * 1000,
      autoCleanOldFiles: json['auto_clean_old_files'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_cache_size': maxCacheSize,
      'cache_expire_duration': cacheExpireDuration,
      'auto_clean_old_files': autoCleanOldFiles,
    };
  }

  /// 获取人类可读的最大缓存大小
  String get maxCacheSizeReadable {
    return _formatBytes(maxCacheSize);
  }

  /// 获取人类可读的缓存过期时间
  String get cacheExpireDurationReadable {
    final days = cacheExpireDuration ~/ (24 * 60 * 60 * 1000);
    if (days > 0) {
      return '$days天';
    }
    final hours = cacheExpireDuration ~/ (60 * 60 * 1000);
    if (hours > 0) {
      return '$hours小时';
    }
    final minutes = cacheExpireDuration ~/ (60 * 1000);
    return '$minutes分钟';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 从MB创建
  static CacheSettingsModel fromMB(int maxCacheSizeMB) {
    return CacheSettingsModel(maxCacheSize: maxCacheSizeMB * 1024 * 1024);
  }

  /// 从天数创建
  static CacheSettingsModel fromDays(int days) {
    return CacheSettingsModel(
      cacheExpireDuration: days * 24 * 60 * 60 * 1000,
    );
  }

  /// 创建副本
  CacheSettingsModel copyWith({
    int? maxCacheSize,
    int? cacheExpireDuration,
    bool? autoCleanOldFiles,
  }) {
    return CacheSettingsModel(
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      cacheExpireDuration: cacheExpireDuration ?? this.cacheExpireDuration,
      autoCleanOldFiles: autoCleanOldFiles ?? this.autoCleanOldFiles,
    );
  }

  /// 获取可用预设大小选项
  static List<int> get availableSizes => [100, 250, 500, 1000, 2000]; // MB

  /// 获取可用预设过期时间选项
  static List<int> get availableDurations => [1, 3, 7, 15, 30]; // 天
}
