import 'dart:async';

import 'package:cloudreve4_flutter/data/models/login_config_model.dart';
import 'package:cloudreve4_flutter/presentation/widgets/desktop_constrained.dart';
import 'package:cloudreve4_flutter/services/captcha_service.dart';
import 'package:cloudreve4_flutter/services/qr_login_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/validators/string_validator.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/server_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';
import 'widgets/auth_server_sheets.dart';
import 'widgets/login_error_parser.dart';
import 'widgets/two_factor_dialog.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

enum _LoginMode { password, qr }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  LoginConfigModel _loginConfig = const LoginConfigModel();

  // QR login state
  _LoginMode _loginMode = _LoginMode.password;
  QrLoginSession? _qrSession;
  Timer? _qrPollTimer;
  bool _isQrLoading = false;
  String? _qrError;
  String _qrStatus = ''; // pending / authorized / expired

  // Site branding state
  String? _siteName;
  String? _siteDescription;
  Uint8List? _siteLogoBytes;

  static const double _desktopDualPanelBreakpoint = 760;

  @override
  void initState() {
    super.initState();
    _loadRememberedInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLoginConfig();
      _loadSiteBrand();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    _qrPollTimer?.cancel();
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

    try {
      final config = await AuthService.instance
          .getBasicSiteConfig()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      final title = config['title'] as String?;
      final description = config['description'] as String?;
      final favicon = config['favicon'] as String?;

      String? logoUrl;
      if (favicon != null && favicon.isNotEmpty) {
        logoUrl = favicon.startsWith('http')
            ? favicon
            : '${QrLoginService.cloudreveSiteBase(server.baseUrl)}/$favicon';
      }

      setState(() {
        _siteName = title;
        _siteDescription = description;
      });

      // Load logo bytes if URL available
      if (logoUrl != null) {
        try {
          final response = await Dio().get<List<int>>(
            logoUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (mounted && response.data != null) {
            setState(() {
              _siteLogoBytes = Uint8List.fromList(response.data!);
            });
          }
        } catch (_) {
          // Logo fetch failed, will fallback to app logo
        }
      }
    } catch (_) {
      // Site brand fetch failed, use defaults
    }
  }

  Future<void> _showServerSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ServerSelectorSheet(),
    );
    await _loadRememberedInfo();
    await _loadLoginConfig();
    await _loadSiteBrand();
  }

  Future<void> _showServerManagement() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ServerManagementSheet(),
    );
    await _loadRememberedInfo();
    await _loadLoginConfig();
    await _loadSiteBrand();
  }

  // ─── QR Login ──────────────────────────────────────────────

  Future<void> _startQrLogin() async {
    final server = ServerService.instance.currentServer;
    if (server == null) {
      ToastHelper.failure('请先选择服务器');
      return;
    }

    setState(() {
      _isQrLoading = true;
      _qrError = null;
      _qrStatus = 'pending';
    });

    _qrPollTimer?.cancel();

    try {
      final session = await QrLoginService.instance.createSession(
        cloudreveBaseUrl: server.baseUrl,
      );
      if (!mounted) return;

      setState(() {
        _qrSession = session;
        _isQrLoading = false;
        _qrStatus = 'pending';
      });

      _qrPollTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _pollQrLoginResult(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isQrLoading = false;
        _qrError = _parseQrError(e.toString());
      });
    }
  }

  Future<void> _pollQrLoginResult() async {
    final session = _qrSession;
    if (session == null) return;

    try {
      final status = await QrLoginService.instance.getStatus(session);
      if (!mounted) return;

      if (status.status == 'authorized') {
        _qrPollTimer?.cancel();
        setState(() => _qrStatus = 'authorized');
        await _completeQrLogin();
      } else if (status.status == 'expired') {
        _qrPollTimer?.cancel();
        setState(() {
          _qrStatus = 'expired';
          _qrError = '二维码已过期，请重新获取';
        });
      }
      // pending: keep polling
    } catch (e) {
      // Network error during poll, don't kill the session immediately
    }
  }

  Future<void> _completeQrLogin() async {
    final session = _qrSession;
    if (session == null) return;

    try {
      final payload = await QrLoginService.instance.getResult(session);
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Save the user from QR login result
      await ServerService.instance.updateCurrentServerLogin(
        user: payload.user,
      );

      authProvider.setUser(payload.user);
      authProvider.setState(AuthState.authenticated);

      ToastHelper.success('登录成功');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pushReplacementNamed(RouteNames.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrError = _parseQrError(e.toString());
        _qrStatus = 'expired';
      });
      ToastHelper.failure(_parseQrError(e.toString()));
    }
  }

  String _parseQrError(String error) {
    if (error.startsWith('Exception(') || error.startsWith('AppException(')) {
      final startIdx = error.indexOf('(');
      final endIdx = error.lastIndexOf(')');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        return error.substring(startIdx + 1, endIdx).trim();
      }
    }
    return error.isEmpty ? '扫码登录失败' : error;
  }

  // ─── Password Login ────────────────────────────────────────

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
    if (mounted) Navigator.of(context).pushReplacementNamed(RouteNames.home);
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopDual = screenWidth >= _desktopDualPanelBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: isDesktopDual ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ─── Desktop Dual-Panel Layout ─────────────────────────────

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Left panel: brand area
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                  theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(size: 120),
                    const SizedBox(height: 24),
                    Text(
                      _siteName ?? 'Cloudreve',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_siteDescription != null &&
                        _siteDescription!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _siteDescription!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right panel: login form
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: DesktopConstrained(
                maxContentWidth: 440,
                child: _buildLoginFormCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile Layout ─────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: DesktopConstrained(
          maxContentWidth: 480,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildLogo()),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  _siteName ?? 'Cloudreve V4.0',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (_siteDescription != null &&
                  _siteDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _siteDescription!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildLoginFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Login Form Card (shared by both layouts) ──────────────

  Widget _buildLoginFormCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ServerSelector(
              onTap: _showServerSelector,
              onManage: _showServerManagement,
            ),
            const SizedBox(height: 16),
            _buildLoginModeToggle(),
            const SizedBox(height: 16),
            if (_loginMode == _LoginMode.password)
              _buildPasswordPanel()
            else
              _buildQrLoginPanel(),
          ],
        ),
      ),
    );
  }

  // ─── Login Mode Toggle ─────────────────────────────────────

  Widget _buildLoginModeToggle() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              label: '密码登录',
              icon: LucideIcons.lock,
              selected: _loginMode == _LoginMode.password,
              onTap: () {
                _qrPollTimer?.cancel();
                setState(() => _loginMode = _LoginMode.password);
              },
            ),
          ),
          Expanded(
            child: _buildModeTab(
              label: '扫码登录',
              icon: LucideIcons.qrCode,
              selected: _loginMode == _LoginMode.qr,
              onTap: () {
                setState(() => _loginMode = _LoginMode.qr);
                if (_qrSession == null) {
                  _startQrLogin();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Password Login Panel ──────────────────────────────────

  Widget _buildPasswordPanel() {
    final captcha = CaptchaService.instance;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),
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
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            onFieldSubmitted: (_) => _login(),
          ),
          if (_loginConfig.loginCaptcha) ...[
            const SizedBox(height: 16),
            captcha.buildCaptchaInput(context),
          ],
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ForgotPasswordPage(
                        loginConfig: _loginConfig,
                      ),
                    ),
                  );
                },
                child: const Text('忘记密码？'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RegisterPage(
                        loginConfig: _loginConfig,
                      ),
                    ),
                  );
                },
                child: const Text('注册账号'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isLoading ? null : _login,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  // ─── QR Login Panel ────────────────────────────────────────

  Widget _buildQrLoginPanel() {
    final theme = Theme.of(context);

    if (_isQrLoading) {
      return const SizedBox(
        height: 280,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_qrError != null && _qrSession == null) {
      // Failed to create session
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.wifiOff,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _qrError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _startQrLogin,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_qrSession == null) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.qrCode,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                '点击获取二维码',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _startQrLogin,
                child: const Text('获取二维码'),
              ),
            ],
          ),
        ),
      );
    }

    // Show QR code
    final isExpired = _qrStatus == 'expired';
    final isAuthorized = _qrStatus == 'authorized';

    return Column(
      children: [
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: QrImageView(
                data: _qrSession!.qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            if (isExpired)
              Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.refreshCw,
                      size: 32,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '二维码已过期',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            if (isAuthorized)
              Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.check,
                      size: 40,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '扫码成功，正在登录...',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isExpired
              ? '二维码已过期'
              : isAuthorized
                  ? '扫码成功'
                  : '请使用手机 App 扫描二维码登录',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isExpired
                ? theme.colorScheme.error
                : isAuthorized
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isExpired) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _startQrLogin,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('刷新二维码'),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Logo ──────────────────────────────────────────────────

  Widget _buildLogo({double size = 96}) {
    if (_siteLogoBytes != null) {
      return ClipOval(
        child: Image.memory(
          _siteLogoBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildAppLogo(size),
        ),
      );
    }
    return _buildAppLogo(size);
  }

  Widget _buildAppLogo(double size) {
    return ClipOval(
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _ServerSelector extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onManage;

  const _ServerSelector({
    required this.onTap,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final currentServer = ServerService.instance.currentServer;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.server,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentServer?.label ?? '选择服务器',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (currentServer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      currentServer.baseUrl,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                LucideIcons.pencil,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onManage,
              tooltip: '管理服务器',
            ),
          ],
        ),
      ),
    );
  }
}

