import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloudreve4_flutter/data/models/login_config_model.dart';
import 'package:cloudreve4_flutter/main.dart' show isOnLoginPage;
import 'package:window_manager/window_manager.dart';
import 'package:cloudreve4_flutter/services/captcha_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/brand_config.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/validators/string_validator.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/qr_login_service.dart';
import '../../../services/server_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';
import 'widgets/auth_server_sheets.dart';
import 'widgets/login_error_parser.dart';
import 'widgets/two_factor_dialog.dart';

import 'package:cloudreve4_flutter/mkw_packager/generated/qr_login_config.dart';
class LoginDesktopPage extends StatefulWidget {
  final bool showBackButton;

  const LoginDesktopPage({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<LoginDesktopPage> createState() => _LoginDesktopPageState();
}

enum _LoginMode { qr, password, forgot, register }

class _LoginDesktopPageState extends State<LoginDesktopPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  final _forgotEmailController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _forgotFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  late final AnimationController _entranceController;
  late final AnimationController _auroraController;
  late final AnimationController _logoFloatController;
  late final Animation<Offset> _loginSlideAnimation;
  late final Animation<double> _loginFadeAnimation;

  bool _obscurePassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _inlineAuthError;

  _LoginMode _loginMode = mkwQrLoginEnabled && BrandConfig.qrLoginEnabled ? _LoginMode.qr : _LoginMode.password;
  bool _isQrLoading = false;
  String? _qrError;
  bool _qrRelayUnavailable = false;
  QrLoginSession? _qrSession;
  Timer? _qrPollTimer;

  String? _siteName;
  String? _siteDescription;
  String? _siteLogoUrl;
  Uint8List? _siteLogoBytes;

  LoginConfigModel _loginConfig = const LoginConfigModel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isOnLoginPage.value = true;
    });
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    );
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _logoFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _loginSlideAnimation =
        Tween<Offset>(begin: const Offset(-0.28, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.24, 1, curve: Curves.easeOutCubic),
          ),
        );
    _loginFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.18, 0.86, curve: Curves.easeOut),
    );
    _entranceController.forward();

    _loadRememberedInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLoginConfig();
      await _loadSiteBrand();
      if (mounted && mkwQrLoginEnabled) _startQrLogin();
    });
  }

  @override
  void dispose() {
    scheduleMicrotask(() {
      isOnLoginPage.value = false;
    });
    _qrPollTimer?.cancel();
    _entranceController.dispose();
    _auroraController.dispose();
    _logoFloatController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _forgotEmailController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleBackToPreviousPage() {
    _qrPollTimer?.cancel();
    _focusNode.unfocus();
    Navigator.of(context).pop(false);
  }

  Future<void> _loadRememberedInfo() async {
    final server = ServerService.instance.currentServer;
    if (server != null) {
      setState(() {
        if (server.email != null) {
          _emailController.text = server.email!;
        }
        if (server.password != null && server.rememberMe) {
          _passwordController.text = server.password!;
        }
        _rememberMe = server.rememberMe;
      });
    }
  }

  Future<void> _loadLoginConfig() async {
    final server = ServerService.instance.currentServer;
    if (server == null) return;

    try {
      await ApiService.instance.setBaseUrl(server.baseUrl);
      final config = await AuthService.instance.getLoginConfig().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;
      setState(() => _loginConfig = config);

      CaptchaService.instance.clearCaptcha();
      if (config.loginCaptcha) {
        await CaptchaService.instance.loadCaptcha(server.baseUrl);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadSiteBrand() async {
    final server = ServerService.instance.currentServer;
    if (server == null) return;

    final fallbackName = server.label.trim().isEmpty
        ? 'Cloudreve'
        : server.label.trim();
    final fallbackDescription = '登录后继续管理你的云端文件。';
    final fallbackLogo = QrLoginService.faviconUrlFromCloudreve(server.baseUrl);

    String? siteName;
    String? description;
    String? logo;

    try {
      await ApiService.instance.setBaseUrl(server.baseUrl);
      final config = await AuthService.instance.getBasicSiteConfig().timeout(
        const Duration(seconds: 8),
      );

      siteName = _firstString(config, const [
        'title',
        'name',
        'site_name',
        'siteName',
        'site_title',
        'siteTitle',
        'app_name',
        'appName',
        'product_name',
      ]);
      description = _firstString(config, const [
        'description',
        'site_description',
        'siteDescription',
        'subtitle',
        'sub_title',
        'site_subtitle',
        'siteSubtitle',
        'site_notice',
        'notice',
      ]);
      logo = _firstString(config, const [
        'favicon',
        'favicon_url',
        'faviconUrl',
        'site_icon',
        'siteIcon',
        'icon',
        'logo',
        'logo_url',
        'logoUrl',
        'site_logo',
        'siteLogo',
      ]);
    } catch (_) {}

    try {
      final htmlBrand = await _fetchSiteHtmlBrand(
        server.baseUrl,
      ).timeout(const Duration(seconds: 8));
      siteName = htmlBrand.title ?? siteName;
      description = htmlBrand.description ?? description;
      logo = htmlBrand.iconUrl ?? logo;
    } catch (_) {}

    final resolvedLogo =
        _resolveSiteAssetUrl(server.baseUrl, logo) ?? fallbackLogo;
    Uint8List? logoBytes;
    try {
      logoBytes = await _fetchBytesDirect(
        resolvedLogo,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _siteName = _cleanSiteText(siteName) ?? fallbackName;
      _siteDescription = _cleanSiteText(description) ?? fallbackDescription;
      _siteLogoUrl = resolvedLogo;
      _siteLogoBytes = logoBytes;
    });
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null && value is! Map && value is! List) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map) {
        final found = _firstString(Map<String, dynamic>.from(value), keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _cleanSiteText(String? value) {
    if (value == null) return null;
    final text = value
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
    return text.isEmpty ? null : text;
  }

  String? _resolveSiteAssetUrl(String baseUrl, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final site = QrLoginService.cloudreveSiteBase(baseUrl);
    final uri = Uri.parse(site);
    if (raw.startsWith('//')) return '${uri.scheme}:$raw';
    if (raw.startsWith('/')) return '${uri.scheme}://${uri.authority}$raw';
    return '${site.replaceFirst(RegExp(r'/+$'), '')}/$raw';
  }

  Future<_SiteHtmlBrand> _fetchSiteHtmlBrand(String baseUrl) async {
    final site = QrLoginService.cloudreveSiteBase(baseUrl);
    final uri = Uri.parse(site);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml',
      );
      final response = await request.close();
      final html = await utf8.decodeStream(response);
      return _SiteHtmlBrand(
        title: _extractHtmlTitle(html),
        description: _extractMetaContent(html, 'description'),
        iconUrl: _extractIconHref(html, site),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List?> _fetchBytesDirect(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'image/*,*/*;q=0.8');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final chunks = <int>[];
      await for (final chunk in response) {
        chunks.addAll(chunk);
        if (chunks.length > 1024 * 1024) return null;
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }

  String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return _decodeHtmlText(match?.group(1));
  }

  String? _extractMetaContent(String html, String name) {
    final escaped = RegExp.escape(name);
    final patterns = [
      RegExp(
        '<meta[^>]+name=["\\\']$escaped["\\\'][^>]+content=["\\\']([^"\\\']+)["\\\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta[^>]+content=["\\\']([^"\\\']+)["\\\'][^>]+name=["\\\']$escaped["\\\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = _decodeHtmlText(match?.group(1));
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractIconHref(String html, String baseUrl) {
    final linkPattern = RegExp(
      r'''<link[^>]+(?:rel=["'][^"']*(?:icon|shortcut icon|apple-touch-icon)[^"']*["']|href=["'][^"']+["'])[^>]*>''',
      caseSensitive: false,
      dotAll: true,
    );
    final hrefPattern = RegExp(
      r'''href=["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in linkPattern.allMatches(html)) {
      final tag = match.group(0) ?? '';
      if (!tag.toLowerCase().contains('icon')) continue;
      final href = hrefPattern.firstMatch(tag)?.group(1);
      final resolved = _resolveSiteAssetUrl(baseUrl, href);
      if (resolved != null) return resolved;
    }
    return null;
  }

  String? _decodeHtmlText(String? value) {
    if (value == null) return null;
    final text = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _showServerSelector() async {
    if (BrandConfig.hasFixedServer) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const SizedBox(
          width: 560,
          height: 520,
          child: ServerSelectorSheet(),
        ),
      ),
    );
    await _loadRememberedInfo();
    await _loadLoginConfig();
    await _loadSiteBrand();
    if (mounted && _loginMode == _LoginMode.qr) _startQrLogin();
  }

  Future<void> _showServerManagement() async {
    if (BrandConfig.hasFixedServer) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const SizedBox(
          width: 620,
          height: 620,
          child: ServerManagementSheet(),
        ),
      ),
    );
    await _loadRememberedInfo();
    await _loadLoginConfig();
    await _loadSiteBrand();
    if (mounted && _loginMode == _LoginMode.qr) _startQrLogin();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final captcha = CaptchaService.instance;

    if (_loginConfig.loginCaptcha && !captcha.isWebCaptchaVerified) {
      ToastHelper.failure('请先完成人机验证');
      return;
    }

    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final captchaParams = _loginConfig.loginCaptcha
          ? captcha.getCaptchaParams()
          : <String, String>{};

      final success = await authProvider
          .passwordLogin(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            rememberMe: _rememberMe,
            captcha: captchaParams['captcha'],
            ticket: captchaParams['ticket'],
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('请求超时'),
          );

      if (mounted) setState(() => _isLoading = false);

      if (success && mounted) {
        _focusNode.unfocus();
        ToastHelper.success('登录成功');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          if (widget.showBackButton) {
            navigator.pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
          } else {
            navigator.pushReplacementNamed(RouteNames.home);
          }
        }
      } else if (mounted) {
        if (_loginConfig.loginCaptcha) {
          await captcha.refreshCaptcha();
          setState(() {});
        }

        final errorMessage = authProvider.errorMessage;
        if (errorMessage != null && errorMessage.isNotEmpty) {
          final errorMsg = parseLoginErrorMessage(errorMessage);
          ToastHelper.failure(errorMsg);
        } else {
          ToastHelper.failure('登录失败');
        }
      }
    } on TwoFactorRequiredException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showTwoFactorDialog(e.sessionId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_loginConfig.loginCaptcha) {
          await captcha.refreshCaptcha();
          setState(() {});
        }

        final errorMsg = parseLoginErrorMessage(e.toString());
        ToastHelper.failure(errorMsg);
      }
    }
  }

  Future<void> _showTwoFactorDialog(String sessionId) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TwoFactorDialog(
        sessionId: sessionId,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      ),
    );

    if (success != true || !mounted) return;

    _focusNode.unfocus();
    ToastHelper.success('登录成功');
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      final navigator = Navigator.of(context);
      if (widget.showBackButton) {
        navigator.pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
      } else {
        navigator.pushReplacementNamed(RouteNames.home);
      }
    }
  }

  Future<void> _switchLoginMode(_LoginMode mode) async {
    if (_loginMode == mode) return;
    _focusNode.unfocus();
    setState(() {
      _loginMode = mode;
      _qrError = null;
      _qrRelayUnavailable = false;
      _inlineAuthError = null;
    });
    if (mode == _LoginMode.qr) {
      _startQrLogin();
    } else {
      _qrPollTimer?.cancel();
      await _ensureCaptchaForMode(mode);
    }
  }

  bool _modeRequiresCaptcha(_LoginMode mode) {
    return switch (mode) {
      _LoginMode.password => _loginConfig.loginCaptcha,
      _LoginMode.forgot => _loginConfig.forgetCaptcha,
      _LoginMode.register => _loginConfig.regCaptcha,
      _LoginMode.qr => false,
    };
  }

  Future<void> _ensureCaptchaForMode(_LoginMode mode) async {
    if (!_modeRequiresCaptcha(mode)) return;
    final server = ServerService.instance.currentServer;
    if (server == null) return;
    CaptchaService.instance.clearCaptcha();
    await CaptchaService.instance.loadCaptcha(server.baseUrl);
    if (mounted) setState(() {});
  }

  Future<void> _refreshCaptchaAfterFailure(_LoginMode mode) async {
    if (!_modeRequiresCaptcha(mode)) return;
    await CaptchaService.instance.refreshCaptcha();
    if (mounted) setState(() {});
  }

  Future<void> _startQrLogin() async {
    if (!BrandConfig.qrLoginEnabled) {
      _qrPollTimer?.cancel();
      return;
    }
    final server = ServerService.instance.currentServer;
    if (server == null) {
      setState(() {
        _qrSession = null;
        _qrError = '请先选择服务器';
      });
      return;
    }

    _qrPollTimer?.cancel();
    setState(() {
      _isQrLoading = true;
      _qrError = null;
      _qrRelayUnavailable = false;
      _qrSession = null;
    });

    try {
      final relayBaseUrl = QrLoginService.relayBaseForCloudreve(server.baseUrl);
      try {
        await QrLoginService.instance
            .healthCheck(relayBaseUrl)
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isQrLoading = false;
          _qrRelayUnavailable = true;
          _qrError = '健康检查失败, 扫描登录不可用, 请检查二维码插件是否正常部署\n($relayBaseUrl/api/health)';
        });
        return;
      }

      final session = await QrLoginService.instance
          .createSession(
            cloudreveBaseUrl: server.baseUrl,
            deviceName: 'Windows 客户端',
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _qrSession = session;
        _isQrLoading = false;
        _qrError = null;
        _qrRelayUnavailable = false;
      });
      debugPrint(
        '[QR][desktop] session created sid=${session.sessionId} relay=${session.relayBaseUrl}',
      );
      _qrPollTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _pollQrLoginResult(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isQrLoading = false;
        _qrError =
            '无法连接扫码登录中转服务，请确认服务器已安装 /qr-login-relay。\n${parseLoginErrorMessage(e.toString())}';
      });
    }
  }

  Future<void> _pollQrLoginResult() async {
    final session = _qrSession;
    if (session == null || _isLoading) return;

    try {
      final status = await QrLoginService.instance.getStatus(session);
      if (!mounted) return;

      final normalizedStatus = status.status.trim().toLowerCase();
      debugPrint(
        '[QR][desktop] poll sid=${session.sessionId} status=$normalizedStatus message=${status.message ?? ''}',
      );

      if (_isQrAuthorizedStatus(normalizedStatus)) {
        _qrPollTimer?.cancel();
        setState(() => _isLoading = true);
        final payload = await QrLoginService.instance.getResult(session);
        if (!QrLoginService.isSameCloudreve(
          ServerService.instance.currentServer?.baseUrl ?? '',
          payload.cloudreveBaseUrl,
        )) {
          throw Exception('手机端授权站点与当前客户端站点不一致');
        }
        await _completeQrLogin(payload);
        return;
      }

      if (normalizedStatus == 'expired') {
        _qrPollTimer?.cancel();
        setState(() => _qrError = '二维码已过期，请重新生成');
        return;
      }

      if (normalizedStatus == 'scanned') {
        setState(() => _qrError = '手机已扫码，请在手机端确认登录');
        return;
      }

      if (status.message != null && status.message!.isNotEmpty) {
        setState(() => _qrError = status.message);
      }
    } catch (e, stackTrace) {
      debugPrint('[QR][desktop] poll failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      // 轮询失败不立刻打断二维码，避免短暂网络抖动导致界面频繁报错。
    }
  }

  bool _isQrAuthorizedStatus(String status) {
    return const {
      'authorized',
      'confirmed',
      'success',
      'completed',
      'done',
    }.contains(status);
  }

  Future<void> _completeQrLogin(QrLoginTokenPayload payload) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await ServerService.instance.updateCurrentServerLogin(user: payload.user);

      authProvider.setUser(payload.user);
      authProvider.setState(AuthState.authenticated);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _focusNode.unfocus();
      ToastHelper.success('扫码登录成功');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
      final navigator = Navigator.of(context);
      if (widget.showBackButton) {
        navigator.pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
      } else {
        navigator.pushReplacementNamed(RouteNames.home);
      }
    }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _qrError = parseLoginErrorMessage(e.toString());
      });
      ToastHelper.failure(_qrError ?? '扫码登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxWidth < 760;
            return Stack(
              children: [
                Positioned.fill(
                  child: compact
                      ? SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: viewport.maxHeight,
                            ),
                            child: _buildLoginShell(theme, compact: true),
                          ),
                        )
                      : _buildLoginShell(theme, compact: false),
                ),
                if (Platform.isWindows || Platform.isLinux)
                  const Positioned(
                    left: 0,
                    right: 132,
                    top: 0,
                    height: 58,
                    child: DragToMoveArea(child: SizedBox.expand()),
                  ),
                if (widget.showBackButton)
                  Positioned(
                    top: 14,
                    left: 18,
                    child: _LoginGlassBackButton(
                      onTap: _handleBackToPreviousPage,
                    ),
                  ),
                if (Platform.isWindows || Platform.isLinux)
                  const Positioned(
                    top: 14,
                    right: 18,
                    child: _LoginWindowControls(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginShell(ThemeData theme, {required bool compact}) {
    // 这里不要再做 Flutter 内部圆角裁剪。
    // 用户要的是 Windows 原生窗口外框/窗口区域变圆，
    // 内部页面必须保持直角铺满，避免出现“里面又套了一层圆角”。
    return SizedBox.expand(
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBrandPanel(theme, compact: true),
                _buildLoginPanel(theme, compact: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(0, 0.46, curve: Curves.easeOut),
                    ),
                    child: _buildBrandPanel(theme, compact: false),
                  ),
                ),
                Expanded(
                  flex: 9,
                  child: FadeTransition(
                    opacity: _loginFadeAnimation,
                    child: SlideTransition(
                      position: _loginSlideAnimation,
                      child: _buildLoginPanel(theme, compact: false),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBrandPanel(ThemeData theme, {required bool compact}) {
    final server = ServerService.instance.currentServer;
    final siteName =
        _siteName ??
        (server?.label.trim().isNotEmpty == true
            ? server!.label.trim()
            : 'Cloudreve');
    final siteDescription = _siteDescription ?? '登录后继续管理你的云端文件。';

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (compact ? 520.0 : 760.0);
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (compact ? 360.0 : 720.0);
        final designWidth = compact ? 420.0 : 620.0;
        final designHeight = compact ? 330.0 : 560.0;
        final brandScale = math
            .min(availableWidth / designWidth, availableHeight / designHeight)
            .clamp(0.62, 1.0)
            .toDouble();
        final logoSize = (compact ? 150.0 : 238.0) * brandScale;
        final titleSize = (compact ? 30.0 : 38.0) * brandScale;
        final bodySize = 16.0 * brandScale;
        final floatDistance = (compact ? 7.0 : 9.0) * brandScale;

        final brandContent = SizedBox(
          width: (compact ? 420.0 : 560.0) * brandScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoFloatController,
                child: RepaintBoundary(child: _buildSiteLogo(size: logoSize)),
                builder: (context, child) {
                  final t = _logoFloatController.value * math.pi * 2;
                  return Transform.translate(
                    offset: Offset(0, math.sin(t) * floatDistance),
                    child: child,
                  );
                },
              ),
              SizedBox(height: (compact ? 24.0 : 30.0) * brandScale),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.0 * brandScale),
                child: Text(
                  siteName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: titleSize.clamp(22.0, 38.0),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2F2529),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(height: 12.0 * brandScale),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 460.0 * brandScale),
                child: Text(
                  siteDescription,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: bodySize.clamp(12.0, 16.0),
                    color: const Color(0xFF6D6670),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );

        return SizedBox(
          width: double.infinity,
          height: compact ? math.max(320.0, availableHeight) : double.infinity,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AuroraGlassBackground(animation: _auroraController),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.20),
                          const Color(0xFFFFEEF5).withValues(alpha: 0.20),
                          const Color(0xFFEAF6FF).withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 44,
                    vertical: compact ? 24 : 36,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: brandContent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginPanel(ThemeData theme, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 620.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (compact ? 640.0 : 720.0);
        final widthScale = compact
            ? 1.0
            : (availableWidth / 620.0).clamp(0.88, 1.12).toDouble();
        final topSafePadding = compact ? 0.0 : 42.0;
        final availableContentHeight = compact
            ? availableHeight
            : (availableHeight - topSafePadding - 18.0)
                  .clamp(300.0, availableHeight)
                  .toDouble();
        final heightScale = compact
            ? 1.0
            : (availableContentHeight / 760.0).clamp(0.54, 1.10).toDouble();
        final modeDesignHeight = switch (_loginMode) {
          _LoginMode.qr => 560.0,
          _LoginMode.password => _loginConfig.loginCaptcha ? 600.0 : 505.0,
          _LoginMode.forgot => _loginConfig.forgetCaptcha ? 500.0 : 400.0,
          _LoginMode.register => _loginConfig.regCaptcha ? 670.0 : 570.0,
        };
        final modeHeightScale = compact
            ? 1.0
            : (availableContentHeight / modeDesignHeight)
                  .clamp(0.52, 1.10)
                  .toDouble();
        final panelScale = compact
            ? 1.0
            : math.min(widthScale, math.min(heightScale, modeHeightScale));
        final horizontalPadding = compact
            ? 24.0
            : (40.0 * panelScale).clamp(34.0, 52.0).toDouble();
        final verticalPadding = compact
            ? 20.0
            : (14.0 * panelScale).clamp(6.0, 16.0).toDouble();
        final contentMaxWidth = compact
            ? availableWidth.clamp(320.0, 560.0).toDouble()
            : (540.0 * panelScale).clamp(440.0, 560.0).toDouble();

        Widget content = SizedBox(
          width: contentMaxWidth,
          child: Theme(
            data: theme.copyWith(
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: (14.0 * panelScale).clamp(10.0, 14.0).toDouble(),
                  vertical: (14.0 * panelScale).clamp(9.0, 14.0).toDouble(),
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!BrandConfig.hasFixedServer) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _ServerSelector(onTap: _showServerSelector),
                      ),
                      const SizedBox(width: 12),
                      _ManageServersButton(onTap: _showServerManagement),
                    ],
                  ),
                  SizedBox(
                    height: compact
                        ? 22
                        : (22.0 * panelScale).clamp(16.0, 24.0).toDouble(),
                  ),
                ],
                ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(-0.045, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: switch (_loginMode) {
                      _LoginMode.qr => mkwQrLoginEnabled
                          ? _buildQrLoginPanel(
                              theme,
                              scale: panelScale,
                            )
                          : _buildPasswordLoginPanel(
                              theme,
                              scale: panelScale,
                            ),
                      _LoginMode.password => _buildPasswordLoginPanel(
                        theme,
                        scale: panelScale,
                      ),
                      _LoginMode.forgot => _buildForgotPasswordPanel(
                        theme,
                        scale: panelScale,
                      ),
                      _LoginMode.register => _buildRegisterPanel(
                        theme,
                        scale: panelScale,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        final child = compact
            ? ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (availableHeight - verticalPadding * 2).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(child: content),
                  ),
                ),
              )
            : Center(
                child: SizedBox(
                  width: (availableWidth - horizontalPadding * 2)
                      .clamp(440.0, 760.0)
                      .toDouble(),
                  height: (availableContentHeight - verticalPadding * 2)
                      .clamp(360.0, 760.0)
                      .toDouble(),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: content,
                  ),
                ),
              );

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding + topSafePadding,
            horizontalPadding,
            verticalPadding,
          ),
          child: child,
        );
      },
    );
  }

  bool get _isQrExpired => (_qrError ?? '').contains('二维码已过期');

  Widget _buildQrLoginPanel(ThemeData theme, {double scale = 1.0}) {
    final session = _qrSession;
    final qrBoxSize = (218.0 * scale).clamp(150.0, 282.0).toDouble();
    final qrPadding = (14.0 * scale).clamp(8.0, 18.0).toDouble();
    final showExpiredOverlay = _isQrExpired && session != null;
    final statusColor = _qrError != null && !_isQrExpired
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      key: const ValueKey('qr-login'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '手机扫码登录',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: (24.0 * scale).clamp(20.0, 29.0).toDouble(),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: _gap(6, scale, min: 3)),
        Text(
          '使用手机端已登录账号扫码确认后，即可登录电脑端。',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: (14.0 * scale).clamp(12.0, 16.0).toDouble(),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: _gap(18, scale, min: 8)),
        Center(
          child: Container(
            width: qrBoxSize,
            height: qrBoxSize,
            padding: EdgeInsets.all(qrPadding),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7FA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF2D7E0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isQrLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (session == null)
                    Center(
                      child: Icon(
                        LucideIcons.qrCode,
                        size: 78,
                        color: theme.colorScheme.outline,
                      ),
                    )
                  else
                    QrImageView(
                      data: session.qrPayload,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      gapless: true,
                    ),
                  if (showExpiredOverlay)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.42),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE8CAD5),
                                ),
                              ),
                              child: Text(
                                '二维码过期',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFFA14564),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: _gap(10, scale, min: 4)),
        Center(
          child: _buildQrStatusContent(theme, statusColor),
        ),
        SizedBox(height: _gap(12, scale, min: 4)),
        FilledButton.icon(
          onPressed: _isQrLoading ? null : _startQrLogin,
          style: FilledButton.styleFrom(
            minimumSize: Size(
              double.infinity,
              _buttonHeight(46, scale, min: 38),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFFA95775),
          ),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: Text(session == null ? '生成二维码' : '重新生成二维码'),
        ),
        SizedBox(height: _gap(12, scale, min: 6)),
        OutlinedButton.icon(
          onPressed: () => _switchLoginMode(_LoginMode.password),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(
              double.infinity,
              _buttonHeight(44, scale, min: 36),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(LucideIcons.mail, size: 18),
          label: const Text('使用账号密码登录'),
        ),
        SizedBox(height: _gap(8, scale, min: 4)),
        _buildAuthLinkRow(),
      ],
    );
  }

  String _qrStatusText() {
    if (_isQrExpired) {
      return '请打开手机端，点击概览页左上角扫码图标扫描二维码。';
    }
    if (_qrError != null) return _qrError!;
    if (_isQrLoading) return '正在连接扫码登录中转服务...';
    if (_qrSession == null) return '点击生成二维码后，用手机端扫码确认登录。';
    return '请打开手机端，点击概览页左上角扫码图标扫描二维码。';
  }

  static const String _qrRelayPluginUrl =
      'https://github.com/LimoYuan/mkw_qr_relay_server';

  Widget _buildQrStatusContent(ThemeData theme, Color statusColor) {
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: statusColor,
      height: 1.5,
    );

    final statusText = Text(
      _qrStatusText(),
      textAlign: TextAlign.center,
      style: baseStyle,
    );

    if (!_qrRelayUnavailable) return statusText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        statusText,
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: baseStyle?.copyWith(fontSize: 12),
            children: [
              const TextSpan(text: '插件来自 @mkw3627-ui 部署方案，'),
              TextSpan(
                text: '点击浏览器访问',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = _openQrRelayPluginPage,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _openQrRelayPluginPage() async {
    final uri = Uri.parse(_qrRelayPluginUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ToastHelper.failure('无法打开浏览器：$_qrRelayPluginUrl');
    }
  }

  double _gap(double value, double scale, {double min = 6.0}) =>
      (value * scale).clamp(min, value * 1.12).toDouble();

  double _buttonHeight(double value, double scale, {double min = 42.0}) =>
      (value * scale).clamp(min, value * 1.08).toDouble();

  Widget _buildPasswordLoginPanel(ThemeData theme, {double scale = 1.0}) {
    final captcha = CaptchaService.instance;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('password-login'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '账号密码登录',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (mkwQrLoginEnabled)
              TextButton.icon(
                onPressed: () => _switchLoginMode(_LoginMode.qr),
                icon: const Icon(LucideIcons.qrCode, size: 18),
                label: const Text('扫码登录'),
              ),
            ],
          ),
          SizedBox(height: _gap(20, scale, min: 10)),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: StringValidator.validateEmail,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(LucideIcons.mail),
            ),
            onFieldSubmitted: (_) => _focusNode.requestFocus(),
          ),
          SizedBox(height: _gap(14, scale, min: 8)),
          TextFormField(
            controller: _passwordController,
            focusNode: _focusNode,
            obscureText: _obscurePassword,
            validator: StringValidator.validatePassword,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              prefixIcon: const Icon(LucideIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onFieldSubmitted: (_) => _login(),
          ),
          if (_loginConfig.loginCaptcha) ...[
            SizedBox(height: _gap(12, scale, min: 6)),
            captcha.buildCaptchaInput(context),
          ],
          SizedBox(height: _gap(10, scale, min: 5)),
          InkWell(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('记住我'),
              ],
            ),
          ),
          SizedBox(height: _gap(14, scale, min: 6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _switchLoginMode(_LoginMode.forgot),
                child: const Text('忘记密码？'),
              ),
              TextButton(
                onPressed: () => _switchLoginMode(_LoginMode.register),
                child: const Text('注册账号'),
              ),
            ],
          ),
          SizedBox(height: _gap(10, scale, min: 5)),
          FilledButton(
            onPressed: _isLoading ? null : _login,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, _buttonHeight(50, scale)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFFA95775),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthLinkRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => _switchLoginMode(_LoginMode.forgot),
          child: const Text('忘记密码？'),
        ),
        TextButton(
          onPressed: () => _switchLoginMode(_LoginMode.register),
          child: const Text('注册账号'),
        ),
      ],
    );
  }

  Widget _buildPanelBackButton(String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey(title),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _isLoading
                  ? null
                  : () => _switchLoginMode(_LoginMode.password),
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              tooltip: '返回登录',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_inlineAuthError != null) ...[
          const SizedBox(height: 16),
          _buildInlineError(theme, _inlineAuthError!),
        ],
      ],
    );
  }

  Widget _buildInlineError(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        parseLoginErrorMessage(message),
        style: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildForgotPasswordPanel(ThemeData theme, {double scale = 1.0}) {
    final captcha = CaptchaService.instance;
    return Form(
      key: _forgotFormKey,
      child: Column(
        key: const ValueKey('forgot-password-inline'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelBackButton('找回密码', '输入账号邮箱后，我们会把重置链接发送到你的邮箱。'),
          SizedBox(height: _gap(18, scale, min: 8)),
          TextFormField(
            controller: _forgotEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: StringValidator.validateEmail,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(LucideIcons.mail),
            ),
            onFieldSubmitted: (_) => _sendResetEmailInline(),
          ),
          if (_loginConfig.forgetCaptcha) ...[
            SizedBox(height: _gap(12, scale, min: 6)),
            captcha.buildCaptchaInput(context),
          ],
          SizedBox(height: _gap(16, scale, min: 8)),
          FilledButton(
            onPressed: _isLoading ? null : _sendResetEmailInline,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, _buttonHeight(50, scale)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFFA95775),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发送重置邮件'),
          ),
          SizedBox(height: _gap(8, scale, min: 4)),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => _switchLoginMode(_LoginMode.password),
              child: const Text('想起来了，返回登录'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterPanel(ThemeData theme, {double scale = 1.0}) {
    final captcha = CaptchaService.instance;
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register-inline'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelBackButton('注册账号', '创建新账号后即可在当前页面继续登录。'),
          SizedBox(height: _gap(18, scale, min: 8)),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: StringValidator.validateEmail,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(LucideIcons.mail),
            ),
          ),
          SizedBox(height: _gap(12, scale, min: 7)),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            validator: StringValidator.validatePassword,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码（至少6位）',
              prefixIcon: const Icon(LucideIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterPassword
                      ? LucideIcons.eye
                      : LucideIcons.eyeOff,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureRegisterPassword = !_obscureRegisterPassword,
                ),
              ),
            ),
          ),
          SizedBox(height: _gap(12, scale, min: 7)),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _obscureRegisterConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请确认密码';
              }
              if (value != _registerPasswordController.text) {
                return '两次输入的密码不一致';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: '确认密码',
              hintText: '请再次输入密码',
              prefixIcon: const Icon(LucideIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterConfirmPassword
                      ? LucideIcons.eye
                      : LucideIcons.eyeOff,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureRegisterConfirmPassword =
                      !_obscureRegisterConfirmPassword,
                ),
              ),
            ),
          ),
          if (_loginConfig.regCaptcha) ...[
            SizedBox(height: _gap(12, scale, min: 6)),
            captcha.buildCaptchaInput(context),
          ],
          SizedBox(height: _gap(16, scale, min: 8)),
          FilledButton(
            onPressed: _isLoading ? null : _registerInline,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, _buttonHeight(50, scale)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: const Color(0xFFA95775),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('注册'),
          ),
          SizedBox(height: _gap(8, scale, min: 4)),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => _switchLoginMode(_LoginMode.password),
              child: const Text('已有账号？返回登录'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendResetEmailInline() async {
    if (!_forgotFormKey.currentState!.validate()) return;

    final captcha = CaptchaService.instance;
    if (_loginConfig.forgetCaptcha && !captcha.isWebCaptchaVerified) {
      ToastHelper.failure('请先完成人机验证');
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineAuthError = null;
    });

    try {
      final captchaParams = _loginConfig.forgetCaptcha
          ? captcha.getCaptchaParams()
          : <String, String>{};

      await AuthService.instance.sendResetPasswordEmail(
        email: _forgotEmailController.text.trim(),
        captcha: captchaParams['captcha'],
        ticket: captchaParams['ticket'],
      );

      if (!mounted) return;
      ToastHelper.success('重置密码邮件已发送，请查收邮箱');
      _emailController.text = _forgotEmailController.text.trim();
      setState(() => _isLoading = false);
      await _switchLoginMode(_LoginMode.password);
    } catch (e) {
      if (!mounted) return;
      await _refreshCaptchaAfterFailure(_LoginMode.forgot);
      setState(() {
        _isLoading = false;
        _inlineAuthError = e.toString();
      });
    }
  }

  Future<void> _registerInline() async {
    if (!_registerFormKey.currentState!.validate()) return;

    if (_registerPasswordController.text !=
        _registerConfirmPasswordController.text) {
      setState(() => _inlineAuthError = '两次输入的密码不一致');
      return;
    }

    final captcha = CaptchaService.instance;
    if (_loginConfig.regCaptcha && !captcha.isWebCaptchaVerified) {
      ToastHelper.failure('请先完成人机验证');
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineAuthError = null;
    });

    try {
      final captchaParams = _loginConfig.regCaptcha
          ? captcha.getCaptchaParams()
          : <String, String>{};

      final response = await AuthService.instance.signUp(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        language: 'zh-CN',
        captcha: captchaParams['captcha'],
        ticket: captchaParams['ticket'],
      );

      if (!mounted) return;
      ToastHelper.success(
        response.requiresEmailActivation ? '注册成功，请查收邮箱进行验证' : '注册成功',
      );
      _emailController.text = _registerEmailController.text.trim();
      _passwordController.text = _registerPasswordController.text;
      setState(() => _isLoading = false);
      await _switchLoginMode(_LoginMode.password);
    } catch (e) {
      if (!mounted) return;
      await _refreshCaptchaAfterFailure(_LoginMode.register);
      setState(() {
        _isLoading = false;
        _inlineAuthError = e.toString();
      });
    }
  }

  Widget _buildSiteLogo({required double size}) {
    final server = ServerService.instance.currentServer;
    final faviconUrl =
        _siteLogoUrl ??
        (server == null
            ? null
            : QrLoginService.faviconUrlFromCloudreve(server.baseUrl));

    Widget fallback() => Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    final Widget image;
    if (_siteLogoBytes != null && _siteLogoBytes!.isNotEmpty) {
      image = Image.memory(
        _siteLogoBytes!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else if (faviconUrl != null) {
      image = Image.network(
        faviconUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = fallback();
    }

    return SizedBox(
      width: size + 16,
      height: size + 16,
      child: Center(child: image),
    );
  }
}

class _AuroraGlassBackground extends StatelessWidget {
  final Animation<double> animation;

  const _AuroraGlassBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraGlassPainter(animation),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuroraGlassPainter extends CustomPainter {
  final Animation<double> animation;

  _AuroraGlassPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = animation.value * math.pi * 2;

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFEDF6),
          Color(0xFFF3ECFF),
          Color(0xFFE8F8FF),
          Color(0xFFFFF7E7),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    void drawBlob({
      required Offset center,
      required double radius,
      required List<Color> colors,
    }) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, radius, colors, const [
          0.0,
          0.56,
          1.0,
        ])
        ..blendMode = BlendMode.srcOver;
      canvas.drawCircle(center, radius, paint);
    }

    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;

    drawBlob(
      center: Offset(
        w * (0.16 + math.sin(t * 0.45) * 0.08),
        h * (0.24 + math.cos(t * 0.58) * 0.10),
      ),
      radius: math.max(w, h) * 0.34,
      colors: [
        const Color(0xFFFF5FA8).withValues(alpha: 0.40),
        const Color(0xFFFF9ED0).withValues(alpha: 0.20),
        Colors.transparent,
      ],
    );

    drawBlob(
      center: Offset(
        w * (0.76 + math.cos(t * 0.38) * 0.10),
        h * (0.26 + math.sin(t * 0.52) * 0.12),
      ),
      radius: math.max(w, h) * 0.38,
      colors: [
        const Color(0xFF7A7CFF).withValues(alpha: 0.34),
        const Color(0xFFC7A6FF).withValues(alpha: 0.18),
        Colors.transparent,
      ],
    );

    drawBlob(
      center: Offset(
        w * (0.58 + math.sin(t * 0.62 + 1.4) * 0.12),
        h * (0.76 + math.cos(t * 0.44 + 0.8) * 0.10),
      ),
      radius: math.max(w, h) * 0.42,
      colors: [
        const Color(0xFF58D7FF).withValues(alpha: 0.34),
        const Color(0xFFB7F7F0).withValues(alpha: 0.18),
        Colors.transparent,
      ],
    );

    drawBlob(
      center: Offset(
        w * (0.28 + math.cos(t * 0.72 + 2.2) * 0.11),
        h * (0.70 + math.sin(t * 0.46 + 0.6) * 0.12),
      ),
      radius: math.max(w, h) * 0.30,
      colors: [
        const Color(0xFFFFD25F).withValues(alpha: 0.30),
        const Color(0xFFFFA86B).withValues(alpha: 0.15),
        Colors.transparent,
      ],
    );

    drawBlob(
      center: Offset(
        w * (0.48 + math.sin(t * 0.33 + 4.1) * 0.10),
        h * (0.46 + math.cos(t * 0.50 + 3.2) * 0.12),
      ),
      radius: math.max(w, h) * 0.28,
      colors: [
        const Color(0xFF80FFB8).withValues(alpha: 0.22),
        const Color(0xFFBFFFD8).withValues(alpha: 0.12),
        Colors.transparent,
      ],
    );

    final glassPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRect(rect, glassPaint);
  }

  @override
  bool shouldRepaint(covariant _AuroraGlassPainter oldDelegate) => false;
}

class _LoginGlassBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoginGlassBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      tooltip: '返回账号切换',
      icon: LucideIcons.arrowLeft,
      onTap: onTap,
    );
  }
}

class _LoginWindowControls extends StatelessWidget {
  const _LoginWindowControls();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowButton(
                tooltip: '最小化',
                icon: LucideIcons.minus,
                onTap: () => windowManager.minimize(),
              ),
              _WindowButton(
                tooltip: '最大化/还原',
                icon: LucideIcons.maximize2,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              _WindowButton(
                tooltip: '关闭',
                icon: LucideIcons.x,
                isClose: true,
                onTap: () => windowManager.close(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isClose
        ? const Color(0xFF9B2948)
        : const Color(0xFF4D4750);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _hovering
                  ? Colors.white.withValues(alpha: 0.58)
                  : Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovering ? 0.66 : 0.24),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Center(
                  child: Icon(widget.icon, size: 17, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteHtmlBrand {
  final String? title;
  final String? description;
  final String? iconUrl;

  const _SiteHtmlBrand({this.title, this.description, this.iconUrl});
}

class _ServerSelector extends StatelessWidget {
  final VoidCallback onTap;

  const _ServerSelector({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentServer = ServerService.instance.currentServer;
    final theme = Theme.of(context);
    final displayUrl = currentServer?.baseUrl ?? '选择服务器';

    return Material(
      color: const Color(0xFFF7F6FB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.server,
                  size: 19,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentServer?.label ?? '选择服务器',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronDown,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageServersButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ManageServersButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8FB),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE8CAD5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 17,
                color: Color(0xFFA95775),
              ),
              SizedBox(width: 8),
              Text(
                '管理',
                style: TextStyle(
                  color: Color(0xFFA95775),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
