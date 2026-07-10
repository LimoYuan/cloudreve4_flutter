import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/app_config.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/direct_http_client.dart';
import '../../core/utils/server_url_utils.dart';
import '../../data/models/server_model.dart';
import '../../services/qr_login_service.dart';
import '../../services/server_service.dart';

class DesktopTitleBar extends StatefulWidget implements PreferredSizeWidget {
  const DesktopTitleBar({super.key});

  @override
  State<DesktopTitleBar> createState() => _DesktopTitleBarState();

  @override
  Size get preferredSize => const Size.fromHeight(32); // Windows 标准标题栏高度
}

class _DesktopTitleBarState extends State<DesktopTitleBar> {
  static const String _cacheVersion = 'v11_once';

  String? _siteName;
  String? _siteIconUrl;
  Uint8List? _siteIconBytes;
  String? _lastBaseUrl;
  bool _loadingBrand = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSiteBrand());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.94 : 0.86,
    );

    final ServerModel? server = ServerService.instance.currentServer;
    final currentBaseUrl = server?.baseUrl;

    if (currentBaseUrl != _lastBaseUrl && !_loadingBrand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadSiteBrand());
        }
      });
    }

    final titleText = (_siteName?.trim().isNotEmpty ?? false)
        ? _siteName!.trim()
        : AppConfig.appName;

    return WindowCaption(
      brightness: theme.brightness,
      backgroundColor: Colors.transparent,
      title: DefaultTextStyle.merge(
        style: TextStyle(color: titleColor),
        child: Row(
          children: [
            _TitleBarSiteIcon(
              bytes: _siteIconBytes,
              url: _siteIconUrl,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSansSC',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSiteBrand({bool force = false}) async {
    final ServerModel? server = ServerService.instance.currentServer;
    if (server == null) {
      _lastBaseUrl = null;
      await _applyWindowTitle(AppConfig.appName);
      return;
    }

    final baseUrl = server.baseUrl.trim();
    if (baseUrl.isEmpty) {
      await _applyWindowTitle(AppConfig.appName);
      return;
    }

    if (_loadingBrand) return;
    _loadingBrand = true;
    _lastBaseUrl = baseUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cacheKey(baseUrl);
      final cachedName = prefs.getString('${cacheKey}_name');
      final cachedIconUrl = prefs.getString('${cacheKey}_icon_url');
      final cachedIconBytesText = prefs.getString('${cacheKey}_icon_bytes');
      Uint8List? cachedIconBytes;
      if (cachedIconBytesText != null && cachedIconBytesText.isNotEmpty) {
        try {
          cachedIconBytes = base64Decode(cachedIconBytesText);
        } catch (_) {}
      }

      final hasCompletedCache = !force &&
          cachedName != null &&
          cachedName.trim().isNotEmpty &&
          cachedIconBytes != null &&
          cachedIconBytes.isNotEmpty;

      if (hasCompletedCache) {
        final name = cachedName.trim();
        await _applyWindowTitle(name);
        if (mounted) {
          setState(() {
            _siteName = name;
            _siteIconUrl = cachedIconUrl;
            _siteIconBytes = cachedIconBytes;
          });
        }
        return;
      }

      final brand = await _fetchSiteBrand(baseUrl);
      final name = brand.name ?? cachedName ?? AppConfig.appName;
      final iconUrl = brand.iconUrl ?? cachedIconUrl;
      Uint8List? iconBytes = cachedIconBytes;

      if (iconUrl != null && iconUrl.trim().isNotEmpty) {
        try {
          iconBytes = await _fetchBytesDirect(iconUrl).timeout(
            const Duration(seconds: 8),
          );
        } catch (e) {
          AppLogger.d('DesktopTitleBar: 读取站点小图标失败: $e');
        }
      }

      await prefs.setString('${cacheKey}_name', name);
      if (iconUrl != null && iconUrl.trim().isNotEmpty) {
        await prefs.setString('${cacheKey}_icon_url', iconUrl);
      }
      if (iconBytes != null && iconBytes.isNotEmpty) {
        await prefs.setString('${cacheKey}_icon_bytes', base64Encode(iconBytes));
      }

      await _applyWindowTitle(name);

      if (mounted) {
        setState(() {
          _siteName = name;
          _siteIconUrl = iconUrl;
          _siteIconBytes = iconBytes;
        });
      }
    } catch (e) {
      AppLogger.d('DesktopTitleBar: 加载站点标题栏信息失败: $e');
      await _applyWindowTitle(_siteName ?? AppConfig.appName);
    } finally {
      _loadingBrand = false;
    }
  }

  String _cacheKey(String baseUrl) {
    final normalized = ServerUrlUtils.toApiBaseUrl(baseUrl)
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    // v11 缓存策略：第一次成功获取站点名称和小图标后永久沿用。
    // 不再每天刷新，避免每次启动先显示默认名称/图标再跳变。
    return 'mkw_desktop_titlebar_site_brand_${_cacheVersion}_$normalized';
  }

  Future<_SiteBrand> _fetchSiteBrand(String baseUrl) async {
    final htmlBrand = await _fetchHtmlBrand(baseUrl);
    final configs = await _getSiteConfigsDirect(baseUrl);

    String? siteName = htmlBrand.name;
    String? iconUrl = htmlBrand.iconUrl;

    for (final config in configs) {
      siteName ??= _firstString(config, const [
        'site_name',
        'siteName',
        'site_title',
        'siteTitle',
        'title',
        'name',
        'app_name',
        'appName',
        'product_name',
        'productName',
      ]);

      // 不读取 logo / logo_light，这两个是网站大 LOGO。
      // 顶部左侧要的是网页 <link rel="... icon"> 里的小图标。
      iconUrl ??= _firstString(config, const [
        'small_icon',
        'smallIcon',
        'favicon',
        'favicon_url',
        'faviconUrl',
        'site_icon',
        'siteIcon',
        'icon',
        'app_icon',
        'appIcon',
        'client_icon',
        'clientIcon',
      ]);

      if (siteName != null && iconUrl != null) break;
    }

    siteName = _cleanSiteText(siteName);
    iconUrl = _resolveSiteAssetUrl(baseUrl, iconUrl) ??
        QrLoginService.faviconUrlFromCloudreve(baseUrl);

    return _SiteBrand(name: siteName, iconUrl: iconUrl);
  }

  Future<_SiteBrand> _fetchHtmlBrand(String baseUrl) async {
    try {
      final siteBase = QrLoginService.cloudreveSiteBase(baseUrl)
          .replaceFirst(RegExp(r'/+$'), '');
      final dio = Dio();
      dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
        connectionTimeout: const Duration(seconds: 8),
      );

      final response = await dio.get<String>(
        siteBase,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;
      final html = response.data;
      if (status < 200 || status >= 300 || html == null || html.isEmpty) {
        return const _SiteBrand();
      }

      return _SiteBrand(
        name: _extractHtmlTitle(html),
        iconUrl: _extractHtmlIconUrl(html),
      );
    } catch (_) {
      return const _SiteBrand();
    }
  }

  String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    return _decodeHtmlText(match.group(1));
  }

  String? _extractHtmlIconUrl(String html) {
    final linkRegex = RegExp(r'<link\b[^>]*>', caseSensitive: false);
    final relRegex = RegExp(
      r'''\brel\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final hrefRegex = RegExp(
      r'''\bhref\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );

    for (final match in linkRegex.allMatches(html)) {
      final tag = match.group(0) ?? '';
      final rel = relRegex.firstMatch(tag)?.group(1)?.toLowerCase() ?? '';
      if (!rel.contains('icon')) continue;
      final href = hrefRegex.firstMatch(tag)?.group(1)?.trim();
      if (href != null && href.isNotEmpty) return _decodeHtmlText(href);
    }

    final cssLogo = RegExp(
      r'''background-image\s*:\s*url\(["']?([^"')]+)["']?\)''',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (cssLogo != null && cssLogo.isNotEmpty) {
      return _decodeHtmlText(cssLogo);
    }

    return null;
  }

  String? _decodeHtmlText(String? value) {
    if (value == null) return null;
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  Future<List<Map<String, dynamic>>> _getSiteConfigsDirect(String baseUrl) async {
    final apiBase = ServerUrlUtils.toApiBaseUrl(baseUrl)
        .replaceFirst(RegExp(r'/+$'), '');
    final dio = Dio();
    dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
      connectionTimeout: const Duration(seconds: 8),
    );

    final endpoints = <String>[
      '$apiBase/site/config/basic',
      '$apiBase/site/config',
      '$apiBase/site/settings',
    ];

    final results = <Map<String, dynamic>>[];
    for (final endpoint in endpoints) {
      try {
        final response = await dio.get<Map<String, dynamic>>(
          endpoint,
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) continue;

        final root = response.data;
        if (root == null) continue;
        results.add(root);

        final data = root['data'];
        if (data is Map<String, dynamic>) {
          results.add(data);
        } else if (data is Map) {
          results.add(Map<String, dynamic>.from(data));
        }
      } catch (_) {}
    }

    return results;
  }

  Future<void> _applyWindowTitle(String title) async {
    try {
      await windowManager.setTitle(title);
    } catch (_) {}
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final text = _stringValue(value);
      if (text != null) return text;
    }

    for (final entry in data.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      for (final wanted in keys) {
        if (key.toLowerCase().contains(wanted.toLowerCase())) {
          final text = _stringValue(value);
          if (text != null) return text;
        }
      }

      if (value is Map) {
        final found = _firstString(Map<String, dynamic>.from(value), keys);
        if (found != null) return found;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final found = _firstString(Map<String, dynamic>.from(item), keys);
            if (found != null) return found;
          }
        }
      }
    }

    return null;
  }

  String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null && value is! Map && value is! List) {
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _cleanSiteText(String? text) {
    if (text == null) return null;
    var value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return null;

    const suffixes = [
      ' - Cloudreve',
      '_Cloudreve',
      ' · Cloudreve',
      ' — Cloudreve',
    ];

    for (final suffix in suffixes) {
      if (value.toLowerCase().endsWith(suffix.toLowerCase())) {
        value = value.substring(0, value.length - suffix.length).trim();
        break;
      }
    }

    if (value.isEmpty) return null;
    if (value.length > 42) {
      value = '${value.substring(0, 42)}…';
    }
    return value;
  }

  String? _resolveSiteAssetUrl(String baseUrl, String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:')) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final siteBase = QrLoginService.cloudreveSiteBase(baseUrl);
    final siteUri = Uri.tryParse(siteBase);
    if (siteUri == null) return value;

    if (value.startsWith('//')) {
      return '${siteUri.scheme}:$value';
    }
    if (value.startsWith('/')) {
      return '${siteUri.scheme}://${siteUri.authority}$value';
    }
    return '${siteBase.replaceFirst(RegExp(r'/+$'), '')}/$value';
  }

  Future<Uint8List?> _fetchBytesDirect(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    final dio = Dio();
    dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
      connectionTimeout: const Duration(seconds: 8),
    );

    final response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: {'Accept': 'image/*,*/*;q=0.8'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status < 200 ||
        status >= 300 ||
        data == null ||
        data.isEmpty ||
        data.length > 1024 * 1024) {
      return null;
    }
    return Uint8List.fromList(data);
  }
}

class _TitleBarSiteIcon extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;

  const _TitleBarSiteIcon({
    required this.bytes,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/icons/tray_icon.png',
      width: 20,
      height: 20,
      fit: BoxFit.contain,
    );

    Widget image = fallback;
    final data = bytes;
    if (data != null && data.isNotEmpty) {
      image = Image.memory(
        data,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (url != null && url!.trim().isNotEmpty) {
      image = Image.network(
        url!,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    // 保持原始网站小图标样式：不额外加背景、不加边框、不加圆角框。
    // 明暗主题只由标题栏文字颜色和 WindowCaption brightness 适配，避免破坏站点 favicon 原貌。
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(child: image),
    );
  }
}

class _SiteBrand {
  final String? name;
  final String? iconUrl;

  const _SiteBrand({
    this.name,
    this.iconUrl,
  });
}
