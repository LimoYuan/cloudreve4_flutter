import 'package:flutter/material.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/home/home_page.dart';
import '../presentation/pages/splash/splash_page.dart';
import '../presentation/pages/shares/shares_page.dart';
import '../presentation/pages/recycle_bin/recycle_bin_page.dart';
import '../presentation/pages/webdav/webdav_page.dart';

/// 路由名称
class RouteNames {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String share = '/share';
  static const String fileDetail = '/file-detail';
  static const String recycleBin = '/recycle-bin';
  static const String webdav = '/webdav';
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

      case RouteNames.share:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SharesPage(),
        );

      case RouteNames.recycleBin:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const RecycleBinPage(),
        );

      case RouteNames.webdav:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const WebdavPage(),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );
    }
  }
}
