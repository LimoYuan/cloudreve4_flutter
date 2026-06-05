import 'package:dio/dio.dart';

import '../core/utils/app_logger.dart';
import '../core/utils/file_utils.dart';
import '../data/models/share_model.dart';
import 'api_service.dart';

/// 分享来源类型：同源 / 异源
enum ShareSourceKind { sameOrigin, crossOrigin }

/// 从 URL 中提取的分享链接候选
class ShareLinkCandidate {
  final String id;
  final String url;
  final String? password;

  const ShareLinkCandidate({
    required this.id,
    required this.url,
    this.password,
  });

  @override
  String toString() =>
      'ShareLinkCandidate(id=$id, url=$url, password=${password == null ? null : '***'})';
}

/// /file 接口返回的分享目录项
class ShareLinkFile {
  final int type;
  final String id;
  final String name;
  final int size;
  final String path;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? primaryEntity;

  const ShareLinkFile({
    required this.type,
    required this.id,
    required this.name,
    required this.size,
    required this.path,
    this.createdAt,
    this.updatedAt,
    this.primaryEntity,
  });

  bool get isFolder => type == 1;
  bool get isFile => !isFolder;

  factory ShareLinkFile.fromJson(Map<String, dynamic> json) {
    return ShareLinkFile(
      type: _asInt(json['type']),
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名',
      size: _asInt(json['size']),
      path: json['path']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      primaryEntity:
          json['primary_entity']?.toString() ?? json['entity']?.toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class ShareLinkFileListResult {
  final List<ShareLinkFile> files;
  final String? contextHint;
  final bool hasMore;
  final String? nextPageToken;

  const ShareLinkFileListResult({
    required this.files,
    this.contextHint,
    this.hasMore = false,
    this.nextPageToken,
  });
}

/// 预签名下载 URL
class ShareDownloadUrlResult {
  final String url;
  final DateTime? expires;

  const ShareDownloadUrlResult({required this.url, this.expires});
}

/// 分享上下文，封装一次会话需要的所有信息。
class ShareContext {
  final String id;
  final String? password;
  final String shareUrl;
  final Uri originUri;
  final ShareSourceKind sourceKind;
  String? contextHint;

  ShareContext({
    required this.id,
    required this.password,
    required this.shareUrl,
    required this.originUri,
    required this.sourceKind,
    this.contextHint,
  });

  bool get isSameOrigin => sourceKind == ShareSourceKind.sameOrigin;

  /// `cloudreve://id[:pwd]@share/...`
  String buildShareUri({String? subPath, bool trailingSlash = false}) {
    final encodedId = Uri.encodeComponent(id);
    final pw = password?.trim();
    final userInfo =
        pw == null || pw.isEmpty ? encodedId : '$encodedId:${Uri.encodeComponent(pw)}';
    final buffer = StringBuffer('cloudreve://$userInfo@share');
    final sub = subPath?.trim();
    if (sub != null && sub.isNotEmpty) {
      buffer.write('/');
      final segments = sub
          .split('/')
          .where((seg) => seg.isNotEmpty)
          .map((seg) => Uri.encodeComponent(Uri.decodeComponent(seg)));
      buffer.write(segments.join('/'));
    } else if (trailingSlash) {
      buffer.write('/');
    }
    return buffer.toString();
  }
}

/// Cloudreve V4 分享链接服务。
///
/// - 内部维护独立的 `_shareDio`，**不挂 token / 401 刷新拦截器**，
///   避免分享会话被 auth 流程意外接管。
/// - 三个原子方法：
///     `fetchShareInfo` / `listSharedFiles` / `resolveDownloadUrl`
/// - 同源/异源判断走 host+port+scheme。
class ShareLinkService {
  ShareLinkService._() {
    _shareDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: const {'Content-Type': 'application/json'},
        // 由 Cloudreve 统一返回 200 + code，这里允许所有状态码自己处理。
        validateStatus: (_) => true,
      ),
    )..interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (line) => AppLogger.d('[ShareDio] $line'),
        ),
      );
  }

  static final ShareLinkService instance = ShareLinkService._();

  late final Dio _shareDio;

  static final RegExp _shareLinkRegExp = RegExp(
    r'https?://\S+?/s/([A-Za-z0-9_-]+)(?:/([A-Za-z0-9_-]+))?',
    caseSensitive: false,
  );

  /// 从一段文本中提取分享链接候选。
  ShareLinkCandidate? parseShareLink(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = _shareLinkRegExp.firstMatch(text.trim());
    if (match == null) return null;
    final id = match.group(1);
    if (id == null || id.isEmpty) return null;
    final password = match.group(2);
    return ShareLinkCandidate(
      id: id,
      url: match.group(0)!,
      password: password == null || password.isEmpty ? null : password,
    );
  }

  /// 判断分享链接相对当前已登录服务的来源类型。
  ///
  /// 规则：host + port + scheme 完全一致才视为同源。
  ShareSourceKind classifyOrigin(String shareUrl) {
    final shareUri = Uri.tryParse(shareUrl);
    final baseUri = Uri.tryParse(ApiService.instance.dio.options.baseUrl);
    if (shareUri == null || baseUri == null) return ShareSourceKind.crossOrigin;

    final same = shareUri.scheme == baseUri.scheme &&
        shareUri.host == baseUri.host &&
        _effectivePort(shareUri) == _effectivePort(baseUri);
    return same ? ShareSourceKind.sameOrigin : ShareSourceKind.crossOrigin;
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    if (uri.scheme == 'http') return 80;
    if (uri.scheme == 'https') return 443;
    return 0;
  }

  /// 解析分享 host 形成 baseUrl，用于 _shareDio。
  ///
  /// 异源分享要走分享方服务器，不能复用当前 auth baseUrl。
  String _baseUrlFor(ShareContext context) {
    final origin = context.originUri;
    final port = origin.hasPort ? ':${origin.port}' : '';
    return '${origin.scheme}://${origin.host}$port/api/v4';
  }

  /// 创建一个分享上下文（确定来源类型、归一化原始 URL）。
  ShareContext createContext(ShareLinkCandidate candidate) {
    final origin = Uri.parse(candidate.url);
    final kind = classifyOrigin(candidate.url);
    return ShareContext(
      id: candidate.id,
      password: candidate.password,
      shareUrl: candidate.url,
      originUri: origin,
      sourceKind: kind,
    );
  }

  // ──────────────────────────── 原子方法 1：fetchShareInfo ────────────────────────────

  /// GET /share/info/{id}[?password=xxx]
  ///
  /// 始终返回 ShareModel；调用方根据 `expired` / `passwordProtected` / `unlocked`
  /// 决定下一步行为。失败时抛出包含 code/msg 的异常。
  Future<ShareModel> fetchShareInfo(ShareContext context) async {
    final query = <String, dynamic>{
      'count_views': true,
      'owner_extended': true,
      if (context.password != null && context.password!.isNotEmpty)
        'password': context.password,
    };

    final response = await _shareDio.get<Map<String, dynamic>>(
      '${_baseUrlFor(context)}/share/info/${context.id}',
      queryParameters: query,
      options: Options(headers: const {'X-Cr-Context-Hint': 'share'}),
    );

    final body = response.data ?? <String, dynamic>{};
    final code = body['code'] as int?;
    final msg = body['msg']?.toString() ?? '';
    if (code != 0) {
      // 服务端常见错误：404 Share link expired
      throw ShareException(code ?? -1, msg.isEmpty ? '分享信息读取失败' : msg);
    }

    final data = _asMap(body['data']) ?? body;
    final headerContext = _headerValue(response.headers, 'X-Cr-Context-Hint');
    if (headerContext != null && headerContext.isNotEmpty) {
      context.contextHint = headerContext;
    }
    return ShareModel.fromJson(Map<String, dynamic>.from(data));
  }

  // ──────────────────────────── 原子方法 2：listSharedFiles ────────────────────────────

  /// 列分享目录（用于目录类型分享 source_type=1，浏览子目录）。
  ///
  /// uri 是 `cloudreve://id[:pwd]@share[/sub/path]`。
  Future<ShareLinkFileListResult> listSharedFiles({
    required ShareContext context,
    required String uri,
    int page = 0,
    int pageSize = 100,
    String? nextPageToken,
  }) async {
    final response = await _shareDio.get<Map<String, dynamic>>(
      '${_baseUrlFor(context)}/file',
      queryParameters: <String, dynamic>{
        'uri': uri,
        'page': page,
        'page_size': pageSize,
        if (nextPageToken != null && nextPageToken.isNotEmpty)
          'next_page_token': nextPageToken,
      },
      options: Options(
        headers: <String, dynamic>{
          'X-Cr-Context-Hint': context.contextHint ?? 'share',
        },
      ),
    );

    final body = response.data ?? <String, dynamic>{};
    final code = body['code'] as int?;
    if (code != null && code != 0) {
      throw ShareException(code, body['msg']?.toString() ?? '分享目录读取失败');
    }

    final data = _asMap(body['data']) ?? body;
    final rawFiles = data['files'];
    final pagination = _asMap(data['pagination']);
    final headerContext = _headerValue(response.headers, 'X-Cr-Context-Hint');
    if (headerContext != null && headerContext.isNotEmpty) {
      context.contextHint = headerContext;
    }

    return ShareLinkFileListResult(
      files: rawFiles is List
          ? rawFiles
              .whereType<Map>()
              .map((item) =>
                  ShareLinkFile.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      contextHint: data['context_hint']?.toString() ?? headerContext,
      hasMore: pagination?['next_token'] != null,
      nextPageToken: pagination?['next_token']?.toString(),
    );
  }

  // ──────────────────────────── 原子方法 3：resolveDownloadUrl ──────────────────────

  /// POST /file/url 拿预签名下载 URL。
  ///
  /// - 单文件分享：fileName 传 ShareModel.name，subPath 留空（默认按 name 拼）。
  /// - 目录中具体子文件：传 candidateUri，跳过自动拼 share root。
  /// - 整个目录打包：archive=true，candidateUri 传 share root（trailingSlash=true）。
  ///
  /// 首选 URI：`cloudreve://id[:pwd]@share/{fileName}`
  /// 失败时按用户偏好启用兜底（_legacyUriCandidates）。
  Future<ShareDownloadUrlResult> resolveDownloadUrl({
    required ShareContext context,
    String? candidateUri,
    String? fileName,
    bool archive = false,
  }) async {
    final tried = <String>[];
    final List<String> uris = <String>[];

    void addUri(String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty && !uris.contains(text)) {
        uris.add(text);
      }
    }

    if (candidateUri != null && candidateUri.trim().isNotEmpty) {
      addUri(candidateUri.trim());
    } else if (archive) {
      addUri(context.buildShareUri(trailingSlash: true));
    } else if (fileName != null && fileName.trim().isNotEmpty) {
      addUri(context.buildShareUri(subPath: fileName.trim()));
    } else {
      addUri(context.buildShareUri(trailingSlash: true));
    }

    // 兜底：仅在首选失败时再尝试这些。
    uris.addAll(_legacyUriCandidates(
      primary: uris.first,
      context: context,
      fileName: fileName,
      archive: archive,
    ));

    Object? lastError;
    for (final uri in uris.toSet()) {
      tried.add(uri);
      try {
        return await _postFileUrl(
          context: context,
          uri: uri,
          archive: archive,
        );
      } catch (e) {
        lastError = e;
        AppLogger.d('[Share] resolveDownloadUrl 失败 uri=$uri error=$e');
        // 权限类错误是终止性的，没必要继续兜底尝试其它 URI
        if (e is ShareException && e.code == 40007) {
          rethrow;
        }
      }
    }

    throw lastError ??
        ShareException(-1, '获取下载链接失败，已尝试 ${tried.length} 个 URI');
  }

  Future<ShareDownloadUrlResult> _postFileUrl({
    required ShareContext context,
    required String uri,
    bool archive = false,
  }) async {
    final body = <String, dynamic>{
      'uris': <String>[uri],
      'download': true,
      if (archive) 'archive': true,
    };

    final response = await _shareDio.post<Map<String, dynamic>>(
      '${_baseUrlFor(context)}/file/url',
      data: body,
      options: Options(
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'X-Cr-Context-Hint': context.contextHint ?? 'share',
        },
      ),
    );

    final raw = response.data ?? <String, dynamic>{};
    final code = raw['code'] as int?;
    if (code != null && code != 0) {
      throw ShareException(code, raw['msg']?.toString() ?? '下载链接获取失败');
    }

    final data = _asMap(raw['data']) ?? raw;
    final url = _extractDownloadUrl(data) ?? _extractDownloadUrl(raw);
    if (url == null || url.isEmpty) {
      throw ShareException(-1, '服务端未返回可用下载链接');
    }
    return ShareDownloadUrlResult(
      url: url,
      expires: _parseDate(data['expires'] ?? raw['expires']),
    );
  }

  /// 兜底 URI 候选：来源于历史多重试探逻辑。
  ///
  /// 优先使用标准 `cloudreve://id[:pwd]@share/fileName`；
  /// 当服务端拒绝时，再尝试 URL 编码版本、带斜杠版本、share root 等。
  List<String> _legacyUriCandidates({
    required String primary,
    required ShareContext context,
    String? fileName,
    bool archive = false,
  }) {
    final out = <String>[];
    void add(String? v) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty && t != primary && !out.contains(t)) {
        out.add(t);
      }
    }

    add(context.buildShareUri(trailingSlash: true));
    add(context.buildShareUri(trailingSlash: false));

    final name = fileName?.trim();
    if (name != null && name.isNotEmpty) {
      add(context.buildShareUri(subPath: name));
      // 用 dart 默认 encodeComponent 没编码到的字符（如 +）
      add(context.buildShareUri(subPath: Uri.encodeComponent(name)));
    }

    return out;
  }

  // ──────────────────────────── 工具 ────────────────────────────

  /// 转存接口（仅同源可用）：POST /file/move with copy=true
  ///
  /// 与原实现保持一致；走 ApiService 主 dio（需要 token）。
  Future<void> saveSharedFiles({
    required ShareContext context,
    required List<String> uris,
    required String destination,
  }) async {
    final dst = FileUtils.toCloudreveUri(destination);
    final cleaned = uris
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      throw ShareException(-1, '没有可转存的文件');
    }

    await ApiService.instance.post<void>(
      '/file/move',
      data: <String, dynamic>{
        'uris': cleaned,
        'dst': dst,
        'copy': true,
      },
      headers: <String, dynamic>{
        'Content-Type': 'application/json',
        'X-Cr-Context-Hint': context.contextHint ?? 'share',
      },
    );
  }

  /// 同源用户头像 URL（异源无法访问，返回 null）。
  String? ownerAvatarUrl(ShareContext context, ShareModel info) {
    if (!context.isSameOrigin) return null;
    final ownerId = info.owner?.id;
    if (ownerId == null || ownerId.isEmpty) return null;
    final base = ApiService.instance.dio.options.baseUrl
        .replaceFirst(RegExp(r'/+$'), '');
    return '$base/user/avatar/${Uri.encodeComponent(ownerId)}';
  }

  // ──────────────────────────── 私有工具 ────────────────────────────

  static String? _extractDownloadUrl(Map<String, dynamic> data) {
    final direct = data['url'] ??
        data['download_url'] ??
        data['downloadUrl'] ??
        data['src'] ??
        data['href'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();

    final rawUrls = data['urls'];
    if (rawUrls is String && rawUrls.trim().isNotEmpty) return rawUrls.trim();
    if (rawUrls is List) {
      for (final item in rawUrls) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
        final map = _asMap(item);
        if (map == null) continue;
        final url = _extractDownloadUrl(map);
        if (url != null && url.isNotEmpty) return url;
      }
    }
    if (rawUrls is Map) {
      for (final item in rawUrls.values) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
        final map = _asMap(item);
        if (map == null) continue;
        final url = _extractDownloadUrl(map);
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? _headerValue(Headers headers, String name) {
    final direct = headers.value(name) ?? headers.value(name.toLowerCase());
    if (direct != null && direct.isNotEmpty) return direct;
    final lower = name.toLowerCase();
    for (final entry in headers.map.entries) {
      if (entry.key.toLowerCase() == lower && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }
}

/// 分享接口业务异常。
class ShareException implements Exception {
  final int code;
  final String message;
  ShareException(this.code, this.message);

  @override
  String toString() => '[$code] $message';
}
