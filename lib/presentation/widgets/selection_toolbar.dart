import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 文件选择底部操作栏。
///
/// 现在手机文件选择态直接复用和底部导航栏一致的 NavigationBar
/// 布局高度与目的项排版，让“下载 / 分享 / 删除 / 重命名 / 更多”
/// 和“概览 / 文件 / 任务 / 商店 / 我的”在图标、文字、横向间距上对齐。
class SelectionToolbar extends StatelessWidget {
  final int selectionCount;
  final int totalCount;
  final VoidCallback? onCancel;
  final VoidCallback? onSelectAll;
  final VoidCallback? onMore;
  final VoidCallback? onDownload;
  final VoidCallback? onMove;
  final VoidCallback? onCopy;
  final VoidCallback onDelete;

  /// 兼容旧调用参数。当前实现统一使用 MKW 手机选择栏样式。
  final bool useOldAndroidActions;
  final VoidCallback? onShare;
  final VoidCallback? onRename;

  const SelectionToolbar({
    super.key,
    required this.selectionCount,
    this.totalCount = 0,
    this.onCancel,
    this.onSelectAll,
    this.onMore,
    this.onDownload,
    this.onMove,
    this.onCopy,
    required this.onDelete,
    this.useOldAndroidActions = true,
    this.onShare,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return _buildMkwMobileSelectionBar(context);
  }

  double _bottomSystemPadding(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewPadding = media.viewPadding.bottom;
    if (viewPadding > 0) return viewPadding;

    // 手势导航模式下部分设备 viewPadding 为 0，但 systemGestureInsets
    // 仍会给出底部手势区域。给内容留一个小间距，避免贴住 Home 手势条。
    return media.systemGestureInsets.bottom > 0 ? 8.0 : 0.0;
  }

  Widget _buildMkwMobileSelectionBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomSafePadding = _bottomSystemPadding(context);
    final actions = <_MkwSelectionAction>[
      _MkwSelectionAction(
        icon: LucideIcons.download,
        label: '下载',
        onTap: onDownload,
      ),
      _MkwSelectionAction(
        icon: LucideIcons.share2,
        label: '分享',
        onTap: onShare,
      ),
      _MkwSelectionAction(
        icon: LucideIcons.trash2,
        label: '删除',
        color: colorScheme.error,
        onTap: onDelete,
      ),
      _MkwSelectionAction(
        icon: LucideIcons.edit3,
        label: '重命名',
        onTap: onRename,
      ),
      _MkwSelectionAction(
        icon: LucideIcons.moreHorizontal,
        label: '更多',
        onTap: onMore,
      ),
    ];

    return SizedBox(
      height: 80.0 + bottomSafePadding,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomSafePadding),
          child: NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
              indicatorColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                (states) => TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                (states) => IconThemeData(
                  size: 24,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            child: NavigationBar(
              height: 80,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: 0,
              onDestinationSelected: (index) {
                final action = actions[index];
                action.onTap?.call();
              },
              destinations: actions
                  .map(
                    (action) => NavigationDestination(
                      icon: Icon(
                        action.icon,
                        color: action.enabled
                            ? action.color
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                      selectedIcon: Icon(
                        action.icon,
                        color: action.enabled
                            ? action.color
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                        weight: 700,
                      ),
                      label: action.label,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _MkwSelectionAction {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _MkwSelectionAction({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  bool get enabled => onTap != null;
}
