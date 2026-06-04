/// 服务器地址规范化工具。
///
/// Cloudreve V4 的 API 基础地址需要指向 `/api/v4`，但用户在登录页通常会输入
/// `cloud.example.com` 或 `https://cloud.example.com`。在 Windows / Android / iOS 等
/// 非 Web 平台，Dio 的 baseUrl 必须是完整 URL，因此这里统一补全协议并规范路径。
class ServerUrlUtils {
  ServerUrlUtils._();

  static final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

  /// 补全协议、去掉末尾斜杠、去掉 query/fragment。
  ///
  /// 示例：
  /// - `cloud.example.com` -> `https://cloud.example.com`
  /// - `https://cloud.example.com/` -> `https://cloud.example.com`
  /// - `https://cloud.example.com/api/v4` -> `https://cloud.example.com/api/v4`
  static String toAbsoluteUrl(String value, {String defaultScheme = 'https'}) {
    var url = value.trim();
    if (url.isEmpty) return url;

    if (url.startsWith('//')) {
      url = '$defaultScheme:$url';
    } else if (!_schemePattern.hasMatch(url)) {
      url = '$defaultScheme://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return _trimTrailingSlash(url);
    }

    return _trimTrailingSlash(
      uri.replace(query: null, fragment: null).toString(),
    );
  }

  /// 返回站点根地址，去掉 `/api/v4`。
  ///
  /// 示例：
  /// - `cloud.example.com` -> `https://cloud.example.com`
  /// - `https://cloud.example.com/api/v4` -> `https://cloud.example.com`
  static String toSiteBaseUrl(String value, {String defaultScheme = 'https'}) {
    final absolute = toAbsoluteUrl(value, defaultScheme: defaultScheme);
    final uri = Uri.tryParse(absolute);
    if (uri == null || uri.host.isEmpty) return absolute;

    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (_endsWithApiV4(segments)) {
      segments.removeLast();
      segments.removeLast();
    }

    return _trimTrailingSlash(
      uri.replace(path: _pathFromSegments(segments), query: null, fragment: null).toString(),
    );
  }

  /// 返回 Cloudreve V4 API 基础地址，确保结尾为 `/api/v4`。
  ///
  /// 示例：
  /// - `cloud.example.com` -> `https://cloud.example.com/api/v4`
  /// - `https://cloud.example.com` -> `https://cloud.example.com/api/v4`
  /// - `https://cloud.example.com/api/v4` -> `https://cloud.example.com/api/v4`
  static String toApiBaseUrl(String value, {String defaultScheme = 'https'}) {
    final site = toSiteBaseUrl(value, defaultScheme: defaultScheme);
    if (site.isEmpty) return site;

    final uri = Uri.tryParse(site);
    if (uri == null || uri.host.isEmpty) return site;

    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (!_endsWithApiV4(segments)) {
      segments.addAll(const ['api', 'v4']);
    }

    return _trimTrailingSlash(
      uri.replace(path: _pathFromSegments(segments), query: null, fragment: null).toString(),
    );
  }

  static bool _endsWithApiV4(List<String> segments) {
    if (segments.length < 2) return false;
    final last = segments[segments.length - 1].toLowerCase();
    final prev = segments[segments.length - 2].toLowerCase();
    return prev == 'api' && last == 'v4';
  }

  static String _pathFromSegments(List<String> segments) {
    if (segments.isEmpty) return '';
    return '/${segments.map(Uri.encodeComponent).join('/')}';
  }

  static String _trimTrailingSlash(String value) {
    var result = value.trim();
    while (result.length > 1 && result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
