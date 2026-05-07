import 'package:cloudreve4_flutter/data/models/admin_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/admin_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

/// 管理员功能区域
class AdminSection extends StatelessWidget {
  const AdminSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adminProvider = context.watch<AdminProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(LucideIcons.shield, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('管理',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (adminProvider.isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else ...[
          _GroupsCard(groups: adminProvider.groups, pagination: adminProvider.groupsPagination),
          const SizedBox(height: 12),
          _UsersCard(users: adminProvider.users, pagination: adminProvider.usersPagination),
        ],
      ],
    );
  }
}

/// 用户组列表卡片
class _GroupsCard extends StatelessWidget {
  final List<AdminGroupModel> groups;
  final PaginationModel? pagination;

  const _GroupsCard({required this.groups, this.pagination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.users, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('用户组',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (pagination != null)
                  Text(
                    '共 ${pagination!.totalItems} 个',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('暂无数据',
                      style: TextStyle(color: theme.hintColor)),
                ),
              )
            else
              ...groups.map((group) => _GroupItem(group: group)),
          ],
        ),
      ),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final AdminGroupModel group;

  const _GroupItem({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                group.name[0],
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  'ID: ${group.id}  •  ${group.formattedMaxStorage}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          if (group.name.toLowerCase() == 'admin' || group.name == '管理员')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('管理员',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// 用户列表卡片
class _UsersCard extends StatelessWidget {
  final List<AdminUserModel> users;
  final PaginationModel? pagination;

  const _UsersCard({required this.users, this.pagination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.user, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('用户',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (pagination != null)
                  Text(
                    '共 ${pagination!.totalItems} 个',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('暂无数据',
                      style: TextStyle(color: theme.hintColor)),
                ),
              )
            else
              ...users.map((user) => _UserItem(user: user)),
          ],
        ),
      ),
    );
  }
}

class _UserItem extends StatelessWidget {
  final AdminUserModel user;

  const _UserItem({required this.user});

  bool _isAdminGroup(AdminGroupModel group) {
    final name = group.name.toLowerCase();
    return name == 'admin' || name == '管理员';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          UserAvatar(
            userId: user.id.toString(),
            email: user.email,
            displayName: user.nick,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.nick,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (user.group != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _isAdminGroup(user.group!)
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(user.group!.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _isAdminGroup(user.group!)
                                  ? colorScheme.onPrimaryContainer
                                  : theme.hintColor,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.email}  •  ${user.formattedStorage}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
