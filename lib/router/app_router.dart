import 'package:flutter/material.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/home/home_page.dart';
import '../presentation/pages/splash/splash_page.dart';
import '../presentation/pages/shares/shares_page.dart';
import '../presentation/pages/recycle_bin/recycle_bin_page.dart';
import '../presentation/pages/webdav/webdav_page.dart';
import '../presentation/pages/search/search_page.dart';
import '../presentation/pages/settings/settings_page.dart';
import '../presentation/pages/preview/image_preview_page.dart';
import '../presentation/pages/preview/pdf_preview_page.dart';
import '../presentation/pages/preview/video_preview_page.dart';
import '../presentation/pages/preview/audio_preview_page.dart';
import '../data/models/file_model.dart';

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
  static const String search = '/search';
  static const String imagePreview = '/image-preview';
  static const String pdfPreview = '/pdf-preview';
  static const String videoPreview = '/video-preview';
  static const String audioPreview = '/audio-preview';
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

      case RouteNames.search:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SearchPage(),
        );

      case RouteNames.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SettingsPage(),
        );

      case RouteNames.imagePreview:
        final file = settings.arguments as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ImagePreviewPage(file: file),
        );

      case RouteNames.pdfPreview:
        final file = settings.arguments as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => PdfPreviewPage(file: file),
        );

      case RouteNames.videoPreview:
        final file = settings.arguments as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => VideoPreviewPage(file: file),
        );

      case RouteNames.audioPreview:
        final file = settings.arguments as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => AudioPreviewPage(file: file),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );
    }
  }
}
