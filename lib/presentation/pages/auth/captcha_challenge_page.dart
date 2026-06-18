import 'dart:convert';
import 'dart:io';

import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:cloudreve4_flutter/core/utils/win_env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile;

// ═════════════════════════════════════════════════════
//  WebView 代理配置（仅 Windows，无认证）
// ═════════════════════════════════════════════════════

class CaptchaProxyConfig {
  final String host;
  final int port;

  const CaptchaProxyConfig({required this.host, required this.port});

  String get proxyArg => '--proxy-server=http://$host:$port';

  @override
  String toString() => '$host:$port';
}

// ═════════════════════════════════════════════════════
//  WebView2 代理环境变量管理
// ═════════════════════════════════════════════════════

const _envVarName = 'WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS';

/// 为 WebView2 设置代理环境变量（进程级，不影响其他程序）
void _applyWebView2Proxy(CaptchaProxyConfig? proxy) {
  if (!Platform.isWindows) return;

  if (proxy != null) {
    // 进程级环境变量，已有值则追加（保留用户可能通过启动参数设置的值）
    final existing = Platform.environment[_envVarName];
    final newValue = existing != null && existing.isNotEmpty
        ? '$existing ${proxy.proxyArg}'
        : proxy.proxyArg;
    winSetEnvVar(_envVarName, newValue);
    AppLogger.i('WebView2 代理环境变量已设置: $newValue');
  }
}

/// 清除 WebView2 代理环境变量
void _clearWebView2Proxy() {
  if (!Platform.isWindows) return;
  winSetEnvVar(_envVarName, null);
  AppLogger.i('WebView2 代理环境变量已清除');
}

// ═════════════════════════════════════════════════════
//  CaptchaWebConfig
// ═════════════════════════════════════════════════════

class CaptchaWebConfig {
  final String type;
  final String displayName;
  final String? siteKey;
  final String? instanceUrl;
  final String? assetServer;

  const CaptchaWebConfig._({
    required this.type,
    required this.displayName,
    this.siteKey,
    this.instanceUrl,
    this.assetServer,
  });

  const CaptchaWebConfig.recaptchaV2({
    required String siteKey,
    String displayName = 'reCAPTCHA V2',
  }) : this._(
          type: 'recaptcha',
          displayName: displayName,
          siteKey: siteKey,
        );

  const CaptchaWebConfig.turnstile({
    required String siteKey,
    String displayName = 'Cloudflare Turnstile',
  }) : this._(
          type: 'turnstile',
          displayName: displayName,
          siteKey: siteKey,
        );

  const CaptchaWebConfig.cap({
    required String instanceUrl,
    required String siteKey,
    String? assetServer,
    String displayName = 'Cap',
  }) : this._(
          type: 'cap',
          displayName: displayName,
          instanceUrl: instanceUrl,
          siteKey: siteKey,
          assetServer: assetServer,
        );
}

// ─── 桌面端判断 ───────────────────────────────────────
bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux);

// ─── 桌面 User-Agent ──────────────────────────────────
const _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

const _androidUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/148.0.0.0 Mobile Safari/537.36';

// ═════════════════════════════════════════════════════
//  CaptchaChallengePage
// ═════════════════════════════════════════════════════

class CaptchaChallengePage extends StatefulWidget {
  final CaptchaWebConfig config;
  final String baseUrl;
  final CaptchaProxyConfig? proxyConfig;

  const CaptchaChallengePage({
    super.key,
    required this.config,
    required this.baseUrl,
    this.proxyConfig,
  });

  @override
  State<CaptchaChallengePage> createState() => _CaptchaChallengePageState();
}

class _CaptchaChallengePageState extends State<CaptchaChallengePage> {
  // ── 移动端 ──
  mobile.WebViewController? _mobileController;

  // ── 桌面端 ──
  InAppWebViewController? _desktopController;
  Key _desktopKey = UniqueKey();

  // ── 共享状态 ──
  bool _isLoading = true;
  int _progress = 0;
  String? _errorMessage;
  String? _statusText;
  bool _disposed = false;

  // ── 是否设置了代理环境变量（用于清理时判断）──
  bool _proxyEnvSet = false;

  // ── HTML ──
  late String _currentHtml;

