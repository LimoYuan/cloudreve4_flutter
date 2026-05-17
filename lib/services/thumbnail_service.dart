import 'api_service.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/file_utils.dart';

/// 缩略图缓存条目
class _ThumbCacheEntry {
  final String imageUrl;
  final DateTime expiresAt;

  _ThumbCacheEntry({required this.imageUrl, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 缩略图服务 — 获取、解码、缓存 Cloudreve 缩略图 URL。
///
/// Cloudreve V4 Web 前端会对 /file/thumb 返回的 url 执行 TimeFlow 解码。
/// 有些版本不会返回 obfuscated=true，因此这里始终先尝试解码；
/// 解码失败时再把 url 当作普通 URL 使用。
class ThumbnailService {
  static ThumbnailService? _instance;
  static ThumbnailService get instance {
    _instance ??= ThumbnailService._();
    return _instance!;
  }

  ThumbnailService._();

  final Map<String, _ThumbCacheEntry> _urlCache = {};
  final Map<String, Future<String?>> _inFlightRequests = {};

  /// 获取缩略图图片 URL。
  ///
  /// [fileUri] 文件路径，例如 `/path/to/file.jpg` 或 `cloudreve://my/path/to/file.jpg`。
  /// [contextHint] 文件列表接口返回的 context_hint，可加速服务端查询。
  Future<String?> getThumbnailUrl({
    required String fileUri,
    String? contextHint,
  }) async {
    final cacheKey = '$fileUri|${contextHint ?? ''}';

    final cached = _urlCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.imageUrl;
    }
    if (cached != null) {
      _urlCache.remove(cacheKey);
    }

    final inFlight = _inFlightRequests[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchThumbnailUrl(
      fileUri: fileUri,
      contextHint: contextHint,
      cacheKey: cacheKey,
    );
    _inFlightRequests[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<String?> _fetchThumbnailUrl({
    required String fileUri,
    required String? contextHint,
    required String cacheKey,
  }) async {
    try {
      final uri = FileUtils.toCloudreveUri(fileUri);
      final headers = contextHint != null && contextHint.isNotEmpty
          ? <String, dynamic>{'X-Cr-Context-Hint': contextHint}
          : null;

      AppLogger.d('ThumbnailService: request uri=$uri contextHint=${contextHint ?? ''}');

      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/file/thumb',
        queryParameters: {'uri': uri},
        headers: headers,
      );

      AppLogger.d('ThumbnailService: raw response for $fileUri = $response');

      final thumbResponse = _normalizeThumbResponse(response);
      if (thumbResponse == null) {
        AppLogger.d('ThumbnailService: no thumbnail URL field for $fileUri');
        return null;
      }

      final rawUrl = thumbResponse.url.trim();
      if (rawUrl.isEmpty) {
        return null;
      }

      // Cloudreve 官方前端会直接对 c.url 做 TimeFlow 解码。
      // 这里也先尝试解码，不依赖 obfuscated 字段是否存在。
      final decodedUrl = _decodeCloudreveTimeFlowUrl(rawUrl);
      var finalUrl = decodedUrl?.trim().isNotEmpty == true ? decodedUrl!.trim() : rawUrl;

      finalUrl = _toAbsoluteUrl(finalUrl);
      if (finalUrl.isEmpty) {
        return null;
      }

      final expiresAt = _parseExpiresAt(thumbResponse.expires);
      _urlCache[cacheKey] = _ThumbCacheEntry(
        imageUrl: finalUrl,
        expiresAt: expiresAt,
      );

      AppLogger.d('ThumbnailService: resolved URL for $fileUri = $finalUrl');
      return finalUrl;
    } catch (e) {
      // 没有缩略图时不要影响文件列表，直接回退图标。
      AppLogger.d('ThumbnailService: failed to get thumbnail URL for $fileUri: $e');
      return null;
    }
  }

  _ThumbResponse? _normalizeThumbResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return _normalizeThumbResponse(data);
    }

    final directUrl = _firstNonEmptyString([
      response['url'],
      response['src'],
      response['thumb'],
      response['thumbnail'],
      response['thumbnail_url'],
      response['preview_url'],
    ]);

    String? url = directUrl;

    if (url == null) {
      final urls = response['urls'];
      if (urls is List && urls.isNotEmpty) {
        final first = urls.first;
        if (first is Map<String, dynamic>) {
          url = _firstNonEmptyString([
            first['url'],
            first['src'],
            first['thumb'],
            first['thumbnail'],
            first['thumbnail_url'],
            first['preview_url'],
          ]);
        } else if (first is String && first.isNotEmpty) {
          url = first;
        }
      }
    }

    if (url == null || url.isEmpty) return null;

    final expires = _firstNonEmptyString([
      response['expires'],
      response['expire'],
      response['expired_at'],
      response['expires_at'],
    ]);

    return _ThumbResponse(url: url, expires: expires);
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  /// Cloudreve V4 Web 前端的 TimeFlow 解码逻辑 Dart 版。
  ///
  /// 官方前端逻辑等价于：
  ///   now = floor(Date.now()/1000)
  ///   try decode(url, now), decode(url, now-1000), decode(url, now+1000)
  String? _decodeCloudreveTimeFlowUrl(String encoded) {
    if (encoded.isEmpty) return null;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final timestamp in [nowSeconds, nowSeconds - 1000, nowSeconds + 1000]) {
      try {
        final decoded = _decodeTimeFlowString(encoded, timestamp);
        if (decoded.isNotEmpty) return decoded;
      } catch (_) {
        // Try next timestamp window.
      }
    }
    return null;
  }

  String _decodeTimeFlowString(String value, int timestampSeconds) {
    final reducedTimestamp = timestampSeconds ~/ 1000;
    final digits = <int>[];
    var t = reducedTimestamp;

    if (value.isEmpty) return '';
    while (t > 0) {
      digits.add(t % 10);
      t ~/= 10;
    }
    if (digits.isEmpty) {
      throw StateError('Invalid timestamp');
    }

    final output = value.split('');
    var working = value.split('');
    var even = working.length.isEven;
    var digitIndex = (working.length - 1) % digits.length;
    final originalLength = working.length;

    for (var step = 0; step < originalLength; step++) {
      var sourceIndex = output.length - 1 - step;

      if (even) {
        sourceIndex = sourceIndex + digits[digitIndex] * digitIndex;
      } else {
        sourceIndex = 2 * digitIndex * digits[digitIndex] - sourceIndex;
      }

      if (sourceIndex < 0) {
        sourceIndex = -sourceIndex;
      }
      sourceIndex = sourceIndex % working.length;

      final outputIndex = output.length - 1 - step;
      output[outputIndex] = working[sourceIndex];

      final tmp = working[outputIndex];
      working[outputIndex] = working[sourceIndex];
      working[sourceIndex] = tmp;
      working = working.sublist(0, working.length - 1);

      even = !even;
      digitIndex--;
      if (digitIndex < 0) {
        digitIndex = digits.length - 1;
      }
    }

    final decoded = output.join();
    final parts = decoded.split('|');
    if (parts.isEmpty || parts.first != reducedTimestamp.toString()) {
      throw StateError('Invalid time flow string');
    }

    return decoded.substring(parts.first.length + 1);
  }

  DateTime _parseExpiresAt(String? expiresStr) {
    if (expiresStr == null || expiresStr.isEmpty) {
      return DateTime.now().add(const Duration(minutes: 5));
    }

    try {
      return DateTime.parse(expiresStr).subtract(const Duration(seconds: 30));
    } catch (_) {
      return DateTime.now().add(const Duration(minutes: 5));
    }
  }

  String _toAbsoluteUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final baseUrl = ApiService.instance.dio.options.baseUrl;
    if (baseUrl.isEmpty) return value;

    try {
      final base = Uri.parse(baseUrl);

      if (value.startsWith('//')) {
        return '${base.scheme.isEmpty ? 'https' : base.scheme}:$value';
      }

      if (value.startsWith('/')) {
        final origin = Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
        );
        return origin.resolve(value).toString();
      }

      final baseForRelative = baseUrl.endsWith('/') ? base : Uri.parse('$baseUrl/');
      return baseForRelative.resolve(value).toString();
    } catch (_) {
      return value;
    }
  }

  /// 移除指定文件的缓存 URL。
  void evictUrl(String fileUri) {
    _urlCache.removeWhere((key, _) => key == fileUri || key.startsWith('$fileUri|'));
  }

  /// 清空所有缓存。
  void clearAll() {
    _urlCache.clear();
    _inFlightRequests.clear();
  }
}

class _ThumbResponse {
  final String url;
  final String? expires;

  const _ThumbResponse({required this.url, this.expires});
}
