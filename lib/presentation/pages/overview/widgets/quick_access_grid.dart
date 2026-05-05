import 'package:cloudreve4_flutter/core/constants/quick_access_defaults.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class QuickAccessGrid extends StatefulWidget {
  const QuickAccessGrid({super.key});

  @override
  State<QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<QuickAccessGrid> {
  List<QuickAccessConfig> _items = [];

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
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
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 统一标题风格：图标 + 文字
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
        if (isWide)
          // 宽屏：Wrap 流式排列
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              return _AccessChip(
                item: item,
                onTap: () => _navigateTo(item.path),
                onLongPress: () => _editShortcut(index),
              );
            }),
          )
        else
          // 窄屏：每行 4 个，等分撑满
          ..._buildRows(),
      ],
    );
  }

  List<Widget> _buildRows() {
    const cols = 4;
    final rows = <Widget>[];
    for (int i = 0; i < _items.length; i += cols) {
      final rowItems = <Widget>[];
      for (int j = 0; j < cols && i + j < _items.length; j++) {
        final index = i + j;
        final item = _items[index];
        rowItems.add(
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: j == 0 ? 0 : 5,
                right: j == cols - 1 || i + j == _items.length - 1 ? 0 : 5,
              ),
              child: _AccessChip(
                item: item,
                onTap: () => _navigateTo(item.path),
                onLongPress: () => _editShortcut(index),
                expanded: true,
              ),
            ),
          ),
        );
      }
      // 不足 4 个的用空白补齐，保证对齐
      if (rowItems.length < cols) {
        for (int k = rowItems.length; k < cols; k++) {
          rowItems.add(Expanded(child: const SizedBox.shrink()));
        }
      }
      rows.add(Row(children: rowItems));
      if (i + cols < _items.length) {
        rows.add(const SizedBox(height: 10));
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
  final bool expanded; // 窄屏时撑满宽度

  const _AccessChip({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.expanded = false,
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
      child: Center(
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
