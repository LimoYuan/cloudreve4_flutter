import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/app_logger.dart';
import '../mkw_packager/generated/mobile_splash_config.dart';

class MobileStartupPreloadProgress {
  const MobileStartupPreloadProgress({
    required this.finished,
    required this.total,
    required this.asset,
  });

  final int finished;
  final int total;
  final String asset;

  double get value => total <= 0 ? 1 : (finished / total).clamp(0, 1);
}

/// Preloads mobile-visible assets before leaving the opening screen.
///
/// This service is intentionally tolerant: a single missing optional image must
/// not block app startup. The selected packager splash image is included when it
/// exists, but the image itself is never replaced here.
class MobileStartupPreloadService {
  MobileStartupPreloadService._();

  static bool _completed = false;

  static Future<void> preloadForMobile(
    BuildContext context, {
    bool preloadAllAssets = true,
    bool precacheImages = true,
    ValueChanged<MobileStartupPreloadProgress>? onProgress,
  }) async {
    if (_completed) {
      return;
    }

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _completed = true;
      return;
    }

    final assets = await _loadAssets();
    if (assets.isEmpty) {
      _completed = true;
      onProgress?.call(
        const MobileStartupPreloadProgress(finished: 1, total: 1, asset: ''),
      );
      return;
    }

    var finished = 0;
    for (final asset in assets) {
      if (!context.mounted) {
        return;
      }

      try {
        if (preloadAllAssets) {
          await rootBundle.load(asset);
        }

        if (!context.mounted) {
          return;
        }

        if (precacheImages && _isImageAsset(asset)) {
          await precacheImage(AssetImage(asset), context);
        }
      } catch (error) {
        AppLogger.w('移动端启动资源预加载跳过：$asset，原因：$error');
      }

      finished += 1;
      onProgress?.call(
        MobileStartupPreloadProgress(
          finished: finished,
          total: assets.length,
          asset: asset,
        ),
      );

      if (finished % 3 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    _completed = true;
  }

  static Future<List<String>> _loadAssets() async {
    final result = <String>{};

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      result.addAll(manifest.listAssets());
    } catch (error) {
      AppLogger.w('AssetManifest 读取失败，尝试 JSON fallback：$error');
      try {
        final raw = await rootBundle.loadString('AssetManifest.json');
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          result.addAll(decoded.keys);
        }
      } catch (fallbackError) {
        AppLogger.w('AssetManifest JSON fallback 失败：$fallbackError');
      }
    }

    result.addAll(const [
      mkwMobileSplashLogoAsset,
      'assets/images/app_logo.png',
      'assets/icons/tray_icon.png',
    ]);

    final splashImage = mkwMobileSplashImageAsset.trim();
    if (mkwMobileSplashEnabled &&
        mkwMobileSplashUseCustomImage &&
        splashImage.isNotEmpty) {
      result.add(splashImage);
    }

    return result
        .where((asset) => asset.trim().isNotEmpty)
        .where((asset) => !asset.endsWith('/'))
        .toList()
      ..sort();
  }

  static bool _isImageAsset(String asset) {
    final lower = asset.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}