  @override
  void initState() {
    super.initState();
    _currentHtml = _buildHtml(widget.config);

    // Windows: 在 WebView2 创建前设置代理环境变量
    if (_isDesktop && widget.proxyConfig != null && Platform.isWindows) {
      _applyWebView2Proxy(widget.proxyConfig);
      _proxyEnvSet = true;
    }

    if (!_isDesktop) {
      _mobileController = mobile.WebViewController()
        ..setJavaScriptMode(mobile.JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setUserAgent(_androidUserAgent)
        ..addJavaScriptChannel(
          'CaptchaBridge',
          onMessageReceived: (message) {
            _handleBridgeMessage(message.message);
          },
        )
        ..setNavigationDelegate(
          mobile.NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              AppLogger.w(
                'Mobile captcha WebView resource error: '
                'code=${error.errorCode}, mainFrame=${error.isForMainFrame}, '
                'description=${error.description}',
              );

              if (_isIgnorableMobileWebViewError(error)) {
                _keepTurnstileChallengeVisible(
                  message: '${error.errorCode}: ${error.description}',
                );
                return;
              }

              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      '${error.errorCode}: ${error.description}'.trim();
                });
              }
            },
          ),
        )
        ..loadHtmlString(_currentHtml, baseUrl: widget.baseUrl);
    }
  }

  // ─── 加载 / 刷新 ────────────────────────────────────

  Future<void> _loadCaptcha() async {
    if (_disposed) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = null;
      _progress = 0;
      _currentHtml = _buildHtml(widget.config);
    });

    if (!_isDesktop && _mobileController != null) {
      await _mobileController!.loadHtmlString(
        _currentHtml,
        baseUrl: widget.baseUrl,
      );
    } else if (_isDesktop) {
      setState(() => _desktopKey = UniqueKey());
    }
  }

  bool _isIgnorableMobileWebViewError(mobile.WebResourceError error) {
    final description = error.description.toLowerCase();

    // Android WebView may report Cloudflare Turnstile iframe / challenge
    // resources as -1/net::ERR_FAILED while the visible challenge is still
    // usable. Treat these as non-fatal so the login page does not show a
    // misleading bottom error banner.
    if (error.errorCode == -1) return true;
    if (error.isForMainFrame == false) return true;
    if (widget.config.type == 'turnstile' &&
        (description.contains('net::err_failed') ||
            description.contains('err_failed') ||
            description.contains('frame') ||
            description.contains('iframe'))) {
      return true;
    }

    return false;
  }

  bool _isIgnorableCaptchaScriptError(String message) {
    final normalized = message.toLowerCase();
    return widget.config.type == 'turnstile' &&
        (normalized.contains('net::err_failed') ||
            normalized.contains('err_failed') ||
            normalized.contains('-1') ||
            normalized.contains('iframe') ||
            normalized.contains('frame') ||
            normalized.contains('timeout') ||
            normalized.contains('network') ||
            normalized.contains('turnstile'));
  }

  void _keepTurnstileChallengeVisible({String? message}) {
    AppLogger.w('Turnstile 非致命状态，保留验证码继续等待: ${message ?? ''}');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _statusText = '请继续完成人机验证；如果长时间没有返回，请点右上角刷新。';
    });
  }

  // ─── Bridge 消息处理 ─────────────────────────────────

  void _handleBridgeMessage(String rawMessage) {
    AppLogger.d('Bridge 收到消息: ${rawMessage.length > 100 ? "${rawMessage.substring(0, 100)}..." : rawMessage}');
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();

      if (type == 'success') {
        final token = decoded['token']?.toString() ?? '';
        final jsTs = decoded['_jsTs'];
        if (jsTs is num) {
          final delayMs = DateTime.now().millisecondsSinceEpoch - jsTs.toInt();
          AppLogger.d('Bridge 收到 success, JS→Dart 传输延迟=${delayMs}ms, token长度=${token.length}');
        } else {
          AppLogger.d('Bridge 收到 success, token长度=${token.length}');
        }
        if (token.isNotEmpty && mounted && !_disposed) {
          _disposed = true;
          AppLogger.d('准备 pop 返回登录页');
          Navigator.of(context).pop(token);
          AppLogger.d('pop 完成');
        }
        return;
      }

      if (type == 'progress') {
        final progress = decoded['progress']?.toString();
        if (mounted) {
          setState(() {
            _statusText =
                progress == null ? '正在验证...' : '正在验证... $progress';
          });
        }
        return;
      }

      if (type == 'error') {
        final message = decoded['message']?.toString() ?? '验证码加载失败';
        // Cloudflare Turnstile 在 Android WebView 中可能把一次 iframe/网络
        // 抖动通过 error-callback 抛出来，但页面上的验证码仍可继续完成。
        // 这里不能关闭或跳过验证码，只是不把它显示成底部红色致命错误。
        if (_isIgnorableCaptchaScriptError(message)) {
          _keepTurnstileChallengeVisible(message: message);
          return;
        }

        if (mounted) {
          setState(() {
            _errorMessage = message;
          });
        }
        return;
      }

      if (type == 'debug') {
        AppLogger.d('JS debug: ${decoded['message']}');
        return;
      }

      if (type == 'expired') {
        if (mounted) {
          setState(() {
            _statusText = '验证码已过期，请重新验证';
          });
        }
        return;
      }
    } catch (_) {}
  }

  // ─── WebView 销毁 ───────────────────────────────────

  void _cleanupWebView() {
    if (_isDesktop) {
      final ctrl = _desktopController;
      _desktopController = null;
      AppLogger.d('开始清理 WebView controller');
      ctrl?.dispose();
      AppLogger.d('WebView controller 已 dispose');
      if (_proxyEnvSet) {
        _clearWebView2Proxy();
        _proxyEnvSet = false;
      }
    }
  }

  @override
  void dispose() {
    AppLogger.d('CaptchaChallengePage dispose 开始');
    _disposed = true;
    _cleanupWebView();
    super.dispose();
    AppLogger.d('CaptchaChallengePage dispose 完成');
  }

  // ═════════════════════════════════════════════════════
  //  HTML 生成
  // ═════════════════════════════════════════════════════

  String _buildHtml(CaptchaWebConfig config) {
    switch (config.type) {
      case 'turnstile':
        return _baseHtml(
          title: 'Cloudflare Turnstile',
          body: '<div id="widget"></div>',
          script: '''
            function onTurnstileLoad() {
              try {
                turnstile.render('#widget', {
                  sitekey: '${_js(config.siteKey!)}',
                  callback: function(token) { solved(token); },
                  // 不移除验证码。Android WebView 有时会把 Turnstile 的临时
                  // iframe/network 状态作为 error-callback 抛出，这时仍保留
                  // 原验证码，让用户继续等待或手动刷新。
                  'error-callback': function(errorCode) {
                    var message = errorCode ? String(errorCode) : 'Turnstile challenge error';
                    markStatus('请继续完成人机验证，如长时间无响应请点右上角刷新。', false);
                    sendBridge({ type: 'error', message: message });
                  },
                  'expired-callback': function() { expired(); },
                  'after-interactive-callback': function() {
                    sendBridge({ type: 'debug', message: 'after-interactive fired' });
                    markStatus('正在与 Cloudflare 服务器验证，请稍候...', false);
                    sendBridge({ type: 'progress', progress: '服务器验证中' });
                  },
                  retry: 'auto',
                  'retry-interval': 3000,
                  'refresh-expired': 'auto',
                  'refresh-timeout': 'auto'
                });
                markStatus('请完成人机验证', false);
              } catch (e) {
                failed(e && e.message ? e.message : String(e));
              }
            }
          </script>
          <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit" async defer></script>
          <script>
          ''',
        );
      case 'recaptcha':
        return _baseHtml(
          title: 'reCAPTCHA V2',
          body: '<div id="widget"></div>',
          script: '''
            function onRecaptchaLoad() {
              try {
                grecaptcha.render('widget', {
                  sitekey: '${_js(config.siteKey!)}',
                  callback: function(token) { solved(token); },
                  'expired-callback': function() { expired(); },
                  'error-callback': function() { failed('reCAPTCHA 加载或验证失败，请重试'); }
                });
                markStatus('请完成人机验证', false);
              } catch (e) {
                failed(e && e.message ? e.message : String(e));
              }
            }
          </script>
          <script src="https://www.google.com/recaptcha/api.js?onload=onRecaptchaLoad&render=explicit" async defer></script>
          <script>
          ''',
        );
      case 'cap':
        final endpoint = _capEndpoint(config.instanceUrl!, config.siteKey!);
        final scriptUrl = _capWidgetScript(config.assetServer);
        final safeEndpoint = const HtmlEscape().convert(endpoint);
        final safeScriptUrl = const HtmlEscape().convert(scriptUrl);

        return _baseHtml(
          title: 'Cap',
          body:
              '<div id="widget"><cap-widget id="cap" required data-cap-api-endpoint="$safeEndpoint" data-cap-disable-haptics></cap-widget></div>',
          script: '''
            window.CAP_DISABLE_HAPTICS = true;
            const cap = document.getElementById('cap');
            if (cap) {
              cap.addEventListener('solve', function(e) {
                solved(e.detail && e.detail.token ? e.detail.token : '');
              });
              cap.addEventListener('progress', function(e) {
                const progress = e.detail && e.detail.progress != null ? e.detail.progress : '';
                markStatus('正在验证... ' + progress, false);
                sendBridge({ type: 'progress', progress: progress });
              });
              cap.addEventListener('error', function(e) {
                const message = e.detail && e.detail.message ? e.detail.message : 'Cap 验证失败';
                failed(message);
              });
              markStatus('请完成人机验证', false);
            }
          </script>
          <script type="module" src="$safeScriptUrl"></script>
          <script>
          ''',
        );
      default:
        return _baseHtml(
          title: '验证码错误',
          body:
              '<div id="widget" class="error">${const HtmlEscape().convert('不支持的验证码类型: ${config.type}')}</div>',
          script: "failed('不支持的验证码类型');",
        );
    }
  }

  String _baseHtml({
    required String title,
    required String body,
    required String script,
  }) {
    final safeTitle = const HtmlEscape().convert(title);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>$safeTitle</title>
  <style>
    html, body {
      margin: 0;
      padding: 0;
      min-height: 100%;
      background: #ffffff;
      color: #0f172a;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans SC", sans-serif;
    }
    .page {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      box-sizing: border-box;
    }
    .card {
      width: 100%;
      max-width: 380px;
      border: 1px solid #e5e7eb;
      border-radius: 18px;
      box-shadow: 0 12px 32px rgba(15, 23, 42, 0.12);
      padding: 24px;
      box-sizing: border-box;
    }
    h1 {
      font-size: 18px;
      margin: 0 0 8px;
      text-align: center;
      color: #111827;
    }
    p {
      font-size: 13px;
      color: #64748b;
      text-align: center;
      margin: 0 0 20px;
      line-height: 1.5;
    }
    #widget {
      display: flex;
      justify-content: center;
      min-height: 78px;
      align-items: center;
    }
    .status {
      margin-top: 14px;
      font-size: 12px;
      text-align: center;
      color: #64748b;
      word-break: break-word;
    }
    .error {
      color: #dc2626;
    }
    cap-widget {
      display: block;
      margin: 0 auto;
    }
  </style>
