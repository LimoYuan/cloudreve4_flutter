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
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/validators/string_validator.dart';
import '../../../data/models/server_model.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/qr_login_service.dart';
import '../../../services/server_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';

class LoginDesktopPage extends StatefulWidget {
  const LoginDesktopPage({super.key});

  @override
  State<LoginDesktopPage> createState() => _LoginDesktopPageState();
}

enum _LoginMode { qr, password, forgot, register }

class _LoginDesktopPageState extends State<LoginDesktopPage> with TickerProviderStateMixin {
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

  _LoginMode _loginMode = _LoginMode.qr;
  bool _isQrLoading = false;
  String? _qrError;
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
    _loginSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.28, 0),
      end: Offset.zero,
    ).animate(
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
      if (mounted) _startQrLogin();
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
      final config = await AuthService.instance
          .getLoginConfig()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => _loginConfig = config);

      if (config.loginCaptcha) {
        await CaptchaService.instance.loadCaptcha(server.baseUrl);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }


  Future<void> _loadSiteBrand() async {
    final server = ServerService.instance.currentServer;
    if (server == null) return;

    final fallbackName = server.label.trim().isEmpty ? 'Cloudreve' : server.label.trim();
    final fallbackDescription = '登录后继续管理你的云端文件。';
    final fallbackLogo = QrLoginService.faviconUrlFromCloudreve(server.baseUrl);

    String? siteName;
    String? description;
    String? logo;

    try {
      await ApiService.instance.setBaseUrl(server.baseUrl);
      final config = await AuthService.instance
          .getBasicSiteConfig()
          .timeout(const Duration(seconds: 8));

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
      final htmlBrand = await _fetchSiteHtmlBrand(server.baseUrl)
          .timeout(const Duration(seconds: 8));
      siteName = htmlBrand.title ?? siteName;
      description = htmlBrand.description ?? description;
      logo = htmlBrand.iconUrl ?? logo;
    } catch (_) {}

    final resolvedLogo = _resolveSiteAssetUrl(server.baseUrl, logo) ?? fallbackLogo;
    Uint8List? logoBytes;
    try {
      logoBytes = await _fetchBytesDirect(resolvedLogo)
          .timeout(const Duration(seconds: 8));
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
    client.findProxy = (_) => 'DIRECT';
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml');
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
    client.findProxy = (_) => 'DIRECT';
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
    final hrefPattern = RegExp(r'''href=["']([^"']+)["']''', caseSensitive: false);
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
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const SizedBox(width: 560, height: 520, child: ServerSelectorSheet()),
      ),
    );
    await _loadRememberedInfo();
    await _loadLoginConfig();
    await _loadSiteBrand();
    if (mounted && _loginMode == _LoginMode.qr) _startQrLogin();
  }

  Future<void> _showServerManagement() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const SizedBox(width: 620, height: 620, child: ServerManagementSheet()),
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
        if (mounted) navigator.pushReplacementNamed(RouteNames.home);
      } else if (mounted) {
        if (_loginConfig.loginCaptcha) {
          await captcha.refreshCaptcha();
          setState(() {});
        }

        final errorMessage = authProvider.errorMessage;
        if (errorMessage != null && errorMessage.isNotEmpty) {
          final errorMsg = _parseErrorMessage(errorMessage);
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

        final errorMsg = _parseErrorMessage(e.toString());
        ToastHelper.failure(errorMsg);
      }
    }
  }

  Future<void> _showTwoFactorDialog(String sessionId) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TwoFactorDialog(
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
    if (mounted) Navigator.of(context).pushReplacementNamed(RouteNames.home);
  }

  Future<void> _switchLoginMode(_LoginMode mode) async {
    if (_loginMode == mode) return;
    _focusNode.unfocus();
    setState(() {
      _loginMode = mode;
      _qrError = null;
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
      _qrSession = null;
    });

    try {
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
      });
      _qrPollTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _pollQrLoginResult(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isQrLoading = false;
        _qrError = '无法连接扫码登录中转服务，请确认服务器已安装 /qr-login-relay。\n${_parseErrorMessage(e.toString())}';
      });
    }
  }

  Future<void> _pollQrLoginResult() async {
    final session = _qrSession;
    if (session == null || _isLoading) return;

    try {
      final status = await QrLoginService.instance.getStatus(session);
      if (!mounted) return;

      if (status.status == 'authorized') {
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

      if (status.status == 'expired') {
        _qrPollTimer?.cancel();
        setState(() => _qrError = '二维码已过期，请重新生成');
        return;
      }

      if (status.message != null && status.message!.isNotEmpty) {
        setState(() => _qrError = status.message);
      }
    } catch (_) {
      // 轮询失败不立刻打断二维码，避免短暂网络抖动导致界面频繁报错。
    }
  }

  Future<void> _completeQrLogin(QrLoginTokenPayload payload) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await ServerService.instance.updateCurrentServerLogin(
        user: payload.user,
      );

      authProvider.setUser(payload.user);
      authProvider.setState(AuthState.authenticated);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _focusNode.unfocus();
      ToastHelper.success('扫码登录成功');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pushReplacementNamed(RouteNames.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _qrError = _parseErrorMessage(e.toString());
      });
      ToastHelper.failure(_qrError ?? '扫码登录失败');
    }
  }

  String _parseErrorMessage(String error) {
    if (error.startsWith('Exception(') || error.startsWith('AppException(')) {
      final startIdx = error.indexOf('(');
      final endIdx = error.lastIndexOf(')');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        return error.substring(startIdx + 1, endIdx).trim();
      }
    }
    if (error.contains(':')) {
      final parts = error.split(':');
      if (parts.length > 1) {
        final msg = parts.sublist(1).join(':').trim();
        if (msg.isNotEmpty) return '登录失败: $msg';
      }
    }
    if (error.contains('"') && error.split('"').length >= 2) {
      final parts = error.split('"');
      if (parts.length >= 2) {
        final msg = parts[1].trim();
        if (msg.isNotEmpty && msg != 'login') return '登录失败: $msg';
      }
    }
    return error.isEmpty ? '登录失败: 未知原因' : '登录失败: $error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoBack = Navigator.of(context).canPop();

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
                            constraints: BoxConstraints(minHeight: viewport.maxHeight),
                            child: _buildLoginShell(theme, compact: true),
                          ),
                        )
                      : _buildLoginShell(theme, compact: false),
                ),
                if (canGoBack)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: '返回',
                        icon: const Icon(LucideIcons.arrowLeft),
                        onPressed: _isLoading
                            ? null
                            : () {
                                _focusNode.unfocus();
                                Navigator.of(context).pop();
                              },
                      ),
                    ),
                  ),
                if (Platform.isWindows || Platform.isLinux)
                  const Positioned(
                    left: 0,
                    right: 132,
                    top: 0,
                    height: 58,
                    child: DragToMoveArea(child: SizedBox.expand()),
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
    final siteName = _siteName ??
        (server?.label.trim().isNotEmpty == true ? server!.label.trim() : 'Cloudreve');
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
        final brandScale = math.min(
          availableWidth / designWidth,
          availableHeight / designHeight,
        ).clamp(0.62, 1.0).toDouble();
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
                child: RepaintBoundary(
                  child: _buildSiteLogo(size: logoSize),
                ),
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
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 620.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (compact ? 640.0 : 720.0);
        final widthScale = compact
            ? 1.0
            : (availableWidth / 620.0).clamp(0.88, 1.12).toDouble();
        final topSafePadding = compact ? 0.0 : 42.0;
        final availableContentHeight = compact
            ? availableHeight
            : (availableHeight - topSafePadding - 18.0).clamp(300.0, availableHeight).toDouble();
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
            : (availableContentHeight / modeDesignHeight).clamp(0.52, 1.10).toDouble();
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _ServerSelector(
                      onTap: _showServerSelector,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ManageServersButton(
                    onTap: _showServerManagement,
                  ),
                ],
              ),
              SizedBox(height: compact ? 22 : (22.0 * panelScale).clamp(16.0, 24.0).toDouble()),
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
                    _LoginMode.qr => _buildQrLoginPanel(theme, scale: panelScale),
                    _LoginMode.password => _buildPasswordLoginPanel(theme, scale: panelScale),
                    _LoginMode.forgot => _buildForgotPasswordPanel(theme, scale: panelScale),
                    _LoginMode.register => _buildRegisterPanel(theme, scale: panelScale),
                  },
                ),
              ),
              ],
            ),
          ),
        );

        final child = compact
            ? ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (availableHeight - verticalPadding * 2).clamp(0.0, double.infinity),
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
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFE8CAD5)),
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
          child: Text(
            _qrStatusText(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: statusColor,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: _gap(12, scale, min: 4)),
        FilledButton.icon(
          onPressed: _isQrLoading ? null : _startQrLogin,
          style: FilledButton.styleFrom(
            minimumSize: Size(double.infinity, _buttonHeight(46, scale, min: 38)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFFA95775),
          ),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: Text(session == null ? '生成二维码' : '重新生成二维码'),
        ),
        SizedBox(height: _gap(12, scale, min: 6)),
        OutlinedButton.icon(
          onPressed: () => _switchLoginMode(_LoginMode.password),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, _buttonHeight(44, scale, min: 36)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              onPressed: _isLoading ? null : () => _switchLoginMode(_LoginMode.password),
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
        _parseErrorMessage(message),
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
          _buildPanelBackButton(
            '找回密码',
            '输入账号邮箱后，我们会把重置链接发送到你的邮箱。',
          ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              onPressed: _isLoading ? null : () => _switchLoginMode(_LoginMode.password),
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
          _buildPanelBackButton(
            '注册账号',
            '创建新账号后即可在当前页面继续登录。',
          ),
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
                  _obscureRegisterPassword ? LucideIcons.eye : LucideIcons.eyeOff,
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
              if (value == null || value.isEmpty) return '请确认密码';
              if (value != _registerPasswordController.text) return '两次输入的密码不一致';
              return null;
            },
            decoration: InputDecoration(
              labelText: '确认密码',
              hintText: '请再次输入密码',
              prefixIcon: const Icon(LucideIcons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterConfirmPassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureRegisterConfirmPassword = !_obscureRegisterConfirmPassword,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              onPressed: _isLoading ? null : () => _switchLoginMode(_LoginMode.password),
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

    if (_registerPasswordController.text != _registerConfirmPasswordController.text) {
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
    final faviconUrl = _siteLogoUrl ??
        (server == null ? null : QrLoginService.faviconUrlFromCloudreve(server.baseUrl));

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
        ..shader = ui.Gradient.radial(
          center,
          radius,
          colors,
          const [0.0, 0.56, 1.0],
        )
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
                  child: Icon(
                    widget.icon,
                    size: 17,
                    color: iconColor,
                  ),
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

  const _ServerSelector({
    required this.onTap,
  });

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
              Icon(LucideIcons.slidersHorizontal, size: 17, color: Color(0xFFA95775)),
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

class ServerSelectorSheet extends StatelessWidget {
  const ServerSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final currentServer = ServerService.instance.currentServer;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('选择服务器', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RadioGroup<String>(
              groupValue: currentServer?.label,
              onChanged: (value) async {
                if (value == null) return;
                await ServerService.instance.selectServer(value);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: servers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final isSelected = currentServer?.label == server.label;
                  return _ServerListItem(
                    server: server,
                    isSelected: isSelected,
                    onTap: () async {
                      await ServerService.instance.selectServer(server.label);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerListItem extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServerListItem({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Radio<String>(
        value: server.label,
      ),
      title: Text(
        server.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(fontSize: 12, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      tileColor:
          isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      onTap: onTap,
    );
  }
}

class ServerManagementSheet extends StatefulWidget {
  const ServerManagementSheet({super.key});

  @override
  State<ServerManagementSheet> createState() => _ServerManagementSheetState();
}

class _ServerManagementSheetState extends State<ServerManagementSheet> {
  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('管理服务器', style: theme.textTheme.titleLarge),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = servers[index];
                return _ServerManagementItem(
                  server: server,
                  onEdit: () => _showEditServerDialog(context, server),
                  onDelete: () => _showDeleteConfirmDialog(context, server),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddServerDialog(context),
              icon: const Icon(LucideIcons.plus),
              label: const Text('添加服务器'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    final labelController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                hintText: '例如: 我的服务器',
                prefixIcon: Icon(LucideIcons.tag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://example.com/api/v4',
                prefixIcon: Icon(LucideIcons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.addServer(
          ServerModel(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已添加');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('添加失败: $e');
      }
    }
  }

  Future<void> _showEditServerDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final labelController = TextEditingController(text: server.label);
    final urlController = TextEditingController(text: server.baseUrl);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                prefixIcon: Icon(LucideIcons.tag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                prefixIcon: Icon(LucideIcons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.updateServer(
          server.label,
          server.copyWith(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已更新');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('更新失败: $e');
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器 "${server.label}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.deleteServer(server.label);
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已删除');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('删除失败: $e');
      }
    }
  }
}

class _ServerManagementItem extends StatelessWidget {
  final ServerModel server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerManagementItem({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        server.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(fontSize: 12, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.pencil,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.trash2,
              size: 20,
              color: theme.colorScheme.error,
            ),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}

/// 两步验证输入对话框
class _TwoFactorDialog extends StatefulWidget {
  final String sessionId;
  final String email;
  final String password;
  final bool rememberMe;

  const _TwoFactorDialog({
    required this.sessionId,
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  @override
  State<_TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<_TwoFactorDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOut,
      ),
    );
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text.length == 6 && !_isSubmitting) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) return;

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final success = await authProvider
          .twoFactorLogin(
            otp: code,
            sessionId: widget.sessionId,
            email: widget.email,
            password: widget.password,
            rememberMe: widget.rememberMe,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('请求超时'),
          );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        _onVerifyFailed(authProvider.errorMessage ?? '验证码错误');
      }
    } catch (e) {
      if (mounted) _onVerifyFailed(_parse2FAError(e.toString()));
    }
  }

  void _onVerifyFailed(String message) {
    setState(() => _isSubmitting = false);
    _controller.clear();
    _focusNode.requestFocus();
    _shakeController.forward(from: 0);
    ToastHelper.failure(message);
  }

  String _parse2FAError(String error) {
    if (error.startsWith('Exception(') || error.startsWith('AppException(')) {
      final startIdx = error.indexOf('(');
      final endIdx = error.lastIndexOf(')');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        return error.substring(startIdx + 1, endIdx).trim();
      }
    }
    return error.isEmpty ? '验证码错误' : error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(LucideIcons.shieldCheck, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('两步验证'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '请输入身份验证器中的6位数字验证码',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              enabled: !_isSubmitting,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('验证'),
        ),
      ],
    );
  }
}
