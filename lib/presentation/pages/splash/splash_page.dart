import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../mkw_packager/generated/mobile_splash_config.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/mobile_startup_preload_service.dart';
import '../../../services/server_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';

/// Startup page.
///
/// Mobile behavior:
/// - If the packager selected a custom splash image, that image is shown as the
///   full-screen opening picture. The code only adds a light UI layer on top.
/// - If no custom picture exists, a simple branded fallback is shown.
///
/// Desktop behavior stays compact and does not show the mobile splash artwork.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  double _progress = 0.04;
  String _status = mkwMobileSplashLoadingText;
  String? _errorText;
  bool _initializing = false;

  bool get _useMobileSplash {
    if (kIsWeb || !mkwMobileSplashEnabled) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _hasCustomSplashImage {
    return mkwMobileSplashUseCustomImage &&
        mkwMobileSplashImageAsset.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initApp();
      }
    });
  }

  Future<void> _initApp() async {
    if (_initializing) {
      return;
    }
    _initializing = true;

    final startedAt = DateTime.now();
    final navigator = Navigator.of(context);
    final authProvider = context.read<AuthProvider>();
    final syncProvider = context.read<SyncProvider>();

    if (mounted) {
      setState(() {
        _progress = 0.04;
        _status = mkwMobileSplashLoadingText;
        _errorText = null;
      });
    }

    try {
      await _prepareMobileResources();

      await _setProgress(0.34, '正在初始化服务器');
      await ServerService.instance.init();

      final currentServer = ServerService.instance.currentServer;
      if (currentServer != null) {
        await _setApiBaseUrl(currentServer.baseUrl);
      }

      await _setProgress(0.52, '正在初始化网络服务');
      await ApiService.instance.init();

      if (!mounted) {
        return;
      }

      await _setProgress(0.70, '正在检查登录状态');
      await authProvider.init();

      if (!mounted) {
        return;
      }

      if (authProvider.isAuthenticated) {
        await _setProgress(0.86, '正在恢复同步状态');
        final token = authProvider.token;
        await syncProvider.autoResumeIfNeeded(
          currentAccessToken: token?.accessToken,
          currentRefreshToken: token?.refreshToken,
        );
      }

      await _setProgress(1.0, '加载完成，正在进入');
      await _waitForMinimumMobileDuration(startedAt);

      if (!mounted) {
        return;
      }
      navigator.pushReplacementNamed(
        authProvider.isAuthenticated ? RouteNames.home : RouteNames.login,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = 1.0;
        _status = '启动遇到问题';
        _errorText = _friendlyStartupError(error);
      });
    } finally {
      _initializing = false;
    }
  }

  Future<void> _prepareMobileResources() async {
    if (!_useMobileSplash) {
      return;
    }

    await _setProgress(0.12, _hasCustomSplashImage ? '正在加载开屏图' : '正在加载图标资源');
    if (!mounted) {
      return;
    }

    await MobileStartupPreloadService.preloadForMobile(
      context,
      preloadAllAssets: mkwMobileSplashPreloadAllAssets,
      precacheImages: mkwMobileSplashPrecacheImages,
      onProgress: (progress) {
        if (!mounted) {
          return;
        }
        final value = 0.12 + (progress.value * 0.16);
        setState(() {
          _progress = value.clamp(0.12, 0.28);
          _status = _hasCustomSplashImage ? '正在加载开屏图' : '正在加载应用资源';
        });
      },
    );

    await _setProgress(0.28, '资源加载完成');
  }

  Future<void> _setProgress(double progress, String status) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = progress.clamp(0.0, 1.0);
      _status = status;
    });
    await Future<void>.delayed(const Duration(milliseconds: 45));
  }

  Future<void> _waitForMinimumMobileDuration(DateTime startedAt) async {
    if (!_useMobileSplash || mkwMobileSplashMinMillis <= 0) {
      return;
    }

    final minimum = Duration(milliseconds: mkwMobileSplashMinMillis);
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = minimum - elapsed;
    if (!remaining.isNegative) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> _setApiBaseUrl(String baseUrl) async {
    final storageService = StorageService.instance;
    await storageService.setCustomBaseUrl(baseUrl);
  }

  String _friendlyStartupError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('network')) {
      return '网络连接异常，请检查网络后重试';
    }
    if (text.contains('server') ||
        text.contains('baseurl') ||
        text.contains('host')) {
      return '服务器配置异常，请检查服务器地址后重试';
    }
    return '应用启动失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    if (!_useMobileSplash) {
      return _DesktopStartupBody(
        status: _status,
        errorText: _errorText,
        onRetry: _initApp,
      );
    }

    return _MobileSplashBody(
      progress: _progress,
      status: _status,
      errorText: _errorText,
      hasCustomSplashImage: _hasCustomSplashImage,
      onRetry: _initApp,
    );
  }
}

class _MobileSplashBody extends StatelessWidget {
  const _MobileSplashBody({
    required this.progress,
    required this.status,
    required this.errorText,
    required this.hasCustomSplashImage,
    required this.onRetry,
  });

  final double progress;
  final String status;
  final String? errorText;
  final bool hasCustomSplashImage;
  final VoidCallback onRetry;

  bool get _hasError => errorText != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071126),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCustomSplashImage)
            const _CustomSplashImageLayer()
          else
            const _DefaultSplashLayer(),
          const _SplashToneOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                children: [
                  const Spacer(),
                  _BottomStatusPill(
                    progress: progress,
                    status: _hasError ? errorText! : status,
                    hasError: _hasError,
                    onRetry: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSplashImageLayer extends StatelessWidget {
  const _CustomSplashImageLayer();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mkwMobileSplashImageAsset,
      fit: _imageFit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => const _DefaultSplashLayer(),
    );
  }

  static BoxFit get _imageFit {
    switch (mkwMobileSplashImageFit.trim().toLowerCase()) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitwidth':
      case 'fit_width':
        return BoxFit.fitWidth;
      case 'fitheight':
      case 'fit_height':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaledown':
      case 'scale_down':
        return BoxFit.scaleDown;
      case 'cover':
      default:
        return BoxFit.cover;
    }
  }
}

class _SplashToneOverlay extends StatelessWidget {
  const _SplashToneOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.00),
            Colors.black.withValues(alpha: 0.48),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
      ),
    );
  }
}

class _DefaultSplashLayer extends StatelessWidget {
  const _DefaultSplashLayer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF071126),
            Color(0xFF0E2A4F),
            Color(0xFF0B6B8C),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Image.asset(
                  mkwMobileSplashLogoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF1E88E5),
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                mkwMobileSplashTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mkwMobileSplashSubtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomStatusPill extends StatelessWidget {
  const _BottomStatusPill({
    required this.progress,
    required this.status,
    required this.hasError,
    required this.onRetry,
  });

  final double progress;
  final String status;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: hasError ? 0.52 : 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: hasError ? _buildErrorContent() : _buildLoadingContent(),
    );
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress >= 0.98 ? null : progress.clamp(0.04, 0.98),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.94),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '重试',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopStartupBody extends StatelessWidget {
  const _DesktopStartupBody({
    required this.status,
    required this.errorText,
    required this.onRetry,
  });

  final String status;
  final String? errorText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE5485D),
                    size: 44,
                  )
                else
                  const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  hasError ? errorText! : status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
