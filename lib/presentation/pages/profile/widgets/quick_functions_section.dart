import 'package:cloudreve4_flutter/presentation/widgets/glassmorphism_container.dart';
import 'package:cloudreve4_flutter/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 快捷功能项配置
class _QuickFunction {
  final IconData icon;
  final String label;
  final String route;

  const _QuickFunction({
    required this.icon,
    required this.label,
    required this.route,
  });
}

/// 快捷功能区 — 毛玻璃卡片
class QuickFunctionsSection extends StatelessWidget {
  const QuickFunctionsSection({super.key});

  static const _functions = [
    _QuickFunction(icon: LucideIcons.share2, label: '我的分享', route: RouteNames.share),
    _QuickFunction(icon: LucideIcons.cloud, label: 'WebDAV', route: RouteNames.webdav),
    _QuickFunction(icon: LucideIcons.download, label: '离线下载', route: RouteNames.remoteDownload),
    _QuickFunction(icon: LucideIcons.trash2, label: '回收站', route: RouteNames.recycleBin),
    _QuickFunction(icon: LucideIcons.settings, label: '设置', route: RouteNames.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('快捷功能',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _functions.map((fn) {
            return _QuickFunctionCard(
              icon: fn.icon,
              label: fn.label,
              onTap: () => Navigator.of(context).pushNamed(fn.route),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickFunctionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFunctionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickFunctionCard> createState() => _QuickFunctionCardState();
}

class _QuickFunctionCardState extends State<_QuickFunctionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: GlassmorphismContainer(
            borderRadius: 16,
            sigmaX: 10,
            sigmaY: 10,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: _hovered
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _hovered
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
