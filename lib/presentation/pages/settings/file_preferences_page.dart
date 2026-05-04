import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_setting_model.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';

/// 文件偏好设置页
class FilePreferencesPage extends StatefulWidget {
  const FilePreferencesPage({super.key});

  @override
  State<FilePreferencesPage> createState() => _FilePreferencesPageState();
}

class _FilePreferencesPageState extends State<FilePreferencesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserSettingProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserSettingProvider>();
    final settings = provider.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('文件偏好')),
      body: DesktopConstrained(
        child: ListView(
        children: [
          _buildSection(
            title: '版本保留',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('启用版本保留'),
                subtitle: const Text('保留文件的历史版本'),
                value: settings?.versionRetentionEnabled ?? false,
                onChanged: (value) async {
                  final success = await context.read<UserSettingProvider>().updateVersionRetention(enabled: value);
                  if (!mounted) return;
                  if (!success) ToastHelper.failure('更新失败');
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_list),
                title: const Text('保留的文件类型'),
                subtitle: Text(
                  settings?.versionRetentionExt == null
                      ? '所有文件类型'
                      : (settings!.versionRetentionExt!.isEmpty
                          ? '所有文件类型'
                          : settings.versionRetentionExt!.join(', ')),
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: settings?.versionRetentionEnabled ?? false,
                onTap: () => _showExtEditor(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.numbers),
                title: const Text('最大保留版本数'),
                subtitle: Text(
                  (settings?.versionRetentionMax ?? 0) == 0
                      ? '无限制'
                      : '${settings!.versionRetentionMax} 个版本',
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: settings?.versionRetentionEnabled ?? false,
                onTap: () => _showMaxVersionsDialog(context, settings),
              ),
            ],
          ),
          _buildSection(
            title: '视图与同步',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.sync_disabled),
                title: const Text('禁用视图同步'),
                subtitle: const Text('关闭后视图设置不会跨设备同步'),
                value: settings?.disableViewSync ?? false,
                onChanged: (value) async {
                  final success = await context.read<UserSettingProvider>().updateViewSync(value);
                  if (!mounted) return;
                  if (!success) ToastHelper.failure('更新失败');
                },
              ),
            ],
          ),
          _buildSection(
            title: '分享',
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('个人主页分享链接可见性'),
                subtitle: Text(_shareVisibilityLabel(settings?.shareLinksInProfile ?? '')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showShareVisibilityDialog(context, settings),
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

  String _shareVisibilityLabel(String value) {
    switch (value) {
      case 'all_share':
        return '所有分享链接';
      case 'hide_share':
        return '隐藏分享链接';
      default:
        return '仅公开分享';
    }
  }

  Future<void> _showShareVisibilityDialog(BuildContext context, UserSettingModel? settings) async {
    final currentValue = settings?.shareLinksInProfile ?? '';
    final options = [
      ('', '仅公开分享', '仅在个人主页显示公开分享'),
      ('all_share', '所有分享链接', '在个人主页显示所有分享'),
      ('hide_share', '隐藏分享链接', '不在个人主页显示任何分享'),
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('分享链接可见性'),
        children: options
            .map((opt) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(opt.$1),
                  child: Row(
                    children: [
                      Icon(
                        currentValue == opt.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(opt.$3, style: Theme.of(ctx).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );

    if (selected == null || !mounted) return;
    if (selected == currentValue) return;

    final success = await context.read<UserSettingProvider>().updateShareLinksInProfile(selected);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('已更新');
    } else {
      ToastHelper.failure('更新失败');
    }
  }

  Future<void> _showMaxVersionsDialog(BuildContext context, UserSettingModel? settings) async {
    final controller = TextEditingController(
      text: (settings?.versionRetentionMax ?? 0) == 0 ? '' : '${settings!.versionRetentionMax}',
    );
    final isUnlimited = (settings?.versionRetentionMax ?? 0) == 0;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('最大保留版本数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('无限制'),
                value: isUnlimited,
                onChanged: (v) => setDialogState(() {}),
              ),
              if (!isUnlimited)
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '版本数',
                    hintText: '输入最大保留版本数',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final unlimited = isUnlimited;
                final max = unlimited ? 0 : (int.tryParse(controller.text) ?? 0);
                Navigator.of(ctx).pop({'unlimited': unlimited, 'max': max});
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    final max = result['max'] as int;

    final success = await context.read<UserSettingProvider>().updateVersionRetention(max: max);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('已更新');
    } else {
      ToastHelper.failure('更新失败');
    }
  }

  Future<void> _showExtEditor(BuildContext context, UserSettingModel? settings) async {
    final exts = settings?.versionRetentionExt ?? [];
    final controller = TextEditingController(text: exts.join(', '));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保留的文件类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入文件扩展名，用逗号分隔。留空表示所有类型。'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '扩展名',
                hintText: '.doc, .pdf, .xlsx',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final text = controller.text.trim();
    List<String>? newExts;
    if (text.isEmpty) {
      newExts = null; // null 表示所有类型
    } else {
      newExts = text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final success = await context.read<UserSettingProvider>().updateVersionRetention(ext: newExts);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('已更新');
    } else {
      ToastHelper.failure('更新失败');
    }
  }
}
