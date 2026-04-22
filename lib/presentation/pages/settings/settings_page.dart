import 'package:flutter/material.dart';
import '../../../data/models/cache_settings_model.dart';
import '../../../services/cache_manager_service.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  CacheSettingsModel _settings = CacheSettingsModel();
  bool _isLoading = true;
  int? _currentCacheSize;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = CacheManagerService.instance;
    await service.initialize();
    final settings = service.settings;
    final cacheSize = await service.getCacheSize();

    if (mounted) {
      setState(() {
        _settings = settings;
        _currentCacheSize = cacheSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final service = CacheManagerService.instance;
    await service.saveSettings(_settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isCleaning = true;
      });

      try {
        final service = CacheManagerService.instance;
        await service.clearCache();
        final newCacheSize = await service.getCacheSize();

        if (mounted) {
          setState(() {
            _currentCacheSize = newCacheSize;
            _isCleaning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('缓存已清空')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCleaning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空缓存失败: $e')),
          );
        }
      }
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '未知';
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: '刷新',
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildCacheSection(context),
          _buildCacheInfoSection(context),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildCacheSection(BuildContext context) {
    return _buildSection(
      title: '缓存设置',
      children: [
        ListTile(
          title: const Text('最大缓存大小'),
          subtitle: Text(_settings.maxCacheSizeReadable),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showMaxCacheSizeDialog(context),
        ),
        ListTile(
          title: const Text('缓存过期时间'),
          subtitle: Text(_settings.cacheExpireDurationReadable),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCacheExpireDurationDialog(context),
        ),
        SwitchListTile(
          title: const Text('自动清理最旧文件'),
          subtitle: const Text('当超过最大缓存大小时自动清理'),
          value: _settings.autoCleanOldFiles,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(autoCleanOldFiles: value);
            });
            _saveSettings();
          },
        ),
      ],
    );
  }

  Widget _buildCacheInfoSection(BuildContext context) {
    return _buildSection(
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
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      title: '关于',
      children: [
        const ListTile(
          title: Text('应用名称'),
          subtitle: Text('Cloudreve V4.0'),
        ),
        const ListTile(
          title: Text('版本号'),
          subtitle: Text('1.0.0'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Future<void> _showMaxCacheSizeDialog(BuildContext context) async {
    final availableSizes = CacheSettingsModel.availableSizes;

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择最大缓存大小',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...availableSizes.map((size) {
              final isSelected =
                  _settings.maxCacheSize == size * 1024 * 1024;
              return ListTile(
                leading: Radio<int>(
                  value: size,
                  groupValue: _settings.maxCacheSize ~/ (1024 * 1024),
                  onChanged: (_) {
                    Navigator.of(sheetContext).pop(size);
                  },
                ),
                title: Text('$size MB'),
                selected: isSelected,
                onTap: () => Navigator.of(sheetContext).pop(size),
              );
            }).toList(),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _settings = CacheSettingsModel.fromMB(selected);
      });
      _saveSettings();
    }
  }

  Future<void> _showCacheExpireDurationDialog(BuildContext context) async {
    final availableDurations = CacheSettingsModel.availableDurations;

    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择缓存过期时间',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...availableDurations.map((days) {
              final isSelected =
                  _settings.cacheExpireDuration == days * 24 * 60 * 60 * 1000;
              return ListTile(
                leading: Radio<int>(
                  value: days,
                  groupValue: _settings.cacheExpireDuration ~/
                      (24 * 60 * 60 * 1000),
                  onChanged: (_) {
                    Navigator.of(sheetContext).pop(days);
                  },
                ),
                title: Text('$days天'),
                selected: isSelected,
                onTap: () => Navigator.of(sheetContext).pop(days),
              );
            }).toList(),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _settings = CacheSettingsModel.fromDays(selected);
      });
      _saveSettings();
    }
  }
}
