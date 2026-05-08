import 'package:cloudreve4_flutter/data/models/admin_model.dart';
import 'package:cloudreve4_flutter/presentation/providers/admin_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/toast_helper.dart';
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

// ==================== 用户组卡片 ====================

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
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed: () => _showCreateGroupDialog(context),
                  tooltip: '创建用户组',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _StyledDialog(
        title: '创建用户组',
        icon: LucideIcons.users,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: _StyledInputDecoration(
            labelText: '用户组名称',
            hintText: '请输入用户组名称',
          ),
        ),
        onConfirm: () {
          final name = controller.text.trim();
          if (name.isEmpty) return false;
          Navigator.of(ctx).pop();
          context.read<AdminProvider>().createGroup(name).then((success) {
            if (context.mounted) {
              if (success) {
                ToastHelper.success('创建成功');
              } else {
                ToastHelper.failure('创建失败');
              }
            }
          });
          return true;
        },
      ),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final AdminGroupModel group;

  const _GroupItem({required this.group});

  bool get _isAdmin => group.name.toLowerCase() == 'admin' || group.name == '管理员';

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
          if (_isAdmin)
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
            )
          else
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 16, color: colorScheme.error.withValues(alpha: 0.7)),
              onPressed: () => _confirmDeleteGroup(context, group),
              tooltip: '删除',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, AdminGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => _StyledConfirmDialog(
        title: '删除用户组',
        message: '确定要删除用户组「${group.name}」吗？',
        icon: LucideIcons.trash2,
        isDestructive: true,
        onConfirm: () {
          Navigator.of(ctx).pop();
          context.read<AdminProvider>().deleteGroup(group.id).then((error) {
            if (context.mounted) {
              if (error != null) {
                ToastHelper.failure(error);
              } else {
                ToastHelper.success('已删除');
              }
            }
          });
        },
      ),
    );
  }
}

// ==================== 用户卡片 ====================

class _UsersCard extends StatelessWidget {
  final List<AdminUserModel> users;
  final PaginationModel? pagination;

