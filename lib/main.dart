import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:logger/logger.dart' show Level;
import 'package:cloudreve4_flutter/presentation/widgets/desktop_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:oktoast/oktoast.dart';
import 'package:window_manager/window_manager.dart';
import 'config/app_config.dart';
import 'core/constants/storage_keys.dart';
import 'services/storage_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/file_manager_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/upload_manager_provider.dart';
import 'presentation/providers/download_manager_provider.dart';
import 'presentation/providers/user_setting_provider.dart';
import 'presentation/providers/admin_provider.dart';
import 'presentation/providers/quick_access_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'services/upload_service.dart';
import 'services/upload_foreground_service.dart';
import 'services/android_compat_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/api_service.dart';
import 'services/server_service.dart';
import 'services/cache_manager_service.dart';
import 'services/avatar_cache_service.dart';
import 'core/utils/video_fullscreen.dart';
import 'services/desktop_service.dart';
import 'router/app_router.dart';
import 'presentation/widgets/toast_helper.dart';
import 'src/rust/frb_generated.dart' show RustSyncApi;

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// 全局标记：当前是否处于登录页，登录页不显示自定义标题栏
final ValueNotifier<bool> isOnLoginPage = ValueNotifier(false);

Level _parseLogLevel(String level) {
  return switch (level) {
    'error' => Level.error,
    'warning' => Level.warning,
    'info' => Level.info,
    'debug' => Level.debug,
    'trace' => Level.trace,
    _ => Level.info,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志（必须最先，否则后续任何 AppLogger 调用都会触发 fallback Logger 导致文件输出失效）
  await AppLogger.init();
  // 从持久化恢复日志级别
  final savedLevel = await StorageService.instance.getString(
    StorageKeys.logLevel,
  );
  if (savedLevel != null) {
    final level = _parseLogLevel(savedLevel);
    AppLogger.setLevel(level);
  }
  AppLogger.i("应用启动，日志系统就绪");

  UploadForegroundService.initCommunicationPort();

  // 初始化 Flutter Rust Bridge
  // 桌面端在启动时预加载同步核心；移动端按需在 SyncService 中懒加载。
  // 这样 Android 不使用同步功能时不会提前加载 libsync_core.so，
  // 也避免和同步页面里的初始化流程重复调用 FRB init。
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      await RustSyncApi.init();
      AppLogger.i("RustSyncApi 初始化成功");
    } catch (e) {
      AppLogger.e("RustSyncApi 初始化失败: $e");
      // 初始化失败不阻塞应用启动，同步功能将不可用
    }
  } else {
    AppLogger.i("移动端同步核心按需初始化，启动阶段跳过 RustSyncApi 初始化");
  }

  // 捕获 flutter_cache_manager 在 Windows 上删除缓存文件时的文件占用异常
  // 该异常是后台异步抛出的，无法通过 try-catch 拦截，需绑定错误处理器静默忽略
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('PathAccessException') || msg.contains('errno = 32')) {
      return; // Windows 文件占用，忽略
    }
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is PathAccessException) {
      return true; // 已处理，不传播
    }
    return false;
  };

  // 桌面端初始化窗口管理和系统托盘
  if (Platform.isWindows || Platform.isLinux) {
    // 实例化 FlutterSingleInstance 获取单实例句柄
    final singleInstance = FlutterSingleInstance();
    final addr = FlutterSingleInstance.address as InternetAddress;
    // 检查是否是第一个实例
    final bool isFirstInstance = await singleInstance.isFirstInstance();

    if (!isFirstInstance) {
      AppLogger.i("程序已经在运行, 尝试唤醒...");
      // 如果已经有实例在运行，通过focus回调发送消息给"第一个已启动的实例"
      // 第一个实例的 listen 会收到一个字符串
      await singleInstance.focus({"action": "bring_to_front_showWindow"});
      // 退出当前新启动的进程
      exit(0);
    }
    final String processName =
        await singleInstance.getProcessName(pid) ?? "Unknown";
    final File? pidFile = await singleInstance.getPidFile(processName);
    int port = FlutterSingleInstance.port;

    if (await pidFile!.exists()) {
      try {
        final content = await pidFile.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        port = data['port'] ?? 0;
      } catch (e) {
        AppLogger.e(
          "Get FlutterSingleInstance port has error: ${e.toString()}",
        );
      }
    }

    AppLogger.i(
      "processName: $processName \npid: $pid \npidFile: ${pidFile.path.toString()} \nSingleInstance RPC address:port: ${addr.address}:$port",
    );

    FlutterSingleInstance.onFocus = (metadata) async {
      AppLogger.i("收到唤醒信号: $metadata");
      await DesktopService.instance.showWindow();
    };

    await DesktopService.instance.initialize();
  }

  // 初始化MediaKit
  MediaKit.ensureInitialized();

  // 初始化服务器服务
  await ServerService.instance.init();

  // 初始化API服务
  await ApiService.instance.init();

  // 初始化缓存管理器
  await CacheManagerService.instance.initialize();

  // 初始化头像缓存服务
  await AvatarCacheService.instance.init();

  // Android 13+：请求通知权限，避免上传/下载进度通知无法显示。
  await AndroidCompatService.initialize();

  // 初始化上传前台服务配置（Android 后台上传通知）。
  await UploadForegroundService.initialize();

  // Android 15+ targetSdk 35/36 会默认 Edge-to-edge；这里显式开启，
  // 并由各 Scaffold / SafeArea 处理系统栏避让。
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // 设置横竖屏方向（仅移动端）
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const CloudreveApp());
}

