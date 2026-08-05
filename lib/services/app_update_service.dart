import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../mkw_packager/generated/update_config.dart' as mkw_update;
import '../config/brand_config.dart';
import '../core/utils/app_logger.dart';

enum AppUpdateSource { mkw, github }

class AppUpdateInfo {
  final String platform;
  final String version;
  final int build;
  final String downloadUrl;
  final String title;
  final List<String> changelog;
  final bool force;
  final String? fileSize;
  final String? sha256;
  final String? packageType;
  final String? fileName;
  final String? strategy;
  /// Relative helper executable path from update.json, e.g. updater/update.exe.
  /// This is the code-level contract with the standalone update helper app.
  final String? helper;
  final AppUpdateSource updateSource;

  const AppUpdateInfo({
    required this.platform,
    required this.version,
    required this.build,
    required this.downloadUrl,
    this.title = '发现新版本',
    this.changelog = const [],
    this.force = false,
    this.fileSize,
    this.sha256,
    this.packageType,
    this.fileName,
    this.strategy,
    this.helper,
    this.updateSource = AppUpdateSource.mkw,
  });

  String get apkUrl => downloadUrl;


  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final platform = currentPlatformKey();

    final platformsJson = _asMap(json['platforms']) ?? const <String, dynamic>{};
    final platformJson = _asMap(platformsJson[platform]) ??
        _asMap(json[platform]) ??
        const <String, dynamic>{};

    final rawChangelog = _pick(
      root: json,
      platformJson: platformJson,
      platform: platform,
      keys: const ['changelog', 'changes', 'notes'],
      allowRootGeneric: true,
    );

    final url = _pickPlatformDownloadUrl(
      root: json,
      platformJson: platformJson,
      platform: platform,
    );

