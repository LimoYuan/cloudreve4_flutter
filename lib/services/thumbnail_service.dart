import 'api_service.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/file_utils.dart';
import '../core/utils/time_flow_decoder.dart';

/// 缩略图缓存条目
class _ThumbCacheEntry {
  final String imageUrl;
  final DateTime expiresAt;

  _ThumbCacheEntry({required this.imageUrl, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 缩略图服务 — 获取、解码、缓存缩略图 URL
class ThumbnailService {
  static ThumbnailService? _instance;
  static ThumbnailService get instance {
    _instance ??= ThumbnailService._();
    return _instance!;
  }

  ThumbnailService._();

  // 内存缓存: fileUri -> cache entry
  final Map<String, _ThumbCacheEntry> _urlCache = {};

  // 请求去重: fileUri -> in-flight Future
  final Map<String, Future<String?>> _inFlightRequests = {};

  /// 获取缩略图图片 URL
  /// [fileUri] 文件的 relativePath（如 /path/to/file.jpg）
  /// [contextHint] 可选，加速服务端 DB 查询
  Future<String?> getThumbnailUrl({
    required String fileUri,
    String? contextHint,
  }) async {
    final cacheKey = fileUri;

    // 1. 检查内存缓存
    final cached = _urlCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.imageUrl;
    }
    if (cached != null) {
      _urlCache.remove(cacheKey);
    }

    // 2. 检查请求去重
    final inFlight = _inFlightRequests[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    // 3. 发起请求
    final future = _fetchThumbnailUrl(fileUri, contextHint);
    _inFlightRequests[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<String?> _fetchThumbnailUrl(String fileUri, String? contextHint) async {
    try {
      final uri = FileUtils.toCloudreveUri(fileUri);
      final headers = contextHint != null
          ? <String, dynamic>{'X-Cr-Context-Hint': contextHint}
          : null;

      // _parseResponse 已提取 ApiResponse.data，response 即 {url, obfuscated, expires}
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/file/thumb',
        queryParameters: {'uri': uri},
        headers: headers,
      );

      AppLogger.d('ThumbnailService: response for $fileUri = $response');

      var url = response['url'] as String? ?? '';
      final obfuscated = response['obfuscated'] as bool? ?? false;
      final expiresStr = response['expires'] as String?;

      // 解码混淆 URL
      if (obfuscated && url.isNotEmpty) {
        final decoded = TimeFlowDecoder.decodeTimeFlowString(url);
        if (decoded == null) {
          AppLogger.w('Failed to decode obfuscated thumbnail URL for $fileUri');
          return null;
        }
        url = decoded;
      }

      if (url.isEmpty) return null;

      AppLogger.d('ThumbnailService: resolved URL for $fileUri = $url');

      // 解析过期时间，缓存提前 30 秒过期
      DateTime expiresAt;
      if (expiresStr != null) {
        try {
          expiresAt = DateTime.parse(expiresStr).subtract(const Duration(seconds: 30));
        } catch (_) {
          expiresAt = DateTime.now().add(const Duration(minutes: 5));
        }
      } else {
        expiresAt = DateTime.now().add(const Duration(minutes: 5));
      }

      // 存入内存缓存
      _urlCache[fileUri] = _ThumbCacheEntry(
        imageUrl: url,
        expiresAt: expiresAt,
      );

      return url;
    } catch (e) {
      AppLogger.d('ThumbnailService: failed to get thumbnail URL for $fileUri: $e');
      return null;
    }
  }

  /// 移除指定文件的缓存 URL
  void evictUrl(String fileUri) {
    _urlCache.remove(fileUri);
  }

  /// 清空所有缓存（目录切换时调用）
  void clearAll() {
    _urlCache.clear();
    _inFlightRequests.clear();
  }
}
