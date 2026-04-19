import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/theme_config.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/file_manager_provider.dart';
import 'presentation/providers/upload_manager_provider.dart';
import 'presentation/providers/download_manager_provider.dart';
import 'services/upload_service.dart';
import 'services/api_service.dart';
import 'services/server_service.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务器服务
  await ServerService.instance.init();

  // 初始化API服务
  await ApiService.instance.init();

  // 设置横竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
    return
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => FileManagerProvider()),
            ChangeNotifierProvider(create: (_) => UploadService()),
            ChangeNotifierProvider(create: (_) => UploadManagerProvider()..initialize()),
            ChangeNotifierProvider(create: (_) => DownloadManagerProvider()..initialize()),
          ],
          child: const AppView(),
        );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      darkTheme: ThemeConfig.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: RouteNames.splash,
      builder: (context, child) {
        // 添加全局错误处理
        return ErrorHandler(child: child!);
      },
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
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);

            // 显示 SnackBar
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('登录已过期，请重新登录'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );

            // 跳转到登录页
            navigator.pushNamedAndRemoveUntil(
              RouteNames.login,
              (route) => false,
            );

            // 清除标志
            authProvider.clearRefreshTokenExpired();
          });
        }
        return child!;
      },
      child: child,
    );
  }
}
