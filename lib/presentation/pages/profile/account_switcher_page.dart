import 'package:cloudreve4_flutter/data/models/user_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/user_avatar.dart';
import 'package:cloudreve4_flutter/router/app_router.dart';
import 'package:cloudreve4_flutter/services/server_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

/// 账号切换页面
///
/// 一个站点对应一个 ServerModel；同站点多个账号保存在 currentServer.accounts。
class AccountSwitcherPage extends StatefulWidget {
  const AccountSwitcherPage({super.key});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}

class _AccountSwitcherPageState extends State<AccountSwitcherPage> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentServer = auth.currentServer;
    final currentUser = auth.user;
    final accounts = currentServer?.accounts ?? const <UserModel>[];

    return Scaffold(
      appBar: AppBar(title: const Text('切换账号')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CurrentSiteCard(
            siteLabel: currentServer?.label ?? '未选择站点',
            siteUrl: currentServer?.baseUrl ?? '-',
            currentUser: currentUser,
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            icon: LucideIcons.users,
            title: '当前站点账号',
            trailing: '${accounts.length} 个',
          ),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            const _EmptyAccountCard()
          else
            ...accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AccountTile(
                  account: account,
                  isCurrent: currentUser?.id == account.id,
                  onTap: _isBusy ? null : () => _switchAccount(account),
                  onLongPress: _isBusy ? null : () => _showAccountActions(account),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _ActionCard(
            icon: LucideIcons.userPlus,
            title: '添加另一个账户',
            subtitle: currentServer == null
                ? '当前没有选中的站点'
                : '在 ${currentServer.label} 上登录另一个账号',
            onTap: _isBusy ? null : _addAccount,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: LucideIcons.logOut,
            title: '退出当前账号',
            subtitle: '清除当前账号登录状态，不删除站点配置',
            destructive: true,
            onTap: _isBusy ? null : _confirmLogout,
          ),
        ],
      ),
    );
  }

  Future<void> _switchAccount(UserModel account) async {
    final auth = context.read<AuthProvider>();

    if (auth.user?.id == account.id) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isBusy = true);
    final authenticated = await auth.switchToAccount(account.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 ${account.nickname}')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.nickname} 需要重新登录')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.login,
        (route) => false,
      );
    }
  }

  Future<void> _showAccountActions(UserModel account) async {
    final auth = context.read<AuthProvider>();
    final isCurrent = auth.user?.id == account.id;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: UserAvatar(
                    userId: account.id,
                    email: account.email,
                    displayName: account.nickname,
                    radius: 22,
                  ),
                  title: Text(
                    account.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(account.email ?? 'ID: ${account.id}'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(
                    LucideIcons.trash2,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    isCurrent ? '退出并删除当前账号' : '删除这个账号',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    isCurrent
                        ? '删除后会回到登录页'
                        : '只从当前站点的账号列表中移除',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteAccount(account);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount(UserModel account) async {
    final auth = context.read<AuthProvider>();
    final isCurrent = auth.user?.id == account.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrent ? '删除当前账号' : '删除账号'),
        content: Text(
          isCurrent
              ? '确定要删除并退出「${account.nickname}」吗？服务器配置会保留。'
              : '确定要从当前站点移除「${account.nickname}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final removedCurrent = await context.read<AuthProvider>().removeSavedAccount(account.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (removedCurrent) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.login,
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除账号 ${account.nickname}')),
    );
  }

  Future<void> _addAccount() async {
    final auth = context.read<AuthProvider>();

    setState(() => _isBusy = true);
    try {
      await auth.createAccountSlotForCurrentSite();
      if (!mounted) return;

      setState(() => _isBusy = false);

      // 只 push 登录页，不清空当前导航栈。
      // 如果用户突然不想添加账号，按返回键会回到当前账号切换页，
      // 原账号仍然保持登录，账号列表也不会出现空账号。
      await Navigator.of(context).pushNamed(RouteNames.login);

      if (!mounted) return;
      setState(() => _isBusy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加账号失败: $e')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出当前账号'),
        content: const Text('确定要退出当前账号吗？该账号会从当前站点账号列表中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.login,
      (route) => false,
    );
  }
}

class _CurrentSiteCard extends StatelessWidget {
  final String siteLabel;
  final String siteUrl;
  final UserModel? currentUser;

  const _CurrentSiteCard({
    required this.siteLabel,
    required this.siteUrl,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = currentUser?.nickname ?? '未登录';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            UserAvatar(
              userId: currentUser?.id ?? '',
              email: currentUser?.email,
              displayName: displayName,
              radius: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? '当前没有登录账号',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoChip(
                    icon: LucideIcons.server,
                    text: siteLabel,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    siteUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final UserModel account;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AccountTile({
    required this.account,
    required this.isCurrent,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: UserAvatar(
          userId: account.id,
          email: account.email,
          displayName: account.nickname,
          radius: 22,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                account.nickname,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '当前',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (account.email != null) account.email!,
            'ID: ${account.id}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          isCurrent ? LucideIcons.checkCircle2 : LucideIcons.chevronRight,
          size: 20,
          color: isCurrent ? theme.colorScheme.primary : theme.hintColor,
        ),
      ),
    );
  }
}

class _EmptyAccountCard extends StatelessWidget {
  const _EmptyAccountCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              LucideIcons.userX,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '当前站点还没有保存的账号',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: destructive ? color : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(LucideIcons.chevronRight, size: 20),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