class CloudreveApp extends StatelessWidget {
  const CloudreveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => FileManagerProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => UploadService()),
        ChangeNotifierProvider(
          create: (_) => UploadManagerProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadManagerProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => UserSettingProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => QuickAccessProvider()..load()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: const AppView(),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final flutterThemeMode = switch (themeProvider.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return OKToast(
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: themeProvider.buildLightTheme(),
        darkTheme: themeProvider.buildDarkTheme(),
        themeMode: flutterThemeMode,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: RouteNames.splash,
        navigatorObservers: [routeObserver],
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          Widget currentWidget = child;
          if (Platform.isWindows || Platform.isLinux) {
            currentWidget = Material(
              color: themeProvider.isDark
                  ? Colors.black.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  videoFullscreenNotifier,
                  isOnLoginPage,
                ]),
                builder: (context, child) {
                  if (videoFullscreenNotifier.value || isOnLoginPage.value) {
                    return child!;
                  }
                  return Column(
                    children: [
                      const SizedBox(
                        height: 32,
                        child: DragToMoveArea(child: DesktopTitleBar()),
                      ),
                      Expanded(child: child!),
                    ],
                  );
                },
                child: currentWidget,
              ),
            );
            // 添加全局错误处理
            currentWidget = FilterQualityWidget(child: currentWidget);
          }
          // 添加全局错误处理。Android 端外层包裹 WithForegroundTask，
          // 让 flutter_foreground_task 能正确接收通知点击和前台服务事件。
          final wrapped = Platform.isAndroid
              ? WithForegroundTask(child: ErrorHandler(child: currentWidget))
              : ErrorHandler(child: currentWidget);

          final overlayStyle = SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: themeProvider.isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: themeProvider.isDark
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarIconBrightness: themeProvider.isDark
                ? Brightness.light
                : Brightness.dark,
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: wrapped,
          );
        },
      ),
    );
  }
}

// 定义一个简单的包装类，确保子组件在绘制时使用高画质滤镜走抗锯齿逻辑
// ImageFiltered 会强制渲染引擎进行重绘计算，解决 Windows 上部分 UI 边缘生硬的问题
class FilterQualityWidget extends StatelessWidget {
  final Widget child;
  const FilterQualityWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      // 在 Windows 上，此滤镜能强制 Skia 引擎重新计算像素边缘
      imageFilter: ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: child,
    );
  }
}

/// 全局错误处理器
class ErrorHandler extends StatelessWidget {
  final Widget child;

  const ErrorHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 检查是否有待处理的登录过期错误
        if (authProvider.hasRefreshTokenExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final navigator = Navigator.of(context);

            ToastHelper.failure('登录已过期，请重新登录');

            navigator.pushNamedAndRemoveUntil(
              RouteNames.login,
              (route) => false,
            );

            authProvider.clearRefreshTokenExpired();
          });
        }
        return child!;
      },
      child: child,
    );
  }
}
