import 'package:cloudreve4_flutter/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

class QuickFunctionsSection extends StatelessWidget {
  const QuickFunctionsSection({super.key});

  static const _functions = [
    _QuickFunction(icon: LucideIcons.share2, label: '我的分享', route: RouteNames.share),
    _QuickFunction(icon: LucideIcons.cloud, label: 'WebDAV', route: RouteNames.webdav),
    _QuickFunction(icon: LucideIcons.download, label: '离线下载', route: RouteNames.remoteDownload),
    _QuickFunction(icon: LucideIcons.trash2, label: '回收站', route: RouteNames.recycleBin),
    _QuickFunction(icon: LucideIcons.settings, label: '设置', route: RouteNames.settings),
  ];

  static const double _spacing = 12;
  static const double _runSpacing = 4;
  static const double _minItemWidth = 120;

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
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            int perRow = 1;
            while (perRow < _functions.length) {
              final next = perRow + 1;
              final itemWidth = (availableWidth - _spacing * (next - 1)) / next;
              if (itemWidth < _minItemWidth) break;
              perRow = next;
            }
            final itemWidth = (availableWidth - _spacing * (perRow - 1)) / perRow;

            return Wrap(
              spacing: _spacing,
              runSpacing: _runSpacing,
              children: _functions.map((fn) {
                return SizedBox(
                  width: itemWidth,
                  child: _QuickFunctionCard(
                    icon: fn.icon,
                    label: fn.label,
                    onTap: () => Navigator.of(context).pushNamed(fn.route),
                  ),
                );
              }).toList(),
            );
          },
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

    return Card(
      color: _hovered
          ? colorScheme.surfaceContainerHighest
          : null,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        onHover: (v) => setState(() => _hovered = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _hovered ? colorScheme.primary : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
