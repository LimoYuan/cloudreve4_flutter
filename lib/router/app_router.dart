import 'package:flutter/material.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/home/home_page.dart';
import '../presentation/pages/splash/splash_page.dart';

/// 路由名称
class RouteNames {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String share = '/share';
  static const String fileDetail = '/file-detail';
}

/// 应用路由
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );

      case RouteNames.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const LoginPage(),
        );

      case RouteNames.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const HomePage(),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );
    }
  }
}
