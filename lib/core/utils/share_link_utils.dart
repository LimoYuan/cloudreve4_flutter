/// Cloudreve 分享链接识别工具。
///
/// 只负责从文本中提取分享 ID 和提取码，不负责跳转外部网页。
class ShareLinkParseResult {
  final String originalText;
  final String originalUrl;
  final String normalizedUrl;
  final String shareId;
  final String? password;

  const ShareLinkParseResult({
    required this.originalText,
    required this.originalUrl,
    required this.normalizedUrl,
    required this.shareId,
    this.password,
  });
}

class ShareLinkUtils {
  ShareLinkUtils._();

  static final RegExp _urlPattern = RegExp(
    r'''((?:https?:\/\/|cloudreve:\/\/|cloudreve4:\/\/|www\.)[^\s一-龥<>"']+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:\/[^\s一-龥<>"']*)?)''',
    caseSensitive: false,
  );

  static final RegExp _passwordTextPattern = RegExp(
    r'(?:提取码|访问码|取件码|密码|pass(?:word)?|pwd|code)\s*[:：]?\s*([A-Za-z0-9_-]{2,32})',
    caseSensitive: false,
  );

  static const Set<String> _shareSegmentNames = {'s', 'share', 'shares'};
  static const Set<String> _passwordKeys = {
    'password',
    'pwd',
    'pass',
    'code',
    'p',
    'access_code',
    'accessCode',
  };
  static const Set<String> _shareIdKeys = {
    'id',
    'share_id',
    'shareId',
    'sid',
    'share',
  };

  static ShareLinkParseResult? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final candidates = <String>[];
    final matches = _urlPattern.allMatches(trimmed).toList();
    if (matches.isEmpty) {
      candidates.add(trimmed);
    } else {
      candidates.addAll(
        matches.map((m) => m.group(0) ?? '').where((e) => e.isNotEmpty),
      );
      if (!candidates.contains(trimmed)) candidates.add(trimmed);
    }

    for (final candidate in candidates) {
      final result = _tryParseCandidate(trimmed, candidate);
      if (result != null) return result;
    }
    return null;
  }

  static ShareLinkParseResult? _tryParseCandidate(
    String originalText,
    String candidate,
  ) {
    var url = _stripTrailingPunctuation(candidate.trim());
    if (url.isEmpty) return null;

    if (url.startsWith('www.')) {
      url = 'https://$url';
    } else if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(url)) {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final fragmentData = _parseFragment(uri.fragment);
    final segments = <String>[
      ..._segmentsFromUri(uri),
      ...fragmentData.segments,
    ];
    final query = <String, String>{
      ...uri.queryParameters,
      ...fragmentData.query,
    };

    final shareId = _extractShareId(segments, query, uri);
    if (shareId == null) return null;

    return ShareLinkParseResult(
      originalText: originalText,
      originalUrl: candidate,
      normalizedUrl: url,
      shareId: shareId,
      password: _extractPassword(query, originalText),
    );
  }

  static List<String> _segmentsFromUri(Uri uri) {
    final segments = <String>[];
    if ((uri.scheme == 'cloudreve' || uri.scheme == 'cloudreve4') &&
        uri.host.isNotEmpty) {
      segments.add(Uri.decodeComponent(uri.host));
    }
    segments.addAll(
      uri.pathSegments
          .where((e) => e.trim().isNotEmpty)
          .map((e) => Uri.decodeComponent(e.trim())),
    );
    return segments;
  }

  static _FragmentData _parseFragment(String fragment) {
    if (fragment.trim().isEmpty) return const _FragmentData([], {});

    var value = fragment.trim();
    if (value.startsWith('#')) value = value.substring(1);

    if (!value.startsWith('/') && value.contains('=')) {
      final queryUri = Uri.tryParse('https://local/?$value');
      return _FragmentData(const [], queryUri?.queryParameters ?? const {});
    }

    if (value.startsWith('/')) value = value.substring(1);
    final uri = Uri.tryParse('https://local/$value');
    if (uri == null) return const _FragmentData([], {});

    return _FragmentData(
      uri.pathSegments
          .where((e) => e.trim().isNotEmpty)
          .map((e) => Uri.decodeComponent(e.trim()))
          .toList(),
      uri.queryParameters,
    );
  }

  static String? _extractShareId(
    List<String> segments,
    Map<String, String> query,
    Uri uri,
  ) {
    for (final key in _shareIdKeys) {
      final value = query[key];
      if (value != null && _looksLikeShareId(value)) return value.trim();
    }

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i].toLowerCase();
      if (_shareSegmentNames.contains(segment) && i + 1 < segments.length) {
        final next = segments[i + 1].trim();
        if (_looksLikeShareId(next)) return next;
      }
    }

    if ((uri.scheme == 'cloudreve' || uri.scheme == 'cloudreve4') &&
        uri.host.isNotEmpty &&
        !_shareSegmentNames.contains(uri.host.toLowerCase()) &&
        _looksLikeShareId(uri.host)) {
      return uri.host;
    }

    if (segments.length >= 2) {
      final last = segments.last.trim();
      final prev = segments[segments.length - 2].toLowerCase();
      if (!_shareSegmentNames.contains(prev) && _looksLikeShareId(last)) {
        return last;
      }
    }

    return null;
  }

  static String? _extractPassword(Map<String, String> query, String text) {
    for (final key in _passwordKeys) {
      final value = query[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    final match = _passwordTextPattern.firstMatch(text);
    return match?.group(1)?.trim();
  }

  static bool _looksLikeShareId(String value) {
    final v = value.trim();
    if (v.length < 3 || v.length > 128) return false;
    if (v.contains('.') || v.contains('/') || v.contains('\\')) return false;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v);
  }

  static String _stripTrailingPunctuation(String value) {
    var result = value.trim();
    const trailing = [
      '。',
      '，',
      ',',
      '.',
      ';',
      '；',
      ')',
      '）',
      ']',
      '】',
      '}',
      '>',
      '》',
      '！',
      '!',
      '？',
      '?',
      '、',
      '：',
      ':',
    ];
    while (result.isNotEmpty && trailing.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

class _FragmentData {
  final List<String> segments;
  final Map<String, String> query;

  const _FragmentData(this.segments, this.query);
}
