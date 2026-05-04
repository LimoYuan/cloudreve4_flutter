import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/cache_settings_model.dart';
import '../../../services/cache_manager_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCacheSettings();
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
        if (mounted) setState(() => _currentCacheSize = cacheSize);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DesktopConstrained(
              child: ListView(
              children: [
                _buildSection(
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
                _buildSection(
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
                _buildSection(
                  title: '缓存信息',
                  children: [
                    ListTile(
                      title: const Text('当前缓存大小'),
                      subtitle: Text(_formatBytes(_currentCacheSize)),
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
              ],
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: children),
          ),
        ],
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

    // 立即更新本地主题
    await context.read<ThemeProvider>().setSeedColor(selected);

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

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择最大缓存大小', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            for (final size in availableSizes)
              ListTile(
                title: Text('$size MB'),
                selected: currentValue == size,
                leading: Icon(
                  currentValue == size ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () => Navigator.of(sheetContext).pop(size),
              ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _cacheSettings = CacheSettingsModel.fromMB(selected));
      _saveCacheSettings();
    }
  }

  Future<void> _showCacheExpireDurationDialog(BuildContext context) async {
    final availableDurations = CacheSettingsModel.availableDurations;
    final currentValue = _cacheSettings.cacheExpireDuration ~/ (24 * 60 * 60 * 1000);

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择缓存过期时间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            for (final days in availableDurations)
              ListTile(
                title: Text('$days天'),
                selected: currentValue == days,
                leading: Icon(
                  currentValue == days ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () => Navigator.of(sheetContext).pop(days),
              ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _cacheSettings = CacheSettingsModel.fromDays(selected));
      _saveCacheSettings();
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

  String _formatBytes(int? bytes) {
    if (bytes == null) return '未知';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
