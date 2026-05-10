import 'package:cloudreve4_flutter/core/constants/quick_access_defaults.dart';
import 'package:cloudreve4_flutter/main.dart' show routeObserver;
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class QuickAccessGrid extends StatefulWidget {
  final bool fillHeight;
  const QuickAccessGrid({super.key, this.fillHeight = false});

  @override
  State<QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<QuickAccessGrid> with RouteAware {
  List<QuickAccessConfig> _items = [];

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    _loadShortcuts();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadShortcuts() async {
    // 先尝试 v2 格式
    var saved = await StorageService.instance.getString(QuickAccessConfig.storageKey);
    if (saved != null && saved.isNotEmpty) {
      try {
        if (mounted) setState(() => _items = QuickAccessConfig.parseSaved(saved));
        return;
      } catch (_) {}
    }
    // 迁移 v1 格式
    final v1 = await StorageService.instance.getString('quick_access_shortcuts');
    if (v1 != null && v1.isNotEmpty) {
      final migrated = QuickAccessConfig.migrateV1(v1);
      if (mounted) {
        setState(() => _items = migrated);
        await StorageService.instance.setString(
          QuickAccessConfig.storageKey,
          QuickAccessConfig.serialize(migrated),
        );
      }
      return;
    }
    if (mounted) setState(() => _items = List.from(QuickAccessConfig.defaults));
  }

  void _navigateTo(String path) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    navProvider.setIndex(1);
    fileManager.enterFolder(path);
  }

  Future<void> _editShortcut(int index) async {
    final item = _items[index];
    final labelController = TextEditingController(text: item.label);
    final pathController = TextEditingController(text: item.path);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 "${item.label}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(labelText: '目录路径', hintText: '例如: /Images'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(pathController.text), child: const Text('确定')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _items[index] = item.copyWith(path: result);
      });
      await _save();
    }
  }

  Future<void> _save() async {
    await StorageService.instance.setString(
      QuickAccessConfig.storageKey,
      QuickAccessConfig.serialize(_items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('快捷入口', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ..._buildRows(),
      ],
    );
  }

  List<Widget> _buildRows() {
    final total = _items.length;
    if (total == 0) return [];

    final maxCols = total > 6 ? 3 : 2;
    const gap = 10.0;
    final rows = <Widget>[];

    for (int i = 0; i < total; i += maxCols) {
      final rowItems = <Widget>[];
      final remaining = total - i;
      final colsInRow = remaining < maxCols ? remaining : maxCols;

      for (int j = 0; j < colsInRow; j++) {
        final index = i + j;
        if (j > 0) rowItems.add(const SizedBox(width: gap));
        rowItems.add(
          Expanded(
            child: _AccessChip(
              item: _items[index],
              onTap: () => _navigateTo(_items[index].path),
              onLongPress: () => _editShortcut(index),
              expanded: true,
              fillHeight: widget.fillHeight,
            ),
          ),
        );
      }

      final row = Row(children: rowItems);
      rows.add(widget.fillHeight ? Expanded(child: row) : row);
      if (i + maxCols < total) {
        rows.add(const SizedBox(height: gap));
      }
    }
    return rows;
  }
}

/// 渐变胶囊
class _AccessChip extends StatefulWidget {
  final QuickAccessConfig item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool expanded;
  final bool fillHeight;

  const _AccessChip({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.expanded = false,
    this.fillHeight = false,
  });

  @override
  State<_AccessChip> createState() => _AccessChipState();
}

class _AccessChipState extends State<_AccessChip> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
      upperBound: 1.0,
    )..value = 1.0;
    _scaleAnim = _controller.view;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [item.color, item.color.darken(0.12)],
    );

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: widget.expanded ? double.infinity : null,
      height: widget.fillHeight ? double.infinity : null,
      alignment: widget.expanded ? Alignment.center : null,
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? 0 : 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: _hovered ? 0.4 : 0.18),
            blurRadius: _hovered ? 16 : 8,
            offset: Offset(0, _hovered ? 6 : 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            item.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.reverse(),
        onTapUp: (_) {
          _controller.forward();
          widget.onTap();
        },
        onTapCancel: () => _controller.forward(),
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, _) => Transform.scale(scale: _scaleAnim.value, child: child),
        ),
      ),
    );
  }
}
