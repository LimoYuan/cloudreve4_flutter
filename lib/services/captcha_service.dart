import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../presentation/pages/auth/captcha_challenge_page.dart';
import '../presentation/pages/auth/mobile_captcha_challenge_page.dart';
import '../presentation/widgets/toast_helper.dart';
import '../services/auth_service.dart';
import '../services/server_service.dart';
import 'api_service.dart';
import 'mobile_captcha_service.dart';

/// 验证码服务（单例）
///
/// 管理验证码的加载、状态和 UI 构建，供登录/注册/忘记密码页面共享。
class CaptchaService {
  CaptchaService._internal();
  static final CaptchaService _instance = CaptchaService._internal();
  static CaptchaService get instance => _instance;

  final TextEditingController captchaController = TextEditingController();

  String? _captchaType;
  String? _recaptchaSiteKey;
  String? _turnstileSiteKey;
  String? _capInstanceUrl;
  String? _capSiteKey;
  String? _capAssetServer;

  String? _captchaImage;
  String? _captchaTicket;
  String? _captchaToken;
  bool _isLoadingCaptcha = false;

  // 代理配置（仅 Windows 桌面端）
  CaptchaProxyConfig? _proxyConfig;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isLoadingCaptcha => _isLoadingCaptcha;
  String? get captchaImage => _captchaImage;
  String? get captchaTicket => _captchaTicket;
  String? get captchaToken => _captchaToken;

  bool get isWebCaptcha => captchaWebConfig != null;

  CaptchaWebConfig? get captchaWebConfig {
    final type = _normalizedCaptchaType;
    if (type == 'turnstile' &&
        _turnstileSiteKey != null &&
        _turnstileSiteKey!.isNotEmpty) {
      return CaptchaWebConfig.turnstile(
        siteKey: _turnstileSiteKey!,
        displayName: 'Cloudflare Turnstile',
      );
    }

    if (type == 'recaptcha' &&
        _recaptchaSiteKey != null &&
        _recaptchaSiteKey!.isNotEmpty) {
      return CaptchaWebConfig.recaptchaV2(
        siteKey: _recaptchaSiteKey!,
        displayName: 'reCAPTCHA V2',
      );
    }

    if (type == 'cap' &&
        _capInstanceUrl != null &&
        _capInstanceUrl!.isNotEmpty &&
        _capSiteKey != null &&
        _capSiteKey!.isNotEmpty) {
      return CaptchaWebConfig.cap(
        instanceUrl: _capInstanceUrl!,
        siteKey: _capSiteKey!,
        assetServer: _capAssetServer,
        displayName: 'Cap',
      );
    }

    return null;
  }

  String get _normalizedCaptchaType {
    final raw = (_captchaType ?? '').trim().toLowerCase();
    if (raw == 'recaptcha_v2' ||
        raw == 'recaptchav2' ||
        raw == 'google' ||
        raw == 'google_recaptcha' ||
        raw == 'google-recaptcha') {
      return 'recaptcha';
    }
    if (raw == 'cloudflare_turnstile' || raw == 'cloudflare-turnstile') {
      return 'turnstile';
    }
    if (raw == 'image' || raw == 'graphic' || raw == 'captcha') {
      return 'normal';
    }
    return raw;
  }

  /// 加载验证码配置和图片。
  ///
  /// 平台边界：
  /// - Android / iOS 只走旧安卓验证码解析逻辑。
  /// - Windows / Linux / macOS 保留桌面验证码和代理逻辑。
  Future<void> loadCaptcha(String baseUrl) async {
    if (_isLoadingCaptcha) return;

    _isLoadingCaptcha = true;

    try {
      await ApiService.instance.setBaseUrl(baseUrl);

      if (_isMobile) {
        await _loadMobileCaptcha();
      } else {
        await _loadDesktopCaptcha();
      }
    } catch (_) {
      if (_isMobile) {
        _setMobileCaptchaFallback();
      } else {
        clearCaptcha();
      }
    } finally {
      _isLoadingCaptcha = false;
    }
  }

  /// 旧安卓验证码配置加载逻辑。
  Future<void> _loadMobileCaptcha() async {
    final captchaInfo = await MobileCaptchaService.instance.load(
      enabledKeys: const ['login_captcha', 'loginCaptcha'],
      defaultEnabled: true,
    );

    if (!captchaInfo.enabled) {
      clearCaptcha();
      return;
    }

    _captchaType = captchaInfo.type;
    _recaptchaSiteKey = captchaInfo.recaptchaSiteKey;
    _turnstileSiteKey = captchaInfo.turnstileSiteKey;
    _capInstanceUrl = captchaInfo.capInstanceUrl;
    _capSiteKey = captchaInfo.capSiteKey;
    _capAssetServer = captchaInfo.capAssetServer;
    _captchaToken = null;
    _captchaImage = captchaInfo.image;
    _captchaTicket = captchaInfo.ticket;
    captchaController.clear();
  }

