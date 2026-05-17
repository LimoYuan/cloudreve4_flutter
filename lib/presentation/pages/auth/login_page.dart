import 'dart:convert';

import 'package:cloudreve4_flutter/presentation/widgets/desktop_constrained.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../core/validators/string_validator.dart';
import '../../../data/models/server_model.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/server_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'captcha_challenge_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _focusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  String? _captchaImage;
  String? _captchaTicket;
  String? _captchaType;

  String? _recaptchaSiteKey;
  String? _turnstileSiteKey;
  String? _capInstanceUrl;
  String? _capSiteKey;
  String? _capAssetServer;

  String? _captchaToken;
  bool _isLoadingCaptcha = false;

  bool get _isWebCaptcha => _captchaWebConfig != null;

  CaptchaWebConfig? get _captchaWebConfig {
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

  @override
  void initState() {
    super.initState();
    _loadRememberedInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCaptcha();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
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

  Future<void> _loadCaptcha() async {
    if (_isLoadingCaptcha) return;

    final server = ServerService.instance.currentServer;
    if (server == null) {
      return;
    }

    setState(() {
      _isLoadingCaptcha = true;
    });

    try {
      await ApiService.instance.setBaseUrl(server.baseUrl);

      Map<String, dynamic> config = <String, dynamic>{};

      try {
        config = await AuthService.instance
            .getBasicSiteConfig()
            .timeout(const Duration(seconds: 10));

        debugPrint('[LoginPage] basic site config: $config');
      } catch (e) {
        debugPrint('[LoginPage] getBasicSiteConfig failed: $e');
      }

      final captchaType = _normalizeCaptchaType(
        (config['captcha_type'] ??
                config['captchaType'] ??
                config['captcha'])
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

      debugPrint(
        '[LoginPage] captchaType=$captchaType, '
        'recaptchaKey=$recaptchaKey, '
        'turnstileSiteKey=$turnstileSiteKey, '
        'capInstanceUrl=$capInstanceUrl, '
        'capSiteKey=$capSiteKey, '
        'capAssetServer=$capAssetServer',
      );

      if (!mounted) return;

      final isExternalCaptcha = captchaType == 'turnstile' ||
          captchaType == 'recaptcha' ||
          captchaType == 'cap';

      if (isExternalCaptcha) {
        setState(() {
          _captchaType = captchaType;
          _recaptchaSiteKey = recaptchaKey;
          _turnstileSiteKey = turnstileSiteKey;
          _capInstanceUrl = capInstanceUrl;
          _capSiteKey = capSiteKey;
          _capAssetServer = capAssetServer;
          _captchaToken = null;

          _captchaImage = null;
          _captchaTicket = null;
          _captchaController.clear();
        });
        return;
      }

      final captcha = await AuthService.instance.getCaptcha();

      if (!mounted) return;

      setState(() {
        _captchaType = captchaType.isEmpty ? 'normal' : captchaType;
        _recaptchaSiteKey = null;
        _turnstileSiteKey = null;
        _capInstanceUrl = null;
        _capSiteKey = null;
        _capAssetServer = null;
        _captchaToken = null;

        _captchaImage = captcha['image'];
        _captchaTicket = captcha['ticket'];
        _captchaController.clear();
      });
    } catch (e) {
      debugPrint('[LoginPage] _loadCaptcha failed: $e');

      if (!mounted) return;

      setState(() {
        _captchaType = null;
        _recaptchaSiteKey = null;
        _turnstileSiteKey = null;
        _capInstanceUrl = null;
        _capSiteKey = null;
        _capAssetServer = null;
        _captchaToken = null;

        _captchaImage = null;
        _captchaTicket = null;
        _captchaController.clear();
      });

      ToastHelper.failure('验证码加载失败');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCaptcha = false;
        });
      }
    }
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

  Future<void> _openCaptchaChallenge() async {
    final server = ServerService.instance.currentServer;
    final config = _captchaWebConfig;

    if (server == null || config == null) {
      ToastHelper.failure('验证码配置无效');
      return;
    }

    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CaptchaChallengePage(
          config: config,
          baseUrl: server.baseUrl,
        ),
      ),
    );

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      setState(() {
        _captchaToken = token;
      });

      ToastHelper.success('人机验证完成');
    }
  }

  Future<void> _showServerSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ServerSelectorSheet(),
    );
    await _loadRememberedInfo();
    await _loadCaptcha();
  }

  Future<void> _showServerManagement() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ServerManagementSheet(),
    );
    await _loadRememberedInfo();
    await _loadCaptcha();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isWebCaptcha &&
        (_captchaToken == null || _captchaToken!.isEmpty)) {
      ToastHelper.failure('请先完成人机验证');
      return;
    }

    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final success = await authProvider
          .passwordLogin(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            rememberMe: _rememberMe,
            // 普通图形验证码：captcha=用户输入，ticket=/site/captcha 返回的 ticket。
            // reCAPTCHA / Turnstile / Cap：浏览器组件返回 token。
            // Cloudreve V4 登录接口只有 captcha/ticket 两个字段；不同验证码实现
            // 可能读取不同字段，因此外部验证码 token 同时放入 captcha 和 ticket。
            captcha: _isWebCaptcha
                ? _captchaToken
                : _captchaController.text.trim(),
            ticket: _isWebCaptcha ? _captchaToken : _captchaTicket,
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
        await _loadCaptcha();

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
        await _loadCaptcha();

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

  Widget _buildCaptchaInput() {
    if (_isWebCaptcha) {
      final config = _captchaWebConfig;
      final displayName = config?.displayName ?? '人机验证';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _isLoadingCaptcha ? null : _openCaptchaChallenge,
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
            '当前验证码类型：$displayName',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
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
            controller: _captchaController,
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
            onFieldSubmitted: (_) => _login(),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _isLoadingCaptcha ? null : _loadCaptcha,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      'Cloudreve V4.0',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ServerSelector(
                              onTap: _showServerSelector,
                              onManage: _showServerManagement,
                            ),
                            const SizedBox(height: 16),
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
                              onFieldSubmitted: (_) =>
                                  _focusNode.requestFocus(),
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
                                    _obscurePassword
                                        ? LucideIcons.eye
                                        : LucideIcons.eyeOff,
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
                            const SizedBox(height: 16),
                            _buildCaptchaInput(),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
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
                                        builder: (context) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('忘记密码？'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterPage(),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('登录'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ClipOval(
      child: Image.asset(
        'assets/images/app_logo.png',
        width: 96,
        height: 96,
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

class ServerSelectorSheet extends StatelessWidget {
  const ServerSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final currentServer = ServerService.instance.currentServer;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.all(16),
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
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(16),
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