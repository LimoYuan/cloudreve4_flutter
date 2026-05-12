import 'package:cloudreve4_flutter/core/constants/quick_access_defaults.dart';
import 'package:cloudreve4_flutter/services/storage_service.dart';
import 'package:cloudreve4_flutter/presentation/widgets/toast_helper.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuickAccessSettingsPage extends StatefulWidget {
  const QuickAccessSettingsPage({super.key});

  @override
  State<QuickAccessSettingsPage> createState() => _QuickAccessSettingsPageState();
}

class _QuickAccessSettingsPageState extends State<QuickAccessSettingsPage> {
  List<QuickAccessConfig> _items = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    var saved = await StorageService.instance.getString(QuickAccessConfig.storageKey);
    if (saved != null && saved.isNotEmpty) {
      try {
        if (mounted) setState(() { _items = QuickAccessConfig.parseSaved(saved); _isLoaded = true; });
        return;
      } catch (_) {}
    }
    // 迁移 v1
    final v1 = await StorageService.instance.getString('quick_access_shortcuts');
    if (v1 != null && v1.isNotEmpty) {
      final migrated = QuickAccessConfig.migrateV1(v1);
      if (mounted) {
        setState(() { _items = migrated; _isLoaded = true; });
        await _save();
      }
      return;
    }
    if (mounted) setState(() { _items = List.from(QuickAccessConfig.defaults); _isLoaded = true; });
  }

  Future<void> _save() async {
    await StorageService.instance.setString(
      QuickAccessConfig.storageKey,
      QuickAccessConfig.serialize(_items),
    );
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final labelController = TextEditingController(text: item.label);
    final pathController = TextEditingController(text: item.path);

    final result = await showDialog<_EditResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑快捷入口'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '名称', hintText: '例如: 图片'),
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
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_EditResult(labelController.text, pathController.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _items[index] = item.copyWith(
          label: result.label.isNotEmpty ? result.label : item.label,
          path: result.path.isNotEmpty ? result.path : item.path,
        );
      });
      _save();
      ToastHelper.success('快捷入口已更新');
    }
  }

  Future<void> _addItem() async {
    final labelController = TextEditingController();
    final pathController = TextEditingController();
    IconData selectedIcon = LucideIcons.folder;
    Color selectedColor = QuickAccessConfig.colorPool[0];

    final result = await showDialog<_AddResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('新增快捷入口'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: '名称', hintText: '例如: 图片'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pathController,
                      decoration: const InputDecoration(labelText: '目录路径', hintText: '例如: /Images'),
                    ),
                    const SizedBox(height: 16),
                    Text('图标', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: QuickAccessConfig.iconPool.map((icon) {
                        final isSelected = icon.codePoint == selectedIcon.codePoint;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15) : null,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: Theme.of(ctx).colorScheme.primary, width: 2)
                                  : Border.all(color: Theme.of(ctx).dividerColor),
                            ),
                            child: Icon(icon, size: 20, color: isSelected ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).hintColor),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('颜色', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: QuickAccessConfig.colorPool.map((color) {
                        final isSelected = color.toARGB32() == selectedColor.toARGB32();
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(color: color.darken(0.2), width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(LucideIcons.check, size: 18, color: color.darken(0.3))
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(_AddResult(
                    labelController.text,
                    pathController.text,
                    selectedIcon,
                    selectedColor,
                  )),
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.label.isNotEmpty && result.path.isNotEmpty) {
      setState(() {
        _items.add(QuickAccessConfig(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          label: result.label,
          icon: result.icon,
          path: result.path,
          color: result.color,
        ));
      });
      _save();
      ToastHelper.success('快捷入口已添加');
    }
  }

  void _moveItem(int from, int to) {
    if (from < 0 || from >= _items.length || to < 0 || to >= _items.length || from == to) return;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
    });
    _save();
  }

  void _deleteItem(int index) {
    if (_items[index].isDefault) return;
    setState(() {
      _items.removeAt(index);
    });
    _save();
    ToastHelper.success('快捷入口已删除');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('快捷入口')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '自定义概览页中显示的快捷目录入口。默认入口不可删除，但可编辑路径和调整顺序。',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
          ),
          if (_isLoaded)
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 20, color: item.color.darken(0.3)),
                  ),
                  title: Row(
                    children: [
                      Text(item.label),
                      if (item.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('默认', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(item.path, style: TextStyle(color: theme.hintColor, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 上移
                      IconButton(
                        icon: Icon(LucideIcons.chevronUp, size: 18),
                        onPressed: index > 0 ? () => _moveItem(index, index - 1) : null,
                        tooltip: '上移',
                        visualDensity: VisualDensity.compact,
                      ),
                      // 下移
                      IconButton(
                        icon: Icon(LucideIcons.chevronDown, size: 18),
                        onPressed: index < _items.length - 1 ? () => _moveItem(index, index + 1) : null,
                        tooltip: '下移',
                        visualDensity: VisualDensity.compact,
                      ),
                      // 编辑
                      IconButton(
                        icon: Icon(LucideIcons.pencil, size: 16),
                        onPressed: () => _editItem(index),
                        tooltip: '编辑',
                        visualDensity: VisualDensity.compact,
                      ),
                      // 删除（默认不可删）
                      if (!item.isDefault)
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.error),
                          onPressed: () => _deleteItem(index),
                          tooltip: '删除',
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('新增快捷入口'),
                    onPressed: _addItem,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: const Text('恢复默认'),
                  onPressed: () {
                    setState(() { _items = List.from(QuickAccessConfig.defaults); });
                    _save();
                    ToastHelper.success('已恢复默认设置');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _EditResult {
  final String label;
  final String path;
  _EditResult(this.label, this.path);
}

class _AddResult {
  final String label;
  final String path;
  final IconData icon;
  final Color color;
  _AddResult(this.label, this.path, this.icon, this.color);
}
