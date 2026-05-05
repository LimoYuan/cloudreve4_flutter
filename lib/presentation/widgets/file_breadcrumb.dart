import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 面包屑导航组件
class FileBreadcrumb extends StatelessWidget {
  final String currentPath;
  final void Function(String path) onPathTap;

  const FileBreadcrumb({
    super.key,
    required this.currentPath,
    required this.onPathTap,
  });

  @override
  Widget build(BuildContext context) {
    final pathParts = currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildBreadcrumbItem(
              context,
              name: '首页',
              path: '/',
              icon: LucideIcons.home,
              primaryColor: colorScheme.primary,
              onTap: () => onPathTap('/'),
            ),
            for (int i = 0; i < pathParts.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(LucideIcons.chevronRight, size: 16, color: theme.hintColor.withValues(alpha: 0.5)),
              ),
              _buildBreadcrumbItem(
                context,
                name: pathParts[i],
                path: '/${pathParts.sublist(0, i + 1).join('/')}',
                icon: null,
                primaryColor: colorScheme.primary,
                onTap: () => onPathTap('/${pathParts.sublist(0, i + 1).join('/')}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbItem(
    BuildContext context, {
    required String name,
    required String path,
    required IconData? icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              if (icon != null)
                Icon(icon, size: 16, color: primaryColor),
              if (icon != null) const SizedBox(width: 5),
              Text(
                name,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