  const _UsersCard({required this.users, this.pagination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adminProvider = context.watch<AdminProvider>();
    final isSelecting = adminProvider.isSelectingUsers;

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
                const SizedBox(width: 8),
                if (isSelecting) ...[
                  if (adminProvider.hasSelectedUsers)
                    TextButton.icon(
                      onPressed: () => _confirmBatchDelete(context, adminProvider.selectedUserIds.toList()),
                      icon: Icon(LucideIcons.trash2, size: 16, color: colorScheme.error),
                      label: Text('删除 (${adminProvider.selectedUserIds.length})',
                          style: TextStyle(color: colorScheme.error)),
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  IconButton.outlined(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => adminProvider.exitSelectMode(),
                    tooltip: '取消选择',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ] else ...[
                  IconButton.outlined(
                    icon: const Icon(LucideIcons.checkSquare, size: 18),
                    onPressed: () => adminProvider.toggleSelectMode(),
                    tooltip: '多选',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    onPressed: () => _showCreateUserDialog(context),
                    tooltip: '创建用户',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            if (isSelecting)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => adminProvider.selectAllUsers(),
                      child: const Text('全选'),
                    ),
                    TextButton(
                      onPressed: () => adminProvider.clearUserSelection(),
                      child: const Text('取消全选'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
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

  void _showCreateUserDialog(BuildContext context) {
    final emailController = TextEditingController();
    final nickController = TextEditingController();
    final passwordController = TextEditingController();
    final groups = context.read<AdminProvider>().groups;
    int? selectedGroupId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _StyledDialog(
          title: '创建用户',
          icon: LucideIcons.userPlus,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: _StyledInputDecoration(
                  labelText: '邮箱',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(LucideIcons.mail, size: 18),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nickController,
                decoration: _StyledInputDecoration(
                  labelText: '昵称',
                  hintText: '请输入昵称',
                  prefixIcon: Icon(LucideIcons.user, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: _StyledInputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码',
                  prefixIcon: Icon(LucideIcons.lock, size: 18),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _GroupChipSelector(
                groups: groups,
                selectedGroupId: selectedGroupId,
                onChanged: (id) => setDialogState(() => selectedGroupId = id),
              ),
            ],
          ),
          onConfirm: () {
            final email = emailController.text.trim();
            final nick = nickController.text.trim();
            final password = passwordController.text.trim();
            if (email.isEmpty || nick.isEmpty || password.isEmpty || selectedGroupId == null) {
              ToastHelper.error('请填写完整信息');
              return false;
            }
            Navigator.of(ctx).pop();
            context.read<AdminProvider>().createUser(
              email: email,
              nick: nick,
              password: password,
              groupId: selectedGroupId!,
            ).then((success) {
              if (context.mounted) {
                if (success) {
                  ToastHelper.success('创建成功');
                } else {
                  ToastHelper.failure('创建失败');
                }
              }
            });
            return true;
          },
        ),
      ),
    );
  }

  void _confirmBatchDelete(BuildContext context, List<int> ids) {
    showDialog(
      context: context,
      builder: (ctx) => _StyledConfirmDialog(
        title: '批量删除用户',
        message: '确定要删除选中的 ${ids.length} 个用户吗？此操作不可撤销。',
        icon: LucideIcons.trash2,
        isDestructive: true,
        onConfirm: () {
          Navigator.of(ctx).pop();
          context.read<AdminProvider>().batchDeleteUsers(ids).then((success) {
            if (context.mounted) {
              if (success) {
                ToastHelper.success('已删除');
              } else {
                ToastHelper.failure('删除失败');
              }
            }
          });
        },
      ),
    );
  }
}

/// 用户组 Chip 选择器 — 替代 DropdownButtonFormField
class _GroupChipSelector extends StatelessWidget {
  final List<AdminGroupModel> groups;
  final int? selectedGroupId;
  final ValueChanged<int?> onChanged;

  const _GroupChipSelector({
    required this.groups,
    this.selectedGroupId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('用户组',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: groups.map((group) {
            final selected = selectedGroupId == group.id;
            return ChoiceChip(
              label: Text(group.name),
              selected: selected,
              onSelected: (_) => onChanged(selected ? null : group.id),
              avatar: selected
                  ? null
                  : CircleAvatar(
                      radius: 10,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        group.name[0],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
        if (selectedGroupId == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '请选择用户组',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
      ],
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
    final adminProvider = context.watch<AdminProvider>();
    final isSelecting = adminProvider.isSelectingUsers;
    final isSelected = adminProvider.isUserSelected(user.id);

    return InkWell(
      onTap: isSelecting ? () => adminProvider.toggleUserSelection(user.id) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (isSelecting)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => adminProvider.toggleUserSelection(user.id),
                ),
              ),
            UserAvatar(
              userId: user.hashId ?? user.id.toString(),
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
      ),
    );
  }
}

// ==================== 统一风格对话框组件 ====================

/// 圆角风格对话框 — 与页面 Card 风格统一
class _StyledDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool Function() onConfirm;

  const _StyledDialog({
    required this.title,
    required this.icon,
    required this.child,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => onConfirm(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆角确认对话框
class _StyledConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const _StyledConfirmDialog({
    required this.title,
    required this.message,
    required this.icon,
    this.isDestructive = false,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: 18,
                      color: isDestructive
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDestructive ? colorScheme.error : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一输入框装饰 — 填充背景 + 圆角
class _StyledInputDecoration extends InputDecoration {
  _StyledInputDecoration({
    super.labelText,
    super.hintText,
    super.prefixIcon,
  }) : super(
         filled: true,
         border: const OutlineInputBorder(
           borderRadius: BorderRadius.all(Radius.circular(12)),
         ),
         enabledBorder: const OutlineInputBorder(
           borderRadius: BorderRadius.all(Radius.circular(12)),
           borderSide: BorderSide.none,
         ),
         focusedBorder: const OutlineInputBorder(
           borderRadius: BorderRadius.all(Radius.circular(12)),
         ),
         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
       );
}