  /// 旧安卓加载失败时的回退行为：保持验证码入口可刷新，不绕过登录验证码。
  void _setMobileCaptchaFallback() {
    _captchaType = 'normal';
    _recaptchaSiteKey = null;
    _turnstileSiteKey = null;
    _capInstanceUrl = null;
    _capSiteKey = null;
    _capAssetServer = null;
    _captchaToken = null;
    _captchaImage = null;
    _captchaTicket = null;
    captchaController.clear();
  }

  /// 桌面端验证码配置加载逻辑。
  Future<void> _loadDesktopCaptcha() async {
    Map<String, dynamic> config = <String, dynamic>{};

    try {
      config = await AuthService.instance.getBasicSiteConfig().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {}

    final captchaType = _normalizeCaptchaType(
      (config['captcha_type'] ?? config['captchaType'] ?? config['captcha'])
          ?.toString(),
    );

    final recaptchaKey = _firstNonEmptyString(config, const [
      'captcha_ReCaptchaKey',
      'captcha_re_captcha_key',
      'captchaReCaptchaKey',
      'recaptcha_site_key',
      'recaptchaSiteKey',
      'recaptcha_key',
      'reCaptchaKey',
    ]);

    final turnstileSiteKey = _firstNonEmptyString(config, const [
      'turnstile_site_id',
      'turnstileSiteId',
      'turnstile_site_key',
      'turnstileSiteKey',
    ]);

    final capInstanceUrl = _firstNonEmptyString(config, const [
      'captcha_cap_instance_url',
      'captchaCapInstanceUrl',
      'cap_instance_url',
      'capInstanceUrl',
    ]);

    final capSiteKey = _firstNonEmptyString(config, const [
      'captcha_cap_site_key',
      'captchaCapSiteKey',
      'cap_site_key',
      'capSiteKey',
    ]);

    final capAssetServer = _firstNonEmptyString(config, const [
      'captcha_cap_asset_server',
      'captchaCapAssetServer',
      'cap_asset_server',
      'capAssetServer',
    ]);

    final isExternalCaptcha =
        captchaType == 'turnstile' ||
        captchaType == 'recaptcha' ||
        captchaType == 'cap';

    if (isExternalCaptcha) {
      _captchaType = captchaType;
      _recaptchaSiteKey = recaptchaKey;
      _turnstileSiteKey = turnstileSiteKey;
      _capInstanceUrl = capInstanceUrl;
      _capSiteKey = capSiteKey;
      _capAssetServer = capAssetServer;
      _captchaToken = null;

      _captchaImage = null;
      _captchaTicket = null;
      captchaController.clear();
      return;
    }

    final captcha = await AuthService.instance.getCaptcha();

    _captchaType = captchaType.isEmpty ? 'normal' : captchaType;
    _recaptchaSiteKey = null;
    _turnstileSiteKey = null;
    _capInstanceUrl = null;
    _capSiteKey = null;
    _capAssetServer = null;
    _captchaToken = null;

    _captchaImage = captcha['image'];
    _captchaTicket = captcha['ticket'];
    captchaController.clear();
  }

  /// 重新加载图形验证码图片
  Future<void> refreshCaptcha() async {
    final server = ServerService.instance.currentServer;
    if (server == null) return;
    await loadCaptcha(server.baseUrl);
  }

  /// 跳转到 Web 验证码页面
  Future<void> openCaptchaChallenge(
    BuildContext context, {
    VoidCallback? onVerified,
  }) async {
    final server = ServerService.instance.currentServer;
    final config = captchaWebConfig;

    if (server == null || config == null) {
      ToastHelper.failure('验证码配置无效');
      return;
    }

    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) {
          if (_isMobile) {
            return MobileCaptchaChallengePage(
              config: config,
              baseUrl: server.baseUrl,
            );
          }

          return CaptchaChallengePage(
            config: config,
            baseUrl: server.baseUrl,
            proxyConfig: _isDesktop ? _proxyConfig : null,
          );
        },
      ),
    );

    if (token != null && token.isNotEmpty) {
      _captchaToken = token;
      ToastHelper.success('人机验证完成');
      onVerified?.call();
    }
  }

  /// 清空所有验证码状态
  void clearCaptcha() {
    _captchaType = null;
    _recaptchaSiteKey = null;
    _turnstileSiteKey = null;
    _capInstanceUrl = null;
    _capSiteKey = null;
    _capAssetServer = null;
    _captchaToken = null;
    _captchaImage = null;
    _captchaTicket = null;
    captchaController.clear();
  }

  /// 获取验证码参数（用于提交登录/注册/忘记密码请求）
  ///
  /// 返回 `{captcha: ..., ticket: ...}` 或空 Map（无需验证码时）。
  Map<String, String> getCaptchaParams() {
    if (isWebCaptcha) {
      if (_captchaToken == null || _captchaToken!.isEmpty) return {};
      return {'captcha': _captchaToken!, 'ticket': _captchaToken!};
    }

    final userInput = captchaController.text.trim();
    if (userInput.isEmpty &&
        (_captchaTicket == null || _captchaTicket!.isEmpty)) {
      return {};
    }

    return {'captcha': userInput, 'ticket': _captchaTicket ?? ''};
  }

  /// Web 验证码是否已通过
  bool get isWebCaptchaVerified =>
      !isWebCaptcha || (_captchaToken != null && _captchaToken!.isNotEmpty);

  /// 构建验证码输入 Widget
  Widget buildCaptchaInput(BuildContext context) {
    if (isWebCaptcha) {
      final config = captchaWebConfig;
      final displayName = config?.displayName ?? '人机验证';

      return StatefulBuilder(
        builder: (context, setState) {
          final hasProxy = _proxyConfig != null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoadingCaptcha
                    ? null
                    : () async {
                        await openCaptchaChallenge(context);
                        setState(() {});
                      },
                onLongPress: _isDesktop && Platform.isWindows
                    ? () => _showProxyDialog(context, setState)
                    : null,
                icon: Icon(
                  _captchaToken == null
                      ? Icons.verified_user_outlined
                      : Icons.verified,
                ),
                label: Text(
                  _captchaToken == null
                      ? '点击完成 $displayName'
                      : '$displayName 已完成，点击重新验证',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isDesktop && Platform.isWindows
                    ? '当前验证码类型：$displayName${hasProxy ? '  (代理: $_proxyConfig)' : ''}\n网络问题验证失败可长按上方按钮可以设置代理(仅windows)'
                    : '当前验证码类型：$displayName',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          );
        },
      );
    }

    Widget captchaPreview;

    if (_isLoadingCaptcha) {
      captchaPreview = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_captchaImage != null && _captchaImage!.isNotEmpty) {
      try {
        final base64Part = _captchaImage!.contains(',')
            ? _captchaImage!.split(',').last
            : _captchaImage!;

        captchaPreview = Image.memory(
          base64Decode(base64Part),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      } catch (_) {
        captchaPreview = const Text('刷新');
      }
    } else {
      captchaPreview = const Text('刷新');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: captchaController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '验证码',
              hintText: '请输入验证码',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            validator: (value) {
              final needCaptcha =
                  _captchaTicket != null && _captchaTicket!.isNotEmpty;

              if (needCaptcha && (value == null || value.trim().isEmpty)) {
                return '请输入验证码';
              }

              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _isLoadingCaptcha ? null : refreshCaptcha,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 130,
            height: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: captchaPreview,
          ),
        ),
      ],
    );
  }

  String _normalizeCaptchaType(String? rawType) {
    final value = (rawType ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'normal';

    if (value == 'image' || value == 'graphic' || value == 'captcha') {
      return 'normal';
    }

    if (value == 'recaptcha_v2' ||
        value == 'recaptchav2' ||
        value == 'google' ||
        value == 'google_recaptcha' ||
        value == 'google-recaptcha') {
      return 'recaptcha';
    }

    if (value == 'cloudflare_turnstile' || value == 'cloudflare-turnstile') {
      return 'turnstile';
    }

    return value;
  }

  String? _firstNonEmptyString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Windows 桌面端长按弹出代理设置对话框
  void _showProxyDialog(BuildContext context, StateSetter setState) {
    final hostCtrl = TextEditingController(text: _proxyConfig?.host ?? '');
    final portCtrl = TextEditingController(
      text: _proxyConfig?.port.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('WebView 代理设置'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '仅支持无认证代理（HTTP/SOCKS5）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).hintColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(
                    labelText: '代理地址',
                    hintText: '127.0.0.1',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: portCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '端口',
                    hintText: '7890',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _proxyConfig = null;
                setState(() {});
                Navigator.of(ctx).pop();
                ToastHelper.success('已清除代理配置');
              },
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final host = hostCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 0;
                if (host.isEmpty || port <= 0) {
                  ToastHelper.failure('请输入有效的代理地址和端口');
                  return;
                }
                _proxyConfig = CaptchaProxyConfig(host: host, port: port);
                setState(() {});
                Navigator.of(ctx).pop();
                ToastHelper.success('代理已设置: $host:$port');
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
