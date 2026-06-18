import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 面包屑导航组件（桌面端底部）
class FileBreadcrumb extends StatefulWidget {
  final String currentPath;
  final void Function(String path) onPathTap;

  const FileBreadcrumb({
    super.key,
    required this.currentPath,
    required this.onPathTap,
  });

  @override
  State<FileBreadcrumb> createState() => _FileBreadcrumbState();
}

class _FileBreadcrumbState extends State<FileBreadcrumb> {
  final _controller = ScrollController();
  int _previousDepth = 0;
  int _animationDirection = 1;

  @override
  void initState() {
    super.initState();
    _previousDepth = _pathDepth(widget.currentPath);
  }

  @override
  void didUpdateWidget(covariant FileBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      final nextDepth = _pathDepth(widget.currentPath);
      _animationDirection = nextDepth >= _previousDepth ? 1 : -1;
      _previousDepth = nextDepth;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 720),
            curve: Curves.easeInOutCubicEmphasized,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _pathDepth(String path) {
    return path.split('/').where((part) => part.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 760),
          reverseDuration: const Duration(milliseconds: 680),
          switchInCurve: Curves.easeInOutCubicEmphasized,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final incomingOffset = _animationDirection >= 0
                ? const Offset(-0.32, 0)
                : const Offset(0.32, 0);
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubicEmphasized,
              reverseCurve: Curves.easeInOutCubic,
            );

            return ClipRect(
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(begin: incomingOffset, end: Offset.zero).animate(curved),
                  child: child,
                ),
              ),
            );
          },
          child: _BreadcrumbStrip(
            key: ValueKey(widget.currentPath),
            controller: _controller,
            currentPath: widget.currentPath,
            onPathTap: widget.onPathTap,
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbStrip extends StatelessWidget {
  final ScrollController controller;
  final String currentPath;
  final void Function(String path) onPathTap;

  const _BreadcrumbStrip({
    super.key,
    required this.controller,
    required this.currentPath,
    required this.onPathTap,
  });

  @override
  Widget build(BuildContext context) {
    final pathParts = currentPath.split('/');
    pathParts.removeWhere((part) => part.isEmpty);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
              child: Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Theme.of(context).hintColor.withValues(alpha: 0.5),
              ),
            ),
            _buildBreadcrumbItem(
              context,
              name: _decodePathSegment(pathParts[i]),
              path: '/${pathParts.sublist(0, i + 1).join('/')}',
              icon: null,
              primaryColor: colorScheme.primary,
              onTap: () => onPathTap('/${pathParts.sublist(0, i + 1).join('/')}'),
            ),
          ],
        ],
      ),
    );
  }

  String _decodePathSegment(String segment) {
    var decoded = segment;
    for (var i = 0; i < 5; i++) {
      try {
        final next = Uri.decodeComponent(decoded);
        if (next == decoded) break;
        decoded = next;
      } catch (_) {
        break;
      }
    }
    return decoded;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16, color: primaryColor),
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
