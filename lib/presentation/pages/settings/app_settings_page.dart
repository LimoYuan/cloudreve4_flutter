import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:logger/logger.dart' show Level;
import 'package:provider/provider.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/cache_settings_model.dart';
import '../../../services/cache_manager_service.dart';
import '../../../services/desktop_system_service.dart';
import '../../../services/download_service.dart';
import '../../../services/floating_upload_service.dart';
import '../../../services/local_recent_activity_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/download_manager_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/settings/settings_shared.dart';
import '../../widgets/share_clipboard_watcher.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';
import 'log_viewer_page.dart';

/// 应用设置页（缓存、主题、语言）
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  CacheSettingsModel _cacheSettings = CacheSettingsModel();
  bool _isLoading = true;
  int? _currentCacheSize;
  bool _isCleaning = false;
  bool _wifiOnlyEnabled = false;
  int _downloadRetries = 3;
  int _taskRetentionDays = 7;
  bool _gravatarMirrorEnabled = true;
  String _gravatarMirrorUrl = 'https://weavatar.com';
  String _logFilePath = '';
  int? _logFileSize;
  String _cacheDirPath = '';
  Level _logLevel = Level.info;
  int _recentActivityLimit = LocalRecentActivityService.defaultDisplayLimit;
  bool _floatingUploadEnabled = false;
  bool _shutdownAfterUploadsEnabled = false;
  bool _launchAtStartupEnabled = false;
  bool _desktopSystemSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSettings();
    _loadWifiOnlySetting();
    _loadGravatarMirrorSetting();
    _loadLogInfo();
    _loadLogLevel();
    _loadRecentActivityLimit();
    _loadFloatingUploadSetting();
    _loadDesktopSystemSettings();
  }

  Future<void> _loadCacheSettings() async {
    try {
      final service = CacheManagerService.instance;
      await service.initialize();
      final settings = service.settings;

      if (mounted) {
        setState(() {
          _cacheSettings = settings;
          _isLoading = false;
        });
      }

      Future.delayed(const Duration(milliseconds: 100), () async {
        final cacheSize = await service.getCacheSize();
        final cacheDir = await service.getCacheDir();
        if (mounted) {
          setState(() {
            _currentCacheSize = cacheSize;
            _cacheDirPath = cacheDir.path;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCacheSettings() async {
    final service = CacheManagerService.instance;
    await service.saveSettings(_cacheSettings);
    if (mounted) ToastHelper.success('设置已保存');
  }

  Future<void> _loadLogInfo() async {
    final path = await AppLogger.logFilePath;
    final size = await AppLogger.logFileSize;
    if (mounted) {
      setState(() {
        _logFilePath = path;
        _logFileSize = size;
      });
    }
  }

  Future<void> _loadWifiOnlySetting() async {
    final enabled = await StorageService.instance
            .getBool(StorageKeys.downloadWifiOnly) ??
        false;
    final retries = await StorageService.instance
            .getInt(StorageKeys.downloadRetries) ??
        3;
    final retentionDays = await StorageService.instance
            .getInt(StorageKeys.taskRetentionDays) ??
        7;
    if (mounted) {
      setState(() {
        _wifiOnlyEnabled = enabled;
        _downloadRetries = retries;
        _taskRetentionDays = retentionDays;
      });
    }
  }

  Future<void> _loadGravatarMirrorSetting() async {
    final enabled = await StorageService.instance
            .getBool(StorageKeys.gravatarMirrorEnabled) ??
        true;
    final url = await StorageService.instance
            .getString(StorageKeys.gravatarMirrorUrl) ??
        'https://weavatar.com';
    if (mounted) {
      setState(() {
        _gravatarMirrorEnabled = enabled;
        _gravatarMirrorUrl = url;
      });
    }
  }

  Future<void> _loadLogLevel() async {
    final saved = await StorageService.instance.getString(StorageKeys.logLevel);
    if (saved != null && mounted) {
      setState(() {
        _logLevel = _parseLogLevel(saved);
      });
    }
  }

  Future<void> _loadRecentActivityLimit() async {
    final limit = await LocalRecentActivityService.instance.getDisplayLimit();
    if (mounted) setState(() => _recentActivityLimit = limit);
  }

  Future<void> _loadFloatingUploadSetting() async {
    if (!Platform.isWindows) return;
    final enabled = await FloatingUploadService.instance.isEnabled();
    if (mounted) setState(() => _floatingUploadEnabled = enabled);
  }

  Future<void> _loadDesktopSystemSettings() async {
    if (!(Platform.isWindows || Platform.isLinux)) return;
    final shutdownEnabled = await DesktopSystemService.instance.isShutdownAfterUploadsEnabled();
    final launchEnabled = await DesktopSystemService.instance.isLaunchAtStartupEnabled();
    if (mounted) {
      setState(() {
        _shutdownAfterUploadsEnabled = shutdownEnabled;
        _launchAtStartupEnabled = launchEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DesktopConstrained(
              child: ListView(
              children: [
                SettingsSection(
                  title: '外观',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('深色模式'),
                      subtitle: Text(_themeModeLabel(context)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeModeDialog(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('主题色'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: context.watch<ThemeProvider>().seedColor,
                            radius: 10,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _showThemeColorPicker(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('语言'),
                      subtitle: const Text('跟随系统'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showLanguageDialog(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Gravatar 镜像',
                  children: [
                    SwitchListTile(
                      title: const Text('启用 Gravatar 镜像'),
                      subtitle: const Text('国内网络建议启用，加速 Gravatar 头像加载'),
                      value: _gravatarMirrorEnabled,
                      onChanged: (value) async {
                        setState(() => _gravatarMirrorEnabled = value);
                        await StorageService.instance
                            .setBool(StorageKeys.gravatarMirrorEnabled, value);
                      },
                    ),
                    if (_gravatarMirrorEnabled)
                      ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: const Text('镜像地址'),
                        subtitle: Text(_gravatarMirrorUrl),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showGravatarMirrorUrlDialog(context),
                      ),
                  ],
                ),
                SettingsSection(
                  title: '下载设置',
                  children: [
                    SwitchListTile(
                      title: const Text('仅WiFi下载'),
                      subtitle: const Text('非WiFi环境下暂停下载，等待WiFi后自动恢复'),
                      value: _wifiOnlyEnabled,
                      onChanged: (value) async {
                        setState(() => _wifiOnlyEnabled = value);
                        await StorageService.instance
                            .setBool(StorageKeys.downloadWifiOnly, value);
                        if (mounted) {
                          if (!context.mounted) return;
                          context
                              .read<DownloadManagerProvider>()
                              .setWifiOnlyEnabled(value);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('重试次数'),
                      subtitle: Text(_downloadRetries == 0 ? '不重试' : '失败后自动重试 $_downloadRetries 次'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showRetriesDialog(context),
                    ),
                    ListTile(
                      title: const Text('任务记录保留'),
                      subtitle: Text(_taskRetentionDays == -1 ? '永久保留' : '保留 $_taskRetentionDays 天'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showRetentionDaysDialog(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: '概览设置',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard_customize_outlined),
                      title: const Text('最近活动每类显示条数'),
                      subtitle: Text('当前每个小类最多显示 $_recentActivityLimit 条'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showRecentActivityLimitDialog(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: '分享链接',
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.link2, color: Colors.red),
                      title: const Text('清空分享链接弹窗记录'),
                      subtitle: const Text(
                        '已忽略或已打开过的剪贴板分享链接将可以再次触发提示',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _clearShareClipboardFingerprints,
                    ),
                  ],
                ),
                if (Platform.isWindows) SettingsSection(
                  title: '桌面悬浮窗',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(LucideIcons.uploadCloud),
                      title: const Text('启用悬浮上传窗'),
                      subtitle: const Text('在桌面顶层显示蓝色拖拽上传窗，文件松开后上传到网盘根目录'),
                      value: _floatingUploadEnabled,
                      onChanged: (value) async {
                        await FloatingUploadService.instance.setEnabled(value);
                        if (mounted) setState(() => _floatingUploadEnabled = value);
                      },
                    ),
                    ListTile(
                      leading: const Icon(LucideIcons.messageSquare),
                      title: const Text('测试悬浮窗提示'),
                      subtitle: const Text('点击后在悬浮窗下方显示测试提示'),
                      onTap: () {
                        FloatingUploadService.instance.showStatus('悬浮窗测试提示');
                      },
                    ),
                    ListTile(
                      leading: const Icon(LucideIcons.image),
                      title: const Text('刷新站点图标'),
                      subtitle: const Text('重新下载当前站点 favicon 并应用到悬浮窗'),
                      onTap: () async {
                        await FloatingUploadService.instance.refreshSiteIcon();
                        if (mounted) {
                          FloatingUploadService.instance.showStatus('已刷新站点图标');
                        }
                      },
                    ),
                  ],
                ),
                if (Platform.isWindows || Platform.isLinux) SettingsSection(
                  title: '系统设置',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.power_settings_new),
                      title: const Text('上传完成后关机'),
                      subtitle: const Text('所有上传任务成功完成后，延迟 60 秒自动关机'),
                      value: _shutdownAfterUploadsEnabled,
                      onChanged: _desktopSystemSaving ? null : (value) async {
                        setState(() => _desktopSystemSaving = true);
                        try {
                          await DesktopSystemService.instance.setShutdownAfterUploadsEnabled(value);
                          if (mounted) setState(() => _shutdownAfterUploadsEnabled = value);
                        } finally {
                          if (mounted) setState(() => _desktopSystemSaving = false);
                        }
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.rocket_launch_outlined),
                      title: const Text('开机自启动'),
                      subtitle: const Text('登录系统后自动启动 Cloudreve'),
                      value: _launchAtStartupEnabled,
                      onChanged: _desktopSystemSaving ? null : (value) async {
                        setState(() => _desktopSystemSaving = true);
                        try {
                          await DesktopSystemService.instance.setLaunchAtStartupEnabled(value);
                          if (mounted) setState(() => _launchAtStartupEnabled = value);
                        } finally {
                          if (mounted) setState(() => _desktopSystemSaving = false);
                        }
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: '缓存设置',
                  children: [
                    ListTile(
                      title: const Text('最大缓存大小'),
                      subtitle: Text(_cacheSettings.maxCacheSizeReadable),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showMaxCacheSizeDialog(context),
                    ),
                    ListTile(
                      title: const Text('缓存过期时间'),
                      subtitle: Text(_cacheSettings.cacheExpireDurationReadable),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCacheExpireDurationDialog(context),
                    ),
                    SwitchListTile(
                      title: const Text('自动清理最旧文件'),
                      subtitle: const Text('当超过最大缓存大小时自动清理'),
                      value: _cacheSettings.autoCleanOldFiles,
                      onChanged: (value) {
                        setState(() {
                          _cacheSettings = _cacheSettings.copyWith(autoCleanOldFiles: value);
                        });
                        _saveCacheSettings();
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: '缓存信息',
                  children: [
                    if (_cacheDirPath.isNotEmpty)
                      ListTile(
                        title: const Text('缓存目录'),
                        subtitle: Text(
                          _cacheDirPath,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: (Platform.isWindows || Platform.isLinux)
                            ? const Icon(Icons.open_in_new, size: 18)
                            : null,
                        onTap: (Platform.isWindows || Platform.isLinux)
                            ? _openCacheDir
                            : null,
                      ),
                    ListTile(
                      title: const Text('当前缓存大小'),
                      subtitle: Text(formatBytes(_currentCacheSize)),
                    ),
                    ListTile(
                      title: const Text('清空缓存'),
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      trailing: _isCleaning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _isCleaning ? null : _clearCache,
                    ),
                  ],
                ),
                SettingsSection(
                  title: '日志管理',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('日志级别'),
                      subtitle: Text(_logLevelLabel(_logLevel)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickLogLevel(),
                    ),
                    ListTile(
                      title: const Text('日志文件路径'),
                      subtitle: Text(
                        _logFilePath,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ListTile(
                      title: const Text('日志文件大小'),
                      subtitle: Text(formatBytes(_logFileSize)),
                    ),
                    if (!Platform.isAndroid)
                      ListTile(
                        title: const Text('打开日志目录'),
                        leading: const Icon(Icons.folder_open),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openLogFolder,
                      ),
                    ListTile(
                      title: const Text('导出日志'),
                      leading: const Icon(Icons.file_download_outlined),
                      subtitle: const Text('导出到 Download 目录'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _exportLog,
                    ),
                    ListTile(
                      title: const Text('预览日志'),
                      leading: const Icon(Icons.visibility_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _previewLog,
                    ),
                    ListTile(
                      title: const Text('清空日志'),
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _clearLog,
                    ),
                  ],
                ),
              ],
              ),
            ),
    );
  }


  Future<void> _showThemeColorPicker(BuildContext context) async {
    final colors = [
      ('默认蓝', Colors.blue),
      ('靛蓝', Colors.indigo),
      ('紫色', Colors.purple),
      ('粉红', Colors.pink),
      ('红色', Colors.red),
      ('橙色', Colors.orange),
      ('琥珀', Colors.amber),
      ('绿色', Colors.green),
      ('青色', Colors.teal),
      ('青蓝', Colors.cyan),
    ];
    final currentColor = context.read<ThemeProvider>().seedColor;

    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择主题色'),
        children: colors.map((c) {
          final isSelected = currentColor.toARGB32() == c.$2.toARGB32();
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(c.$2),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: c.$2, radius: 14),
                const SizedBox(width: 12),
                Expanded(child: Text(c.$1)),
                if (isSelected)
                  Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || !mounted) return;
    if (!context.mounted) return;
    // 立即更新本地主题
    await context.read<ThemeProvider>().setSeedColor(selected);
    if (!context.mounted) return;

    // 同步到服务端
    final hex = '#${selected.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final success = await context.read<UserSettingProvider>().updatePreferredTheme(hex);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('主题色已更新');
    } else {
      ToastHelper.failure('同步主题色到服务端失败');
    }
  }

  String _themeModeLabel(BuildContext context) {
    final mode = context.watch<ThemeProvider>().themeMode;
    return switch (mode) {
      AppThemeMode.light => '浅色',
      AppThemeMode.dark => '深色',
      AppThemeMode.system => '跟随系统',
    };
  }

  Future<void> _showThemeModeDialog(BuildContext context) async {
    final currentMode = context.read<ThemeProvider>().themeMode;
    final options = [
      (AppThemeMode.system, '跟随系统', Icons.brightness_auto),
      (AppThemeMode.light, '浅色', Icons.light_mode),
      (AppThemeMode.dark, '深色', Icons.dark_mode),
    ];

    final selected = await showDialog<AppThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('深色模式'),
        children: options.map((opt) {
          final isSelected = currentMode == opt.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(opt.$1),
            child: Row(
              children: [
                Icon(opt.$3),
                const SizedBox(width: 12),
                Expanded(child: Text(opt.$2)),
                if (isSelected)
                  Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || !mounted) return;
    if (!context.mounted) return;
    await context.read<ThemeProvider>().setThemeMode(selected);
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final languages = [
      ('zh-CN', '简体中文'),
      ('zh-TW', '繁體中文'),
      ('en-US', 'English'),
      ('ja-JP', '日本語'),
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择语言'),
        children: languages.map((l) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(l.$1),
            child: Text(l.$2),
          );
        }).toList(),
      ),
    );

    if (selected == null || !mounted) return;
    if (!context.mounted) return;
    final success = await context.read<UserSettingProvider>().updateLanguage(selected);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('语言偏好已保存');
    } else {
      ToastHelper.failure('更新语言失败');
    }
  }

  Future<void> _showMaxCacheSizeDialog(BuildContext context) async {
    final availableSizes = CacheSettingsModel.availableSizes;
    final currentValue = _cacheSettings.maxCacheSize ~/ (1024 * 1024);

    final selected = await showGlassOptionDialog<int>(
      context,
      title: '最大缓存大小',
      icon: LucideIcons.hardDrive,
      options: availableSizes.map((size) => (size, '$size MB', currentValue == size)).toList(),
    );

    if (selected != null && mounted) {
      setState(() => _cacheSettings = CacheSettingsModel.fromMB(selected));
      _saveCacheSettings();
    }
  }

  Future<void> _showCacheExpireDurationDialog(BuildContext context) async {
    final availableDurations = CacheSettingsModel.availableDurations;
    final currentValue = _cacheSettings.cacheExpireDuration ~/ (24 * 60 * 60 * 1000);

    final selected = await showGlassOptionDialog<int>(
      context,
      title: '缓存过期时间',
      icon: LucideIcons.timer,
      options: availableDurations.map((days) => (days, '$days 天', currentValue == days)).toList(),
    );

    if (selected != null && mounted) {
      setState(() => _cacheSettings = CacheSettingsModel.fromDays(selected));
      _saveCacheSettings();
    }
  }

  Future<void> _showRetriesDialog(BuildContext context) async {
    final retriesOptions = [0, 1, 2, 3, 5, 10];

    final selected = await showGlassOptionDialog<int>(
      context,
      title: '重试次数',
      icon: LucideIcons.refreshCw,
      subtitle: '下载失败后自动重试的次数',
      options: retriesOptions.map((retries) =>
        (retries, retries == 0 ? '不重试' : '$retries 次', _downloadRetries == retries)).toList(),
    );

    if (selected != null && mounted) {
      setState(() => _downloadRetries = selected);
      await StorageService.instance
          .setInt(StorageKeys.downloadRetries, selected);
    }
  }

  Future<void> _showRetentionDaysDialog(BuildContext context) async {
    final options = [
      (7, '7 天'),
      (15, '15 天'),
      (30, '30 天'),
      (-1, '永久保留'),
    ];

    final selected = await showGlassOptionDialog<int>(
      context,
      title: '任务记录保留时间',
      icon: LucideIcons.clock,
      subtitle: '超过保留时间的已完成任务将被自动清理',
      options: options.map((opt) => (opt.$1, opt.$2, _taskRetentionDays == opt.$1)).toList(),
    );

    if (selected != null && mounted) {
      setState(() => _taskRetentionDays = selected);
      await StorageService.instance
          .setInt(StorageKeys.taskRetentionDays, selected);
    }
  }

  Future<void> _showRecentActivityLimitDialog(BuildContext context) async {
    final limitOptions = [3, 5, 10, 15, 20, 30];

    final selected = await showGlassOptionDialog<int>(
      context,
      title: '最近活动每类显示条数',
      icon: LucideIcons.activity,
      subtitle: '控制概览页每个最近活动小类最多展示多少条记录',
      options: limitOptions.map((n) => (n, '$n 条', _recentActivityLimit == n)).toList(),
    );

    if (selected != null && mounted) {
      await LocalRecentActivityService.instance.setDisplayLimit(selected);
      setState(() => _recentActivityLimit = selected);
    }
  }


  Future<void> _showGravatarMirrorUrlDialog(BuildContext context) async {
    final controller = TextEditingController(text: _gravatarMirrorUrl);
    final presets = [
      'https://weavatar.com',
      'https://gravatar.loli.net',
      'https://cdn.v2ex.com/gravatar',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gravatar 镜像地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '镜像地址',
                hintText: '例如: https://weavatar.com',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text('常用镜像：', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((url) => ActionChip(
                label: Text(url, style: const TextStyle(fontSize: 11)),
                onPressed: () => controller.text = url,
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (selected != null && selected.isNotEmpty && mounted) {
      var url = selected;
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      setState(() => _gravatarMirrorUrl = url);
      await StorageService.instance
          .setString(StorageKeys.gravatarMirrorUrl, url);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空所有缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCleaning = true);
      try {
        final service = CacheManagerService.instance;
        await service.clearCache();
        final newCacheSize = await service.getCacheSize();
        if (mounted) {
          setState(() {
            _currentCacheSize = newCacheSize;
            _isCleaning = false;
          });
          ToastHelper.success('缓存已清空');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCleaning = false);
          ToastHelper.failure('清空缓存失败: $e');
        }
      }
    }
  }


  Future<void> _clearShareClipboardFingerprints() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空分享链接弹窗记录'),
        content: const Text(
          '将清空"已忽略"和"已打开"两类记录。\n清理后，复制之前忽略/打开过的链接会重新触发剪贴板提示。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ShareClipboardWatcher.clearFingerprintCache();
      if (mounted) ToastHelper.success('分享链接弹窗记录已清空');
    } catch (e) {
      if (mounted) ToastHelper.failure('清空失败：$e');
    }
  }

  Future<void> _openLogFolder() async {
    try {
      final path = _logFilePath;
      if (path.isEmpty) {
        ToastHelper.error('日志文件路径未获取');
        return;
      }
      final dir = File(path).parent.path;
      final result = await OpenFile.open(dir);
      if (result.type != ResultType.done) {
        if (mounted) ToastHelper.error('无法打开目录：${result.message}');
      }
    } catch (e) {
      if (mounted) ToastHelper.error('打开目录失败：$e');
    }
  }

  Future<void> _openCacheDir() async {
    try {
      if (_cacheDirPath.isEmpty) {
        ToastHelper.error('缓存目录路径未获取');
        return;
      }
      final result = await OpenFile.open(_cacheDirPath);
      if (result.type != ResultType.done) {
        if (mounted) ToastHelper.error('无法打开目录：${result.message}');
      }
    } catch (e) {
      if (mounted) ToastHelper.error('打开目录失败：$e');
    }
  }

  Future<void> _exportLog() async {
    try {
      final dir = await DownloadService().getDownloadDirectory();
      final destPath = await AppLogger.exportLog(dir.path);
      if (destPath != null && mounted) {
        ToastHelper.success('日志已导出到：$destPath');
      } else if (mounted) {
        ToastHelper.error('导出失败：日志文件不存在');
      }
    } catch (e) {
      if (mounted) ToastHelper.error('导出日志失败：$e');
    }
  }

  Future<void> _previewLog() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogViewerPage()),
    );
  }

  Future<void> _clearLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空日志文件内容吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AppLogger.clearLog();
      await _loadLogInfo();
      if (mounted) ToastHelper.success('日志已清空');
    }
  }

  String _logLevelLabel(Level level) {
    return switch (level) {
      Level.error => 'Error — 仅错误',
      Level.warning => 'Warning — 错误 + 警告',
      Level.info => 'Info — 常规信息',
      Level.debug => 'Debug — 调试信息（含FFI交互）',
      Level.trace => 'Trace — 全量追踪',
      _ => level.name,
    };
  }

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

  Future<void> _pickLogLevel() async {
    final levels = [
      (Level.error, 'Error — 仅错误'),
      (Level.warning, 'Warning — 错误 + 警告'),
      (Level.info, 'Info — 常规信息'),
      (Level.debug, 'Debug — 调试信息（含FFI）'),
      (Level.trace, 'Trace — 全量追踪'),
    ];

    final result = await showDialog<Level>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('日志级别'),
        children: levels.map((e) {
          final isSelected = _logLevel == e.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.$1),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).hintColor,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(e.$2)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (result != null && result != _logLevel) {
      setState(() => _logLevel = result);
      AppLogger.setLevel(result);
      await StorageService.instance.setString(
        StorageKeys.logLevel,
        result.name,
      );
      if (mounted) ToastHelper.success('日志级别已切换为 ${_logLevelLabel(result)}');
    }
  }
}
