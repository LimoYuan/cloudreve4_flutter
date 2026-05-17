import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class CaptchaChallengePage extends StatefulWidget {
  final CaptchaWebConfig config;
  final String baseUrl;

  const CaptchaChallengePage({
    super.key,
    required this.config,
    required this.baseUrl,
  });

  @override
  State<CaptchaChallengePage> createState() => _CaptchaChallengePageState();
}

class _CaptchaChallengePageState extends State<CaptchaChallengePage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;
  String? _errorMessage;
  String? _statusText;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'CaptchaBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    '${error.errorCode}: ${error.description}'.trim();
              });
            }
          },
        ),
      );

    _loadCaptcha();
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = null;
      _progress = 0;
    });

    final html = _buildHtml(widget.config);
    await _controller.loadHtmlString(
      html,
      baseUrl: widget.baseUrl,
    );
  }

  void _handleBridgeMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return;

      final type = decoded['type']?.toString();

      if (type == 'success') {
        final token = decoded['token']?.toString() ?? '';
        if (token.isNotEmpty && mounted) {
          Navigator.of(context).pop(token);
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
        if (mounted) {
          setState(() {
            _errorMessage = decoded['message']?.toString() ?? '验证码加载失败';
          });
        }
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
    } catch (_) {
      // 忽略非 JSON 消息。
    }
  }

  String _buildHtml(CaptchaWebConfig config) {
    switch (config.type) {
      case 'turnstile':
        return _buildTurnstileHtml(config.siteKey!);
      case 'recaptcha':
        return _buildRecaptchaHtml(config.siteKey!);
      case 'cap':
        return _buildCapHtml(
          instanceUrl: config.instanceUrl!,
          siteKey: config.siteKey!,
          assetServer: config.assetServer,
        );
      default:
        return _buildErrorHtml('不支持的验证码类型: ${config.type}');
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
      try {
        CaptchaBridge.postMessage(JSON.stringify(payload));
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

  String _buildTurnstileHtml(String siteKey) {
    return _baseHtml(
      title: 'Cloudflare Turnstile',
      body: '<div id="widget"></div>',
      script: '''
        function onTurnstileLoad() {
          try {
            turnstile.render('#widget', {
              sitekey: '${_js(siteKey)}',
              callback: function(token) { solved(token); },
              'error-callback': function() { failed('Turnstile 验证失败，请重试'); },
              'expired-callback': function() { expired(); }
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
  }

  String _buildRecaptchaHtml(String siteKey) {
    return _baseHtml(
      title: 'reCAPTCHA V2',
      body: '<div id="widget"></div>',
      script: '''
        function onRecaptchaLoad() {
          try {
            grecaptcha.render('widget', {
              sitekey: '${_js(siteKey)}',
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
  }

  String _buildCapHtml({
    required String instanceUrl,
    required String siteKey,
    String? assetServer,
  }) {
    final endpoint = _capEndpoint(instanceUrl, siteKey);
    final scriptUrl = _capWidgetScript(assetServer);
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
  }

  String _buildErrorHtml(String message) {
    return _baseHtml(
      title: '验证码错误',
      body: '<div id="widget" class="error">${const HtmlEscape().convert(message)}</div>',
      script: 'failed(${jsonEncode(message)});',
    );
  }

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
        .replaceAll(r'\\', r'\\\\')
        .replaceAll("'", r"\\'")
        .replaceAll('\\n', r'\\n')
        .replaceAll('\\r', r'\\r');
  }

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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            )
          else if (_statusText != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText!,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