    return AppUpdateInfo(
      platform: platform,
      version: _pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['version', 'latest_version', 'version_name'],
        allowRootGeneric: true,
      ).toString(),
      build: _asInt(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['build', 'latest_build', 'version_code'],
        allowRootGeneric: true,
      )),
      downloadUrl: url,
      title: _pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['title'],
        fallback: '发现新版本',
        allowRootGeneric: true,
      ).toString(),
      changelog: _parseChangelog(rawChangelog),
      force: _asBool(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['force', 'force_update'],
        allowRootGeneric: true,
      )),
      fileSize: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['file_size', 'size'],
        allowRootGeneric: false,
      )),
      sha256: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['sha256'],
        allowRootGeneric: false,
      )),
      packageType: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['type', 'package_type'],
        allowRootGeneric: false,
      )),
      fileName: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['fileName', 'file_name', 'name'],
        allowRootGeneric: false,
      )),
      strategy: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['strategy', 'update_strategy'],
        allowRootGeneric: false,
      )),
      helper: _nullableString(_pick(
        root: json,
        platformJson: platformJson,
        platform: platform,
        keys: const ['helper', 'helperPath', 'helper_path'],
        allowRootGeneric: false,
      )),
    );
  }

  static String currentPlatformKey() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    return Platform.operatingSystem.toLowerCase();
  }

  static String _pickPlatformDownloadUrl({
    required Map<String, dynamic> root,
    required Map<String, dynamic> platformJson,
    required String platform,
  }) {
    final keys = platform == 'windows'
        ? const [
            'url',
            'download_url',
            'windows_url',
            'windows_download_url',
          ]
        : const [
            'url',
            'download_url',
            'apk_url',
            'android_url',
            'android_apk_url',
            'android_download_url',
          ];

    for (final key in keys) {
      final value = platformJson[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    final rootKeys = platform == 'windows'
        ? const [
            'windows_url',
            'windows_download_url',
          ]
        : const [
            'android_url',
            'android_download_url',
            'android_apk_url',
            'apk_url',
          ];

    for (final key in rootKeys) {
      final value = root[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  static dynamic _pick({
    required Map<String, dynamic> root,
    required Map<String, dynamic> platformJson,
    required String platform,
    required List<String> keys,
    dynamic fallback = '',
    bool allowRootGeneric = true,
  }) {
    for (final key in keys) {
      final value = platformJson[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }

    for (final key in keys) {
      final value = root['${platform}_$key'];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }

    if (allowRootGeneric) {
      for (final key in keys) {
        final value = root[key];
        if (value != null && value.toString().trim().isNotEmpty) return value;
      }
    }

    return fallback;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<String> _parseChangelog(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }
}

class AppUpdateCheckResult {
  final PackageInfo current;
  final AppUpdateInfo? update;
  /// 归一化后的当前版本号（优先用打包配置 mkwUpdateVersion，规避
  /// Windows PackageInfo.version 平台差异，例如 1.4.0+1 在 Windows 上被读成 1.4.0.1）。
  final String currentVersion;
  /// 归一化后的当前 build 号（优先用打包配置 mkwUpdateBuild）。
  final String currentBuild;

  const AppUpdateCheckResult({
    required this.current,
    required this.update,
    required this.currentVersion,
    required this.currentBuild,
  });

  bool get hasUpdate => update != null;
}

class AppUpdateDownloadProgress {
  final int received;
  final int total;

  const AppUpdateDownloadProgress({
    required this.received,
    required this.total,
  });

  double get progress {
    if (total <= 0) return 0;
    return (received / total).clamp(0.0, 1.0);
  }

  int get percent => (progress * 100).clamp(0, 100).round();
}

// marker: mkw_update_windows zip helper runtime v118 in-app-dialog integration
// marker: zip-helper-contract-adapter-v118-in-app-dialog
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// Navigator key used only for the in-app update confirmation dialog.
  /// The packager patches MaterialApp(navigatorKey: ...) to this key, so the
  /// update runtime can show the same Flutter-styled dialog as the main app.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String _fallbackUpdateInfoUrl = String.fromEnvironment(
    'MKW_UPDATE_INFO_URL',
    defaultValue: 'https://mkwgame.com/app/update.json',
  );

  static const MethodChannel _channel = MethodChannel('cloudreve/app_update');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: Duration.zero,
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ),
  );

  bool _checking = false;
  bool _windowsInstallScheduled = false;

  bool get isSupportedPlatform => Platform.isAndroid || Platform.isWindows;

  String get platformKey => AppUpdateInfo.currentPlatformKey();

  String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }

  String get updateInfoUrl {
    final generated = mkw_update.mkwUpdateJsonUrl.trim();

    if (generated.isNotEmpty) {
      AppLogger.i('使用打包工具写入的 update.json 地址：$generated');
      return generated;
    }

    AppLogger.w('打包工具没有写入 mkwUpdateJsonUrl，使用备用地址：$_fallbackUpdateInfoUrl');
    return _fallbackUpdateInfoUrl;
  }

  String _updateConfigContext() {
    return [
      '当前应用内置更新入口：${mkw_update.mkwUpdateJsonUrl.isEmpty ? '(空)' : mkw_update.mkwUpdateJsonUrl}',
      '当前更新模式：${mkw_update.mkwUpdateMode}',
      '当前更新域名：${mkw_update.mkwUpdateDomain.isEmpty ? '(空)' : mkw_update.mkwUpdateDomain}',
      '当前运行平台：$platformKey',
    ].join('\n');
  }

  bool _looksLikeDirectPackageUrl(String value) {
    final lower = value.toLowerCase().split('?').first;
    return lower.endsWith('.apk') || lower.endsWith('.zip');
  }

  String _expectedUpdateJsonHint() {
    final domain = mkw_update.mkwUpdateDomain.trim();
    if (domain.isNotEmpty) {
      final isIp = RegExp(r'^\d+\.\d+\.\d+\.\d+(:\d+)?$').hasMatch(domain);
      final scheme = isIp ? 'http' : 'https';
      return '$scheme://$domain/app/update.json';
    }

    return 'https://你的域名/app/update.json';
  }

  Future<AppUpdateCheckResult> _githubCheckUpdate(PackageInfo current) async {
    const owner = 'LimoYuan';
    const repo = 'cloudreve4_flutter';
    final url = 'https://api.github.com/repos/$owner/$repo/releases/latest';

    try {
      final response = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Cloudreve4-Flutter-Client',
          },
        ),
      );
      final data = _asMap(response.data);
      if (data == null) {
        AppLogger.w('GitHub 更新检查：响应不是有效的 JSON');
        return _result(current, null);
      }

      final latestTag = (data['tag_name'] ?? '').toString().trim();
      if (latestTag.isEmpty) {
        AppLogger.w('GitHub 更新检查：tag_name 为空');
        return _result(current, null);
      }

      final remoteParsed = _parseGitHubTag(latestTag);
      final localVersion = _effectiveCurrentVersion(current);
      final localBuild = _effectiveCurrentBuild(current);
      AppLogger.i(
        'GitHub 更新检查：远端 $latestTag (version=${remoteParsed.version}, build=${remoteParsed.build})，'
        '本地 $localVersion($localBuild)',
      );

      // 语义比较：远端 version 严格更高，或 version 相同但 build 严格更高才算有更新。
      // 不再用字符串严格相等比较 tag，避免 Windows PackageInfo 平台差异
      // （1.4.0+1 被读成 1.4.0.1 / buildNumber 为空）导致每次都误报有更新。
      final versionCmp = _compareVersion(remoteParsed.version, localVersion);
      final hasUpdate =
          versionCmp > 0 || (versionCmp == 0 && remoteParsed.build > localBuild);

      if (!hasUpdate) {
        AppLogger.i('GitHub 更新检查：已是最新版本');
        return _result(current, null);
      }

      final releaseUrl = (data['html_url'] ?? '').toString().trim();
      final body = (data['body'] ?? '').toString().trim();
      final changelog = body
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      AppLogger.i('GitHub 更新检查：发现新版本 $latestTag，发布页 $releaseUrl');
      return _result(
        current,
        AppUpdateInfo(
          platform: platformKey,
          version: remoteParsed.version,
          build: remoteParsed.build,
          downloadUrl: releaseUrl,
          title: '发现新版本 $latestTag',
          changelog: changelog,
          updateSource: AppUpdateSource.github,
        ),
      );
    } on DioException catch (e) {
      AppLogger.w('GitHub 更新检查失败：${e.message}');
      return _result(current, null);
    } catch (e) {
      AppLogger.w('GitHub 更新检查失败：$e');
      return _result(current, null);
    }
  }

  Future<AppUpdateCheckResult> check({bool force = false}) async {
    final current = await PackageInfo.fromPlatform();

    if (!mkw_update.mkwOnlineUpdateEnabled) {
      // 打包器未开启自动更新检查, 且包名为默认官方包名，使用 GitHub 兜底检查
      if (BrandConfig.packageName == 'com.limo.cloudreve4_flutter') {
        AppLogger.i('在线更新未启用，使用 GitHub 兜底检查');
        return _githubCheckUpdate(current);
      } else {
        AppLogger.i('在线更新未启用，跳过检查');
        return _result(current, null);
      }
    }

    if (!isSupportedPlatform) {
      return _result(current, null);
    }

    if (_checking && !force) {
      return _result(current, null);
    }

    _checking = true;
    try {
      final url = '$updateInfoUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      AppLogger.i('开始检查应用更新[$platformName/$platformKey]: $url，当前版本 ${current.version}(${current.buildNumber})，配置入口=${mkw_update.mkwUpdateJsonUrl}');

      final response = await _dio.get<dynamic>(url);
      final data = _asMap(response.data);

      if (data == null) {
        final isDirectPackage = _looksLikeDirectPackageUrl(updateInfoUrl);
        final message = [
          '更新配置解析失败：应用请求到的不是 update.json。',
          _updateConfigContext(),
          '',
          if (isDirectPackage)
            '检测到当前更新入口像是安装包直链。应用内置更新入口不能是 APK/ZIP，必须是 update.json。',
          '正确入口应该类似：${_expectedUpdateJsonHint()}',
          '',
          'update.json 里再分别写：',
          'platforms.windows.url = Windows ZIP 覆盖更新包',
          'platforms.android.url = Android apk',
          '',
          '响应类型：${response.data.runtimeType}',
        ].join('\n');

        AppLogger.w(message);
        if (force) throw Exception(message);
        return _result(current, null);
      }

      final info = AppUpdateInfo.fromJson(data);
      AppLogger.i(
        '在线更新平台选择：当前平台=$platformKey，'
        '选择字段=platforms.$platformKey.url，'
        '更新策略=${info.strategy ?? '-'}，包类型=${info.packageType ?? (Platform.isWindows ? 'zip' : 'apk')}，helper=${info.helper ?? '-'}，'
        '文件名=${info.fileName ?? '-'}，'
        '下载地址=${info.downloadUrl}',
      );

      if (info.downloadUrl.isEmpty) {
        final message = '当前平台[$platformKey]没有配置对应更新包地址';
        AppLogger.w(message);
        if (force) throw Exception(message);
        return _result(current, null);
      }

      _validateSelectedPlatformPackage(info);

      final currentVersionForCompare = _effectiveCurrentVersion(current);
      final currentBuildForCompare = _effectiveCurrentBuild(current);
      final versionCompare = _compareVersion(info.version, currentVersionForCompare);
      final hasUpdate = _isRemoteVersionStrictlyNewer(info, current);

      AppLogger.i(
        '更新检查完成[$platformName/$platformKey]：远端 ${info.version}(${info.build})，'
        '本地有效版本 $currentVersionForCompare($currentBuildForCompare)，'
        'PackageInfo=${current.version}(${current.buildNumber})，'
        '打包配置=${mkw_update.mkwUpdateVersion}(${mkw_update.mkwUpdateBuild})，'
        'versionCompare=$versionCompare，hasUpdate=$hasUpdate，url=${info.downloadUrl}',
      );

      if (!hasUpdate) {
        AppLogger.i(
          '远端版本没有高于当前版本，终止自动更新：remote=${info.version}(${info.build})，'
          'local=$currentVersionForCompare($currentBuildForCompare)',
        );
      }

      return _result(current, hasUpdate ? info : null);
    } on DioException catch (e) {
      final message = _friendlyDioUpdateError(e);
      AppLogger.e('在线更新检查失败[$platformName/$platformKey]: $message');
      if (force) throw Exception(message);
      return _result(current, null);
    } catch (e) {
      final message = '在线更新检查失败：$e';
      AppLogger.e('在线更新检查失败[$platformName/$platformKey]: $message');
      if (force) throw Exception(message);
      return _result(current, null);
    } finally {
      _checking = false;
    }
  }

  String _effectiveCurrentVersion(PackageInfo current) {
    final generated = mkw_update.mkwUpdateVersion.trim();
    if (generated.isNotEmpty) return generated;
    return current.version.trim();
  }

  int _effectiveCurrentBuild(PackageInfo current) {
    final generated = mkw_update.mkwUpdateBuild;
    if (generated > 0) return generated;
    return int.tryParse(current.buildNumber) ?? 0;
  }

  /// 统一构造 AppUpdateCheckResult，并把归一化后的当前版本/build 填进去，
  /// 调用方不再直接用 current.version/current.buildNumber（Windows 上是 1.4.0.1 / 空）。
  AppUpdateCheckResult _result(PackageInfo current, AppUpdateInfo? update) {
    return AppUpdateCheckResult(
      current: current,
      update: update,
      currentVersion: _effectiveCurrentVersion(current),
      currentBuild: _effectiveCurrentBuild(current).toString(),
    );
  }

  /// 解析 GitHub release tag 为 version 和 build。
  /// 'v1.4.0+1' -> (version: '1.4.0', build: 1)
  /// 'v1.4.0'   -> (version: '1.4.0', build: 0)
  /// '1.4.0+1'  -> (version: '1.4.0', build: 1)
  ({String version, int build}) _parseGitHubTag(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    final plusIdx = t.indexOf('+');
    if (plusIdx < 0) {
      return (version: t, build: 0);
    }
    final version = t.substring(0, plusIdx);
    final build = int.tryParse(t.substring(plusIdx + 1)) ?? 0;
    return (version: version, build: build);
  }

  bool _isRemoteVersionStrictlyNewer(AppUpdateInfo info, PackageInfo current) {
    final remoteVersion = info.version.trim();
    final localVersion = _effectiveCurrentVersion(current).trim();

    // 最终规则：只有远端版本号严格高于本地版本号才允许更新。
    // 远端版本号等于或低于本地版本号时，即使 build 更大，也必须终止，
    // 避免自动检查更新陷入“同版本反复更新”的循环。
    if (remoteVersion.isEmpty || localVersion.isEmpty) {
      AppLogger.w(
        '更新版本比较缺少版本号，拒绝自动更新以避免循环：remote=$remoteVersion local=$localVersion',
      );
      return false;
    }

    final versionCompare = _compareVersion(remoteVersion, localVersion);
    if (versionCompare <= 0) {
      return false;
    }

    return true;
  }

  Future<bool> _confirmWindowsUpdateBeforeDownload(
    AppUpdateInfo info,
    PackageInfo current,
  ) async {
    if (!Platform.isWindows) return true;

    final currentVersion = _effectiveCurrentVersion(current);
    final latestVersion = info.version.trim();
    final changelogItems = info.changelog.isEmpty
        ? const ['修复已知问题', '优化使用体验']
        : info.changelog;
    final title = info.title.trim().isEmpty ? '发现新版本' : info.title.trim();

    await _appendUpdateLaunchDebug(
      'showInAppUpdateConfirmDialog remote=${info.version} local=$currentVersion',
    );

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      await _appendUpdateLaunchDebug(
        'confirmDialogSkipped: navigator context is null; stop update to avoid closing app without user confirmation.',
      );
      AppLogger.w('没有可用的 Flutter 上下文，无法显示应用内更新确认弹窗，终止自动更新。');
      return false;
    }

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: !info.force,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.system_update_alt_rounded, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前版本：$currentVersion'),
                    const SizedBox(height: 6),
                    Text('最新版本：$latestVersion'),
                    const SizedBox(height: 14),
                    Text(
                      '更新内容',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...changelogItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: colorScheme.primary)),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '点击“现在更新”后会下载更新包，并关闭主程序；随后会启动更新小程序完成覆盖更新并重新打开主程序。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('稍后再说'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('现在更新'),
              ),
            ],
          );
        },
      );

      await _appendUpdateLaunchDebug('inAppConfirmDialogResult=${confirmed == true}');
      return confirmed == true;
    } catch (error, stack) {
      await _appendUpdateLaunchDebug('inAppConfirmDialogFailed=$error');
      await _appendUpdateLaunchDebug(stack.toString());
      AppLogger.e('应用内更新确认弹窗失败，出于安全考虑终止自动更新：$error');
      return false;
    }
  }

  String _friendlyDioUpdateError(DioException error) {
    final uri = error.requestOptions.uri.toString();
    final statusCode = error.response?.statusCode;
    final isDirectPackage = _looksLikeDirectPackageUrl(mkw_update.mkwUpdateJsonUrl);

    if (statusCode == 404) {
      return [
        '检查更新失败：update.json 地址不存在或没有公开访问（HTTP 404）。',
        '',
        _updateConfigContext(),
        '实际请求地址：$uri',
        '',
        '这一步还没有进入 Windows ZIP 更新包 / Android APK 下载；失败点是 update.json 本身访问不到。',
        '',
        if (isDirectPackage)
          '当前应用内置更新入口看起来是安装包直链。请把入口改为 update.json：${_expectedUpdateJsonHint()}',
        '请用浏览器直接打开实际请求地址，必须能看到 JSON。',
        '如果你使用自己服务器更新，请先在打包工具里填写域名并“发送到服务器”。',
        '正确结构：',
        '  /app/update.json',
        '  /app/windows/*_windows_update_*.zip',
        '  /app/android/*.apk',
      ].join('\n');
    }

    if (statusCode != null) {
      return [
        '检查更新失败：update.json 请求失败（HTTP $statusCode）。',
        '',
        _updateConfigContext(),
        '实际请求地址：$uri',
        error.message ?? '',
      ].where((e) => e.trim().isNotEmpty).join('\n');
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return [
        '检查更新失败：update.json 请求超时。',
        '',
        _updateConfigContext(),
        '实际请求地址：$uri',
        '请检查网络、代理、服务器是否可访问。',
      ].join('\n');
    }

    return [
      '检查更新失败：update.json 请求失败。',
      '',
      _updateConfigContext(),
      '实际请求地址：$uri',
      error.message ?? error.toString(),
    ].where((e) => e.trim().isNotEmpty).join('\n');
  }

  void _validateSelectedPlatformPackage(AppUpdateInfo info) {
    final lower = info.downloadUrl.toLowerCase().split('?').first;

    if (Platform.isWindows) {
      final ok = lower.endsWith('.zip');

      if (!ok) {
        throw Exception(
          [
            '检查更新配置错误：Windows 程序拿到的不是 ZIP 覆盖更新包。',
            '',
            _updateConfigContext(),
            'Windows 实际拿到的下载地址：${info.downloadUrl}',
            '',
            '最终版只允许 Windows 下载 platforms.windows.url 里的 .zip 覆盖更新包。',
            '安装器更新链路已删除，避免出现“散装包 exe”和“安装器 exe”两个更新入口混乱。',
            '正确逻辑应该是：',
            '  应用内置入口 = ${_expectedUpdateJsonHint()}',
            '  update.json 的 platforms.windows.url = Windows ZIP 覆盖更新包',
            '  update.json 的 platforms.android.url = Android apk',
            '',
            'Windows 不应该下载 APK/EXE。请重新用最终版打包工具生成 ZIP 更新包并发送到服务器。',
          ].join('\n'),
        );
      }

      return;
    }

    if (Platform.isAndroid) {
      if (!lower.endsWith('.apk')) {
        throw Exception(
          [
            '检查更新配置错误：Android 程序拿到的不是 Android APK。',
            '',
            _updateConfigContext(),
            'Android 实际拿到的下载地址：${info.downloadUrl}',
            '',
            '正确逻辑应该是：',
            '  应用内置入口 = ${_expectedUpdateJsonHint()}',
            '  update.json 的 platforms.android.url = Android apk',
            '  update.json 的 platforms.windows.url = Windows ZIP 覆盖更新包',
            '',
            'Android 不应该下载 ZIP/EXE。请重新用打包工具写入 update_config.dart，并重新打包 Android。',
          ].join('\n'),
        );
      }

      return;
    }
  }

  Future<String> downloadPackage(
    AppUpdateInfo info, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
    bool autoInstallWindows = true,
  }) async {
    if (!mkw_update.mkwOnlineUpdateEnabled) {
      AppLogger.i('在线更新已关闭，拒绝下载更新包。');
      throw Exception('在线更新功能已关闭。');
    }

    final expectedPlatform = platformKey;
    if (info.platform != expectedPlatform) {
      throw Exception('更新包平台不匹配：当前 $expectedPlatform，远端 ${info.platform}');
    }

    final current = await PackageInfo.fromPlatform();
    if (!_isRemoteVersionStrictlyNewer(info, current)) {
      final localVersion = _effectiveCurrentVersion(current);
      final localBuild = _effectiveCurrentBuild(current);
      AppLogger.i(
        '下载/安装前二次拦截：远端版本没有高于当前版本，终止更新。'
        'remote=${info.version}(${info.build}) local=$localVersion($localBuild)',
      );
      throw Exception('当前已是最新版本，无需更新。远端 ${info.version}，本地 $localVersion。');
    }

    if (Platform.isWindows && autoInstallWindows) {
      final confirmed = await _confirmWindowsUpdateBeforeDownload(info, current);
      if (!confirmed) {
        AppLogger.i('用户取消 Windows 更新，停止下载和关闭主程序。');
        throw Exception('用户已取消更新。');
      }
    }

    final dir = await getTemporaryDirectory();
    final safeVersion = info.version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final ext = _fileExtensionFromUrl(info.downloadUrl);
    final path =
        '${dir.path}${Platform.pathSeparator}mkw_update_${expectedPlatform}_${safeVersion}_${info.build}$ext';
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    await _dio.download(
      info.downloadUrl,
      path,
      options: Options(
        followRedirects: true,
        receiveTimeout: Duration.zero,
        headers: const {
          'Accept': '*/*',
          'Connection': 'close',
        },
      ),
      onReceiveProgress: (received, total) {
        onProgress?.call(
          AppUpdateDownloadProgress(received: received, total: total),
        );
      },
    );

    if (!await file.exists() || await file.length() <= 0) {
      throw Exception('更新包下载失败：${info.downloadUrl}');
    }

    if (info.sha256 != null && info.sha256!.trim().isNotEmpty) {
      final expected = info.sha256!.trim().toLowerCase();
      final actual = await _sha256OfFile(file);
      if (actual != expected) {
        throw Exception('更新包校验失败：${info.downloadUrl}');
      }
    }

    if (Platform.isWindows && autoInstallWindows) {
      AppLogger.i('Windows 更新包下载完成，自动执行安装流程：$path');
      await openDownloadedPackage(path, info: info);
    }

    return path;
  }

  Future<String> downloadAndInstallPackage(
    AppUpdateInfo info, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) {
    return downloadPackage(
      info,
      onProgress: onProgress,
      autoInstallWindows: true,
    );
  }

  Future<String> downloadApk(
    AppUpdateInfo info, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) {
    return downloadPackage(info, onProgress: onProgress);
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    final result = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
    return result ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<bool>('openInstallPermissionSettings');
  }

  Future<void> openDownloadedPackage(
    String path, {
    AppUpdateInfo? info,
  }) async {
    if (!mkw_update.mkwOnlineUpdateEnabled) {
      AppLogger.i('在线更新已关闭，拒绝打开更新包。');
      throw Exception('在线更新功能已关闭。');
    }

    if (Platform.isAndroid) {
      await installApk(path);
      return;
    }

    if (Platform.isWindows) {
      if (_windowsInstallScheduled) {
        AppLogger.i('Windows 安装流程已启动，忽略重复点击。path=$path');
        return;
      }

      _windowsInstallScheduled = true;
      await _openWindowsPackage(path, info: info);
      return;
    }

    throw Exception('当前平台不支持自动打开更新包');
  }

  Future<void> installApk(String path) async {
    if (!Platform.isAndroid) {
      throw Exception('当前平台不支持 APK 安装');
    }

    await _channel.invokeMethod<bool>('installApk', {'path': path});
  }

  Future<void> scheduleWindowsPackageInstall(
    String path, {
    required bool closeCurrentAppNow,
    AppUpdateInfo? info,
  }) async {
    if (!mkw_update.mkwOnlineUpdateEnabled) {
      AppLogger.i('在线更新已关闭，拒绝启动 Windows 更新小程序。');
      throw Exception('在线更新功能已关闭。');
    }

    if (!Platform.isWindows) {
      throw Exception('当前平台不是 Windows');
    }

    final lower = path.toLowerCase().split('?').first;
    if (!lower.endsWith('.zip')) {
      throw Exception('Windows 更新只支持 ZIP 覆盖更新包，旧安装器/EXE 更新链路已清理：$path');
    }

    await _scheduleWindowsZipHelperUpdate(path, info: info);
  }

  Future<void> _scheduleWindowsZipHelperUpdate(
    String zipPath, {
    AppUpdateInfo? info,
  }) async {
    final currentExe = Platform.resolvedExecutable;
    final currentDir = File(currentExe).parent.path;
    final processName = _basenameOfPath(currentExe);

    await _appendUpdateLaunchDebug('currentExe=$currentExe');
    await _appendUpdateLaunchDebug('currentDir=$currentDir');
    await _appendUpdateLaunchDebug('processName=$processName');
    await _appendUpdateLaunchDebug('processId=$pid');
    await _appendUpdateLaunchDebug('zipPath=$zipPath');
    await _appendUpdateLaunchDebug('updateInfo.helper=${info?.helper ?? ''}');
    await _appendUpdateLaunchDebug('updateInfo.strategy=${info?.strategy ?? ''}');

    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      await _appendUpdateLaunchDebug('ERROR zip file not found: $zipPath');
      throw Exception('下载好的 ZIP 更新包不存在：$zipPath');
    }
    await _appendUpdateLaunchDebug('zipLength=${await zipFile.length()}');

    final helperExe = await _prepareUpdateHelperRuntime(currentDir, info?.helper);
    final helperDir = helperExe.parent.path;

    final mainPid = pid;
    final args = <String>[
      '--process-name-main=$processName',
      '--process-id-main=$mainPid',
      '--target-dir-root=$currentDir',
      '--new-version-file=$zipPath',
      '--current-version=${_effectiveCurrentVersion(await PackageInfo.fromPlatform())}',
      '--latest-version=${info?.version ?? ''}',
    ];

    await _appendUpdateLaunchDebug('helperExe=${helperExe.path}');
    await _appendUpdateLaunchDebug('helperWorkingDirectory=$helperDir');
    await _appendUpdateLaunchDebug('args=${args.join(' ')}');
    AppLogger.i('启动 ZIP 更新小程序：${helperExe.path} ${args.join(' ')}');

    try {
      final process = await Process.start(
        helperExe.path,
        args,
        workingDirectory: helperDir,
        mode: ProcessStartMode.detached,
      );
      await _appendUpdateLaunchDebug('Process.start OK pid=${process.pid}');
    } catch (error, stack) {
      await _appendUpdateLaunchDebug('Process.start FAILED: $error');
      await _appendUpdateLaunchDebug(stack.toString());
      rethrow;
    }

    // Give the helper window a short head start before the main app exits.
    // The helper now waits by PID, so this delay is only for a visible handoff,
    // not for correctness.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    await _appendUpdateLaunchDebug('main app exit(0) now');
    exit(0);
  }

  Future<File> _prepareUpdateHelperRuntime(String currentDir, String? helperSpec) async {
    // Code-level adapter for D:\flutter_projects\update.
    // The helper app declares this CLI contract in update_args.dart:
    //   --process-name-main
    //   --target-dir-root
    //   --new-version-file
    //   --current-version
    //   --latest-version
    // update.json tells the main app where the helper executable lives, normally:
    //   platforms.windows.helper = "updater/update.exe"
    // We resolve that helper path, validate that it is a complete Flutter Windows
    // runtime, copy the whole runtime to %TEMP%, then launch it with the contract
    // arguments above. This keeps the helper separate while making the main app
    // dock with it by code contract rather than by a hard-coded single EXE copy.
    final candidates = _resolveUpdateHelperCandidates(currentDir, helperSpec);
    await _appendUpdateLaunchDebug('helperSpec=${helperSpec ?? ''}');
    await _appendUpdateLaunchDebug('helperCandidates=${candidates.map((e) => e.path).join(' | ')}');

    for (final candidateExe in candidates) {
      if (!await candidateExe.exists()) {
        await _appendUpdateLaunchDebug('helperCandidateMissing=${candidateExe.path}');
        continue;
      }

      final sourceDir = candidateExe.parent;
      final sourceData = Directory('${sourceDir.path}${Platform.pathSeparator}data');
      final sourceFlutterDll = File('${sourceDir.path}${Platform.pathSeparator}flutter_windows.dll');
      final hasData = await sourceData.exists();
      final hasFlutterDll = await sourceFlutterDll.exists();
      await _appendUpdateLaunchDebug('helperCandidate=${candidateExe.path}');
      await _appendUpdateLaunchDebug('helperCandidateDataExists=$hasData');
      await _appendUpdateLaunchDebug('helperCandidateFlutterDllExists=$hasFlutterDll');

      if (!hasData || !hasFlutterDll) {
        await _appendUpdateLaunchDebug(
          'helperCandidateRejected=not a complete Flutter Windows runtime: ${sourceDir.path}',
        );
        continue;
      }

      final tempRoot = await getTemporaryDirectory();
      final targetDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}mkw_update_helper_${DateTime.now().millisecondsSinceEpoch}',
      );
      await targetDir.create(recursive: true);
      await _copyDirectoryForUpdateHelper(sourceDir, targetDir);

      final targetExe = File('${targetDir.path}${Platform.pathSeparator}${_basenameOfPath(candidateExe.path)}');
      final targetData = Directory('${targetDir.path}${Platform.pathSeparator}data');
      final targetFlutterDll = File('${targetDir.path}${Platform.pathSeparator}flutter_windows.dll');
      await _appendUpdateLaunchDebug('helperSourceDir=${sourceDir.path}');
      await _appendUpdateLaunchDebug('helperTempDir=${targetDir.path}');
      await _appendUpdateLaunchDebug('helperTempExe=${targetExe.path}');
      await _appendUpdateLaunchDebug('helperTempExeExists=${await targetExe.exists()}');
      await _appendUpdateLaunchDebug('helperTempDataExists=${await targetData.exists()}');
      await _appendUpdateLaunchDebug('helperTempFlutterDllExists=${await targetFlutterDll.exists()}');

      if (!await targetExe.exists()) {
        throw Exception('复制更新小程序运行目录后没有找到入口 EXE：${targetExe.path}');
      }
      if (!await targetData.exists() || !await targetFlutterDll.exists()) {
        throw Exception('复制更新小程序运行目录不完整：${targetDir.path}');
      }
      return targetExe;
    }

    await _appendUpdateLaunchDebug('ERROR update helper not found or incomplete in $currentDir');
    throw Exception(
      '没有找到完整的 ZIP 更新小程序运行目录。请确认 update.json 的 platforms.windows.helper 指向 updater/update.exe，且更新包内包含 updater/update.exe、updater/data、updater/flutter_windows.dll。',
    );
  }

  List<File> _resolveUpdateHelperCandidates(String currentDir, String? helperSpec) {
    final result = <File>[];

    void addCandidate(String raw) {
      final normalized = raw.replaceAll('/', Platform.pathSeparator).replaceAll('\\', Platform.pathSeparator).trim();
      if (normalized.isEmpty) return;
      final isAbsolute = RegExp(r'^[a-zA-Z]:\\').hasMatch(normalized) || normalized.startsWith(Platform.pathSeparator);
      final full = isAbsolute ? normalized : '$currentDir${Platform.pathSeparator}$normalized';
      if (full.toLowerCase().endsWith('.exe')) {
        result.add(File(full));
      } else {
        result.add(File('$full${Platform.pathSeparator}update.exe'));
      }
    }

    final spec = helperSpec?.trim();
    if (spec != null && spec.isNotEmpty) {
      addCandidate(spec);
    }

    // Backward-compatible candidate names, but still require a complete Flutter runtime.
    addCandidate('updater${Platform.pathSeparator}update.exe');
    addCandidate('update_helper${Platform.pathSeparator}update.exe');

    // Dedupe while preserving order.
    final seen = <String>{};
    return result.where((file) => seen.add(file.path.toLowerCase())).toList();
  }

  Future<void> _copyDirectoryForUpdateHelper(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) continue;
      final name = segments.last;
      final targetPath = '${destination.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        await _copyDirectoryForUpdateHelper(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  Future<void> _appendUpdateLaunchDebug(String line) async {
    try {
      final tempRoot = await getTemporaryDirectory();
      final file = File('${tempRoot.path}${Platform.pathSeparator}mkw_update_launch_debug.log');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '[${DateTime.now().toIso8601String()}] $line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Debug logging must never block update.
    }
  }

  Future<void> _openWindowsPackage(String path, {AppUpdateInfo? info}) async {
    final lower = path.toLowerCase().split('?').first;

    if (lower.endsWith('.zip')) {
      await scheduleWindowsPackageInstall(
        path,
        closeCurrentAppNow: true,
        info: info,
      );
      return;
    }

    throw Exception('Windows 更新只支持 ZIP 覆盖更新包：$path');
  }

  String _basenameOfPath(String path) {
    final normalized = path.replaceAll('\\', Platform.pathSeparator).replaceAll('/', Platform.pathSeparator);
    final parts = normalized.split(Platform.pathSeparator).where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? normalized : parts.last;
  }

  String _fileExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dot = last.lastIndexOf('.');
      if (dot >= 0 && dot < last.length - 1) {
        final ext = last.substring(dot).toLowerCase();
        if (RegExp(r'^\.[a-z0-9]{2,12}$').hasMatch(ext)) {
          return ext;
        }
      }
    } catch (_) {}

    if (Platform.isWindows) return '.zip';
    if (Platform.isAndroid) return '.apk';
    return '.bin';
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }

    return null;
  }

  int _compareVersion(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;

    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }

    return 0;
  }
}