</head>
<body>
  <div class="page">
    <div class="card">
      <h1>$safeTitle</h1>
      <p>完成验证后会自动返回登录页。</p>
      $body
      <div id="status" class="status">正在加载验证码...</div>
    </div>
  </div>
  <script>
    function sendBridge(payload) {
      payload._jsTs = Date.now();
      var json = JSON.stringify(payload);
      try {
        if (typeof CaptchaBridge !== 'undefined' && CaptchaBridge.postMessage) {
          CaptchaBridge.postMessage(json);
        } else if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('CaptchaBridge', json);
        }
      } catch (e) {}
    }
    function markStatus(text, isError) {
      var el = document.getElementById('status');
      if (!el) return;
      el.textContent = text || '';
      el.className = isError ? 'status error' : 'status';
    }
    function solved(token) {
      markStatus('验证完成，正在返回...', false);
      sendBridge({ type: 'success', token: token });
    }
    function failed(message) {
      markStatus(message || '验证码加载失败', true);
      sendBridge({ type: 'error', message: message || '验证码加载失败' });
    }
    function expired() {
      markStatus('验证码已过期，请重新验证', true);
      sendBridge({ type: 'expired' });
    }
    $script
  </script>
</body>
</html>
''';
  }

  // ═════════════════════════════════════════════════════
  //  Widget 构建
  // ═════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final title = widget.config.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新验证码',
            onPressed: _loadCaptcha,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress > 0 && _progress < 100
              ? LinearProgressIndicator(value: _progress / 100)
              : const SizedBox(height: 3),
        ),
      ),
      body: Stack(
        children: [
          _isDesktop ? _buildDesktopWebView() : _buildMobileWebView(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            _buildOverlayBanner(
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              color: Theme.of(context).colorScheme.errorContainer,
            )
          else if (_statusText != null)
            _buildOverlayBanner(
              child: Text(
                _statusText!,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ── 移动端 WebView ──────────────────────────────────

  Widget _buildMobileWebView() {
    return mobile.WebViewWidget(controller: _mobileController!);
  }

  // ── 桌面端 WebView ──────────────────────────────────

  Widget _buildDesktopWebView() {
    AppLogger.i('WebView 验证码 BaseUrl: ${WebUri(widget.baseUrl)}');

    return InAppWebView(
      key: _desktopKey,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        safeBrowsingEnabled: true,
        isInspectable: true,
        cacheMode: CacheMode.LOAD_NO_CACHE,
        supportMultipleWindows: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccessFromFileURLs: true,
        userAgent: _desktopUserAgent,
        transparentBackground: true,
        supportZoom: false,
        useHybridComposition: true,
      ),
      onWebViewCreated: (controller) {
        _desktopController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'CaptchaBridge',
          callback: (args) {
            if (args.isNotEmpty) {
              _handleBridgeMessage(args[0].toString());
            }
          },
        );

        controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri("${widget.baseUrl}/virtual_captcha.html"),
          ),
        );
      },
      shouldInterceptRequest: (controller, request) async {
        if (request.url.toString().contains('virtual_captcha.html')) {
          AppLogger.i('黑魔法 -> 拦截成功，正在注入动态 HTML');
          return WebResourceResponse(
            contentType: 'text/html',
            contentEncoding: 'utf-8',
            data: Uint8List.fromList(utf8.encode(_currentHtml)),
            statusCode: 200,
            reasonPhrase: 'OK',
          );
        }

        if (request.url.toString().contains('/h/b/rc') && request.method == 'POST') {
          AppLogger.w('发现黑魔法后遗症校验请求 (POST)，执行强制 404');
          await Future.delayed(Duration(seconds: 2));
          return WebResourceResponse(
            contentType: 'text/plain',
            statusCode: 404,
            reasonPhrase: 'Not Found',
            data: Uint8List(0),
          );
        }
        return null;
      },
      onLoadStart: (controller, url) {},
      onLoadStop: (controller, url) {
        if (mounted) setState(() => _isLoading = false);
      },
      onProgressChanged: (controller, progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onReceivedError: (controller, request, error) {
        final description = error.description.toLowerCase();
        final shouldIgnore = request.isForMainFrame == false ||
            (widget.config.type == 'turnstile' &&
                (description.contains('net::err_failed') ||
                    description.contains('err_failed') ||
                    description.contains('iframe') ||
                    description.contains('frame')));

        if (shouldIgnore) {
          AppLogger.w(
            '忽略桌面验证码 WebView 非致命错误: '
            '${error.type}: ${error.description}',
          );
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '${error.type}: ${error.description}'.trim();
          });
        }
      },
    );
  }

  // ── 通用底部提示条 ──────────────────────────────────

  Widget _buildOverlayBanner({required Widget child, Color? color}) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color ??
                Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  //  辅助
  // ═════════════════════════════════════════════════════

  String _capEndpoint(String instanceUrl, String siteKey) {
    final trimmedInstance = instanceUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final trimmedSiteKey = siteKey.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return '$trimmedInstance/$trimmedSiteKey/';
  }

  String _capWidgetScript(String? assetServer) {
    final asset = assetServer?.trim();
    if (asset != null && asset.isNotEmpty) {
      if (asset.startsWith('http://') || asset.startsWith('https://')) {
        return asset;
      }
      if (asset.toLowerCase() == 'jsdelivr') {
        return 'https://cdn.jsdelivr.net/npm/cap-widget';
      }
      if (asset.toLowerCase() == 'unpkg') {
        return 'https://unpkg.com/cap-widget';
      }
    }
    return 'https://cdn.jsdelivr.net/npm/cap-widget';
  }

  String _js(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }
}
