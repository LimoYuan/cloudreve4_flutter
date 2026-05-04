import 'dart:convert';

import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../data/models/user_setting_model.dart';
import '../../../services/user_setting_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';

/// 安全设置页
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
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
      appBar: AppBar(title: const Text('安全设置')),
      body: DesktopConstrained(
        child: ListView(
        children: [
          _buildSection(
            title: '密码',
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                subtitle: Text(settings?.passwordless == true ? '当前使用无密码登录' : '修改账户密码'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
          _buildSection(
            title: '两步验证',
            children: [
              SwitchListTile(
                secondary: Icon(
                  settings?.twoFaEnabled == true ? Icons.shield : Icons.shield_outlined,
                ),
                title: const Text('两步验证 (2FA)'),
                subtitle: Text(
                  settings?.twoFaEnabled == true ? '已启用 — 登录时需要验证码' : '未启用',
                ),
                value: settings?.twoFaEnabled ?? false,
                onChanged: (value) {
                  if (value) {
                    _showEnable2FADialog(context);
                  } else {
                    _showDisable2FADialog(context);
                  }
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Passkey',
            children: [
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text('Passkey (${settings?.passkeys.length ?? 0})'),
                subtitle: settings?.passkeys.isEmpty ?? true
                    ? const Text('未注册任何 Passkey')
                    : Text('已注册 ${settings!.passkeys.length} 个 Passkey'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPasskeyList(context, settings),
              ),
            ],
          ),
          _buildSection(
            title: '已关联账号',
            children: _buildOpenIdTiles(context, settings),
          ),
          _buildSection(
            title: '已授权应用',
            children: _buildOAuthGrantTiles(context, settings),
          ),
          if (settings?.loginActivity.isNotEmpty ?? false)
            _buildSection(
              title: '登录活动',
              children: _buildLoginActivityTiles(settings!),
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

  // ---- 修改密码 ----
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('修改密码'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: '当前密码',
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? '请输入当前密码' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入新密码';
                    if (v.length < 6) return '密码至少6个字符';
                    if (v.length > 128) return '密码不能超过128个字符';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '确认新密码'),
                  validator: (v) {
                    if (v != newCtrl.text) return '两次输入的密码不一致';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<UserSettingProvider>().changePassword(
          currentPassword: currentCtrl.text,
          newPassword: newCtrl.text,
        );
    if (!mounted) return;

    if (success) {
      ToastHelper.success('密码已修改');
    } else {
      ToastHelper.failure('修改密码失败，请检查当前密码是否正确');
    }
  }

  // ---- 启用2FA ----
  Future<void> _showEnable2FADialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    String secret = '';
    try {
      // 先获取 TOTP secret
      final secretJsonString = await context.read<UserSettingProvider>().prepare2FA();
      final Map<String, dynamic> secretMap = jsonDecode(secretJsonString!);
      secret = secretMap['data'];
    } catch (e) {
      secret = e.toString();
    }
    AppLogger.d("2FA API Response --> $secret");
    if (secret.isEmpty || !mounted) {
      ToastHelper.failure('获取2FA密钥失败');
      return;
    }

    final auth = context.read<AuthProvider>();
    final userEmail = auth.user?.email ?? 'user';
    final otpAuthUri = 'otpauth://totp/Cloudreve:$userEmail?secret=$secret&issuer=Cloudreve';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('启用两步验证'),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width >= 1000 ? MediaQuery.of(ctx).size.width * 0.4 : MediaQuery.of(ctx).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('1. 使用验证器应用扫描二维码：'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: otpAuthUri,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('或手动输入密钥：'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    textAlign: TextAlign.center,
                    secret,
                    style: const TextStyle(fontFamily: 'SourceCodePro', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('2. 输入验证器显示的6位验证码：'),
                const SizedBox(height: 8),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.length != 6) {
                ToastHelper.warning('请输入6位验证码');
                return;
              }
              Navigator.of(ctx).pop();
              final success = await context.read<UserSettingProvider>().enable2FA(code);
              if (!mounted) return;
              if (success) {
                ToastHelper.success('两步验证已启用');
              } else {
                ToastHelper.failure('启用失败，请检查验证码是否正确');
              }
            },
            child: const Text('启用'),
          ),
        ],
      ),
    );
  }

  // ---- 禁用2FA ----
  Future<void> _showDisable2FADialog(BuildContext context) async {
    final codeCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('禁用两步验证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入当前验证器显示的6位验证码以确认禁用：'),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(labelText: '验证码', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('禁用'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<UserSettingProvider>().disable2FA(codeCtrl.text.trim());
    if (!mounted) return;

    if (success) {
      ToastHelper.success('两步验证已禁用');
    } else {
      ToastHelper.failure('禁用失败，请检查验证码是否正确');
    }
  }

  // ---- Passkey 列表 ----
  void _showPasskeyList(BuildContext context, UserSettingModel? settings) {
    final passkeys = settings?.passkeys ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Passkey 管理', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (passkeys.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('暂无已注册的 Passkey', style: TextStyle(color: Colors.grey))),
              )
            else
              ...passkeys.map((pk) => ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: Text(pk.name),
                    subtitle: Text('创建于 ${_formatDate(pk.createdAt)}'
                        '${pk.usedAt != null ? ' · 最后使用 ${_formatDate(pk.usedAt!)}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deletePasskey(ctx, pk),
                    ),
                  )),
            // 注册新Passkey暂不实现，Flutter端WebAuthn支持有限
            // 后续批次实现
          ],
        ),
      ),
    );
  }

  Future<void> _deletePasskey(BuildContext context, PasskeyModel passkey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Passkey'),
        content: Text('确定要删除 "${passkey.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await UserSettingService.instance.deletePasskey(passkey.id);
      await context.read<UserSettingProvider>().loadSettings();
      if (mounted) ToastHelper.success('Passkey 已删除');
    } catch (e) {
      if (mounted) ToastHelper.failure('删除失败: $e');
    }
  }

  // ---- 已关联账号 ----
  List<Widget> _buildOpenIdTiles(BuildContext context, UserSettingModel? settings) {
    final openIds = settings?.openId ?? [];
    if (openIds.isEmpty) {
      return [
        ListTile(
          leading: const Icon(Icons.link_off),
          title: const Text('暂无关联账号'),
          subtitle: const Text('未关联任何第三方账号'),
        ),
      ];
    }
    return openIds
        .map((oid) => ListTile(
              leading: Icon(_openIdIcon(oid.provider)),
              title: Text(oid.providerName),
              subtitle: Text('关联于 ${_formatDate(oid.linkedAt)}'),
              trailing: IconButton(
                icon: const Icon(Icons.link_off, color: Colors.red),
                onPressed: () => _unlinkOpenId(context, oid),
              ),
            ))
        .toList();
  }

  Future<void> _unlinkOpenId(BuildContext context, OpenIdProvider oid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑账号'),
        content: Text('确定要解绑 ${oid.providerName} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('解绑'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<UserSettingProvider>().unlinkOpenId(oid.provider);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('已解绑 ${oid.providerName}');
    } else {
      ToastHelper.failure('解绑失败');
    }
  }

  IconData _openIdIcon(int provider) {
    switch (provider) {
      case 1:
        return Icons.chat_bubble; // QQ
      default:
        return Icons.login;
    }
  }

  // ---- OAuth 授权 ----
  List<Widget> _buildOAuthGrantTiles(BuildContext context, UserSettingModel? settings) {
    final grants = settings?.oauthGrants ?? [];
    if (grants.isEmpty) {
      return [
        ListTile(
          leading: const Icon(Icons.apps_outage),
          title: const Text('暂无授权应用'),
          subtitle: const Text('未授权任何第三方应用'),
        ),
      ];
    }
    return grants
        .map((grant) => ListTile(
              leading: grant.clientLogo != null
                  ? CircleAvatar(backgroundImage: NetworkImage(grant.clientLogo!))
                  : const CircleAvatar(child: Icon(Icons.apps)),
              title: Text(grant.clientName),
              subtitle: Text(grant.lastUsedAt != null
                  ? '最后使用 ${_formatDate(grant.lastUsedAt!)}'
                  : '权限: ${grant.scopes.join(", ")}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _revokeOAuth(context, grant),
              ),
            ))
        .toList();
  }

  Future<void> _revokeOAuth(BuildContext context, OAuthGrant grant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤销授权'),
        content: Text('确定要撤销 "${grant.clientName}" 的授权吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('撤销'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<UserSettingProvider>().revokeOAuthGrant(grant.clientId);
    if (!mounted) return;
    if (success) {
      ToastHelper.success('已撤销 ${grant.clientName} 的授权');
    } else {
      ToastHelper.failure('撤销授权失败');
    }
  }

  // ---- 登录活动 ----
  List<Widget> _buildLoginActivityTiles(UserSettingModel settings) {
    final activities = settings.loginActivity;
    if (activities.isEmpty) {
      return [
        const ListTile(
          leading: Icon(Icons.history),
          title: Text('暂无登录记录'),
        ),
      ];
    }
    return activities.map((activity) {
      final icon = activity.success
          ? Icons.check_circle_outline
          : Icons.cancel_outlined;
      final iconColor = activity.success ? Colors.green : Colors.red;
      return ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(activity.loginMethodName),
        subtitle: Text(
          '${_formatDate(activity.createdAt)}'
          '\n${activity.os} · ${activity.browser}'
          '${activity.ip.isNotEmpty ? " · ${activity.ip}" : ""}',
        ),
        isThreeLine: true,
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
