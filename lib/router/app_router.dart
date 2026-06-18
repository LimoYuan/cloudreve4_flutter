import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../presentation/pages/auth/login_page.dart';
import '../presentation/pages/auth/login_page_desktop.dart';
import '../presentation/pages/shell/app_shell.dart';
import '../presentation/pages/splash/splash_page.dart';
import '../presentation/pages/shares/shares_page.dart';
import '../presentation/pages/recycle_bin/recycle_bin_page.dart';
import '../presentation/pages/webdav/webdav_page.dart';
import '../presentation/pages/remote_download/remote_download_page.dart';
import '../presentation/pages/settings/settings_page.dart';
import '../presentation/pages/profile/account_switcher_page.dart';
import '../presentation/pages/sync/sync_settings_page.dart';
import '../presentation/pages/sync/mobile_sync_entry_page.dart';
import '../presentation/pages/sync/desktop_sync_wizard_page.dart';
import '../presentation/pages/preview/image_preview_page.dart';
import '../presentation/pages/preview/pdf_preview_page.dart';
import '../presentation/pages/preview/video_preview_page.dart';
import '../presentation/pages/preview/audio_preview_page.dart';
import '../presentation/pages/preview/document_preview_page.dart';
import '../presentation/pages/preview/markdown_preview_page.dart';
import '../presentation/pages/files/category_files_page.dart';
import '../presentation/pages/share/share_link_page.dart';
import '../presentation/pages/preview/cloudreve_file_app_page.dart';
import '../presentation/pages/files/transferred_files_page.dart';
import '../services/share_link_service.dart';
import '../data/models/file_model.dart';
import '../presentation/pages/auth/qr_login_scan_page.dart';

/// 璺敱鍚嶇О
class RouteNames {
  static const String qrLoginScan = '/qr-login-scan';
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String accountSwitcher = '/account-switcher';
  static const String share = '/share';
  static const String fileDetail = '/file-detail';
  static const String recycleBin = '/recycle-bin';
  static const String webdav = '/webdav';
  static const String remoteDownload = '/remote-download';
  static const String imagePreview = '/image-preview';
  static const String pdfPreview = '/pdf-preview';
  static const String videoPreview = '/video-preview';
  static const String audioPreview = '/audio-preview';
  static const String documentPreview = '/document-preview';
  static const String markdownPreview = '/markdown-preview';
  static const String categoryFiles = '/category-files';
  static const String syncStatus = '/sync-status';
  static const String syncSettings = '/sync-settings';
  static const String desktopSyncWizard = '/desktop-sync-wizard';
  static const String shareLink = '/share-link';
  static const String cloudreveFileApp = '/cloudreve-file-app';
  static const String transferredFiles = '/transferred-files';
}

/// 搴旂敤璺敱
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.qrLoginScan:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const QrLoginScanPage(),
        );
      case RouteNames.splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );

      case RouteNames.login:
        final args = settings.arguments;
        final showBackButton = args is Map && args['showBackButton'] == true;

        return MaterialPageRoute(
          settings: settings,
          builder: (context) =>
              (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
              ? LoginDesktopPage(showBackButton: showBackButton)
              : const LoginPage(),
        );

      case RouteNames.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const AppShell(),
        );

      case RouteNames.accountSwitcher:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const AccountSwitcherPage(),
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

      case RouteNames.remoteDownload:
        final args = settings.arguments;
        String? prefillUrl;
        if (args is Map<String, dynamic>) {
          prefillUrl = args['prefillUrl'] as String?;
        } else if (args is String) {
          prefillUrl = args;
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => RemoteDownloadPage(prefillUrl: prefillUrl),
        );

      case RouteNames.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SettingsPage(),
        );

      case RouteNames.imagePreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ImagePreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => ImagePreviewPage(file: file),
        );

      case RouteNames.pdfPreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => PdfPreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => PdfPreviewPage(file: file),
        );

      case RouteNames.videoPreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => VideoPreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => VideoPreviewPage(file: file),
        );

      case RouteNames.audioPreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => AudioPreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => AudioPreviewPage(file: file),
        );

      case RouteNames.documentPreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => DocumentPreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => DocumentPreviewPage(file: file),
        );

      case RouteNames.markdownPreview:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => MarkdownPreviewPage(
              file: args['file'] as FileModel,
              entityId: args['entityId'] as String?,
            ),
          );
        }
        final file = args as FileModel;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => MarkdownPreviewPage(file: file),
        );

      case RouteNames.categoryFiles:
        final args = settings.arguments;
        if (args is CategoryFilesPageArgs) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => CategoryFilesPage(args: args),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) =>
                CategoryFilesPage(args: CategoryFilesPageArgs.fromMap(args)),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const CategoryFilesPage(
            args: CategoryFilesPageArgs(
              category: 'image',
              title: '鍥剧墖',
              icon: Icons.image,
              color: Color(0xFFF0ABFC),
            ),
          ),
        );

      case RouteNames.desktopSyncWizard:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const DesktopSyncWizardPage(),
        );

      case RouteNames.syncStatus:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const MobileSyncEntryPage(),
        );

      case RouteNames.syncSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SyncSettingsPage(),
        );

      case RouteNames.shareLink:
        final args = settings.arguments;
        if (args is ShareLinkCandidate) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ShareLinkPage(candidate: args),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );

      case RouteNames.cloudreveFileApp:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => CloudreveFileAppPage(
              file: args['file'] as FileModel,
              preferredAction: args['preferredAction'] as String?,
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );

      case RouteNames.transferredFiles:
        final args = settings.arguments;
        return MaterialPageRoute(
          settings: settings,
          builder: (context) =>
              TransferredFilesPage(initialUri: args is String ? args : null),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const SplashPage(),
        );
    }
  }
}




