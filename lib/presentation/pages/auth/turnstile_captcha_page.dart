import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TurnstileCaptchaPage extends StatefulWidget {
  final String siteKey;
  final String baseUrl;

  const TurnstileCaptchaPage({
    super.key,
    required this.siteKey,
    required this.baseUrl,
  });

  @override
  State<TurnstileCaptchaPage> createState() => _TurnstileCaptchaPageState();
}

class _TurnstileCaptchaPageState extends State<TurnstileCaptchaPage> {
  late final WebViewController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    final origin = _toOrigin(widget.baseUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoaded = true);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('验证码加载失败: ${error.description}')),
            );
          },
        ),
      )
      ..loadHtmlString(
        _buildHtml(widget.siteKey),
        baseUrl: origin,
      );
  }

  String _toOrigin(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return 'https://localhost/';
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/';
  }

  String _buildHtml(String siteKey) {
    final encodedSiteKey = jsonEncode(siteKey);
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer></script>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; min-height: 100%; background: transparent; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    .wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; box-sizing: border-box; }
    .card { width: 100%; max-width: 360px; padding: 24px; border-radius: 16px; background: #ffffff; box-shadow: 0 8px 30px rgba(0,0,0,.12); text-align: center; }
    .title { font-size: 18px; font-weight: 600; margin-bottom: 8px; color: #111827; }
    .desc { font-size: 14px; color: #6b7280; margin-bottom: 20px; line-height: 1.5; }
    #turnstile-container { display: flex; justify-content: center; min-height: 70px; }
    .hint { margin-top: 16px; font-size: 12px; color: #9ca3af; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="title">人机验证</div>
      <div class="desc">请完成 Cloudflare Turnstile 验证后返回登录。</div>
      <div id="turnstile-container"></div>
      <div class="hint">验证完成后会自动返回 App。</div>
    </div>
  </div>

  <script>
    function send(payload) { TurnstileChannel.postMessage(JSON.stringify(payload)); }
    function renderTurnstile() {
      if (!window.turnstile) { setTimeout(renderTurnstile, 200); return; }
      try {
        window.turnstile.render('#turnstile-container', {
          sitekey: $encodedSiteKey,
          callback: function(token) { send({ type: 'success', token: token }); },
          'expired-callback': function() { send({ type: 'expired', message: '验证已过期，请重新验证' }); },
          'error-callback': function() { send({ type: 'error', message: '验证失败，请重试' }); },
          'timeout-callback': function() { send({ type: 'timeout', message: '验证超时，请重试' }); }
        });
      } catch (e) {
        send({ type: 'error', message: String(e) });
      }
    }
    window.addEventListener('load', renderTurnstile);
  </script>
</body>
</html>
''';
  }

  void _handleMessage(String rawMessage) {
    try {
      final payload = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = payload['type'] as String?;
      final token = payload['token'] as String?;
      final message = payload['message'] as String?;

      if (type == 'success' && token != null && token.isNotEmpty) {
        Navigator.of(context).pop(token);
        return;
      }

      if (message != null && message.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码返回数据异常')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人机验证')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_isLoaded) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
