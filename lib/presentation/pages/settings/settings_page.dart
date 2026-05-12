import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_setting_model.dart';
import '../../../services/user_setting_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';
import 'profile_edit_page.dart';
import 'security_settings_page.dart';
import 'file_preferences_page.dart';
import 'app_settings_page.dart';
import 'credit_history_page.dart';
import 'quick_access_settings_page.dart';

/// 设置主页
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserSettingProvider>().loadAll();
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await context.read<UserSettingProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final settingProvider = context.watch<UserSettingProvider>();
    final settings = settingProvider.settings;
    final capacity = settingProvider.capacity;
    final isLoading = settingProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
              tooltip: '刷新',
            ),
        ],
      ),
      body: DesktopConstrained(
        child: ListView(
        children: [
          _buildProfileCard(context, user, settings, capacity),
          const SizedBox(height: 8),
          _buildSection(
            title: '账户与安全',
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: '个人资料',
                subtitle: '修改昵称、头像',
                onTap: () => _navigateTo(context, const ProfileEditPage()),
              ),
              _SettingsTile(
                icon: Icons.security_outlined,
                title: '安全设置',
                subtitle: _securitySubtitle(settings),
                onTap: () => _navigateTo(context, const SecuritySettingsPage()),
              ),
            ],
          ),
          _buildSection(
            title: '偏好',
            children: [
              _SettingsTile(
                icon: Icons.apps_outlined,
                title: '快捷入口',
                subtitle: '自定义概览页快捷目录',
                onTap: () => _navigateTo(context, const QuickAccessSettingsPage()),
              ),
              _SettingsTile(
                icon: Icons.folder_outlined,
                title: '文件偏好',
                subtitle: '版本保留、视图同步、分享可见性',
                onTap: () => _navigateTo(context, const FilePreferencesPage()),
              ),
              _SettingsTile(
                icon: Icons.tune,
                title: '应用设置',
                subtitle: '缓存、主题、语言',
                onTap: () => _navigateTo(context, const AppSettingsPage()),
              ),
            ],
          ),
          // Pro 功能区域（有数据时才显示）
          if (settings != null) ..._buildProSections(context, settings),
          _buildSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('应用名称'),
                subtitle: const Text('Cloudreve V4.0'),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('版本号'),
                subtitle: Text(_appVersion.isEmpty ? '加载中...' : _appVersion),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('GitHub'),
                subtitle: const Text('LimoYuan/cloudreve4_flutter'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/LimoYuan/cloudreve4_flutter'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLogoutButton(context, auth),
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  /// Pro 功能区域（存储包、积分、会员）
  List<Widget> _buildProSections(BuildContext context, UserSettingModel settings) {
    final sections = <Widget>[];
    final hasStoragePacks = settings.storagePacks.isNotEmpty;
    final hasCredit = settings.credit > 0;
    final hasMembership = settings.groupExpires != null;

    if (hasStoragePacks || hasCredit || hasMembership) {
      final children = <Widget>[];
      if (hasMembership) {
        children.add(ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('会员'),
          subtitle: Text('到期: ${_formatDate(settings.groupExpires!)}'),
          trailing: TextButton(
            onPressed: () => _cancelMembership(context),
            child: const Text('取消会员', style: TextStyle(color: Colors.red)),
          ),
        ));
      }
      if (hasStoragePacks) {
        children.add(ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text('存储包 (${settings.storagePacks.length})'),
          subtitle: Text(_storagePackSummary(settings.storagePacks)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showStoragePacks(context, settings.storagePacks),
        ));
      }
      if (hasCredit) {
        children.add(ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('积分'),
          subtitle: Text('${settings.credit} 积分'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateTo(context, CreditHistoryPage(currentCredit: settings.credit)),
        ));
      }
      sections.add(_buildSection(title: 'Pro 功能', children: children));
    }
    return sections;
  }

  Widget _buildProfileCard(BuildContext context, UserModel? user, UserSettingModel? settings, UserCapacityModel? capacity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateTo(context, const ProfileEditPage()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _buildAvatar(context, user, 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname ?? '未登录',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (user?.group != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user!.group!.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (capacity != null) ...[
                const SizedBox(height: 16),
                _buildStorageBar(context, capacity),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserModel? user, double size) {
    return UserAvatar(
      userId: user?.id ?? '',
      email: user?.email,
      displayName: user?.nickname ?? '用户',
      radius: size / 2,
    );
  }

  Widget _buildStorageBar(BuildContext context, UserCapacityModel capacity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usedText = _formatBytes(capacity.used);
    final totalText = _formatBytes(capacity.total);
    final percent = capacity.usagePercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('存储空间', style: theme.textTheme.bodySmall),
            Text('$usedText / $totalText', style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
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

  Widget _buildLogoutButton(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context, auth),
        icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
        label: Text('退出登录', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String _securitySubtitle(UserSettingModel? settings) {
    if (settings == null) return '';
    final items = <String>[];
    if (settings.twoFaEnabled) items.add('2FA已启用');
    if (settings.passwordless) items.add('无密码登录');
    return items.isEmpty ? '密码、2FA' : items.join('、');
  }

  // ---- 存储包 ----
  String _storagePackSummary(List<StoragePack> packs) {
    final total = packs.fold<int>(0, (sum, p) => sum + p.size);
    return '共 ${_formatBytes(total)} · ${packs.length} 个存储包';
  }

  void _showStoragePacks(BuildContext context, List<StoragePack> packs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('存储包', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...packs.map((pack) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(pack.name, style: Theme.of(ctx).textTheme.titleSmall),
                        Text(_formatBytes(pack.size), style: Theme.of(ctx).textTheme.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '激活: ${_formatDate(pack.activeSince)}'
                      '${pack.expireAt != null ? " · 到期: ${_formatDate(pack.expireAt!)}" : " · 永久"}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    if (pack.isExpired) ...[
                      const SizedBox(height: 4),
                      Text('已过期', style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---- 取消会员 ----
  Future<void> _cancelMembership(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消会员'),
        content: const Text('确定要取消当前会员吗？取消后将失去会员权益。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await UserSettingService.instance.updateUserSetting(groupExpires: true);
      if (!context.mounted) return;
      await context.read<UserSettingProvider>().loadSettings();
      if (mounted) ToastHelper.success('会员已取消');
    } catch (e) {
      if (mounted) ToastHelper.failure('取消会员失败: $e');
    }
  }

  Future<void> _navigateTo(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!context.mounted) return;
    if (mounted) {
      context.read<UserSettingProvider>().loadAll();
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await auth.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
