import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/quick_access_defaults.dart';
import '../../../../router/app_router.dart';
import '../../../providers/file_manager_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/quick_access_provider.dart';
import '../../files/category_files_page.dart';

/// 首页快捷入口。
///
/// 默认四个入口不再跳转到固定文件夹，而是调用 Cloudreve 分类搜索：
/// 图片 / 视频 / 文档 / 音乐。
/// 用户自定义的目录快捷入口会跳转到文件管理器对应路径。
class QuickAccessGrid extends StatelessWidget {
  final bool fillHeight;

  const QuickAccessGrid({super.key, this.fillHeight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.select<QuickAccessProvider, List<QuickAccessConfig>>(
      (p) => p.items,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '快捷入口',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ..._buildRows(context, items),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context, List<QuickAccessConfig> items) {
    final total = items.length;
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
            child: _QuickAccessButton(
              item: items[index],
              onTap: () => _onTap(context, items[index]),
              fillHeight: fillHeight,
            ),
          ),
        );
      }

      final row = Row(children: rowItems);
      rows.add(fillHeight ? Expanded(child: row) : row);
      if (i + maxCols < total) {
        rows.add(const SizedBox(height: gap));
      }
    }
    return rows;
  }

  void _onTap(BuildContext context, QuickAccessConfig item) {
    if (item.path.startsWith('cloudreve://my?category=')) {
      _openCategory(context, item);
    } else {
      _openDirectory(context, item);
    }
  }

  void _openCategory(BuildContext context, QuickAccessConfig item) {
    final args = _argsForItem(item);
    Navigator.of(context).pushNamed(RouteNames.categoryFiles, arguments: args);
  }

  void _openDirectory(BuildContext context, QuickAccessConfig item) {
    final dirPath = item.path.startsWith('/') ? item.path : '/${item.path}';
    final navProvider = context.read<NavigationProvider>();
    final fileManager = context.read<FileManagerProvider>();
    navProvider.setIndex(1);
    fileManager.enterFolder(dirPath);
  }

  CategoryFilesPageArgs _argsForItem(QuickAccessConfig item) {
    switch (item.id) {
      case 'img':
        return CategoryFilesPageArgs(
          category: 'image',
          title: '图片',
          icon: LucideIcons.image,
          color: item.color,
        );
      case 'vid':
        return CategoryFilesPageArgs(
          category: 'video',
          title: '视频',
          icon: LucideIcons.video,
          color: item.color,
        );
      case 'doc':
        return CategoryFilesPageArgs(
          category: 'document',
          title: '文档',
          icon: LucideIcons.fileText,
          color: item.color,
        );
      case 'mus':
        return CategoryFilesPageArgs(
          category: 'audio',
          title: '音乐',
          icon: LucideIcons.music,
          color: item.color,
        );
      default:
        return CategoryFilesPageArgs(
          category: 'document',
          title: item.label,
          icon: item.icon,
          color: item.color,
        );
    }
  }
}

class _QuickAccessButton extends StatelessWidget {
  final QuickAccessConfig item;
  final VoidCallback onTap;
  final bool fillHeight;

  const _QuickAccessButton({
    required this.item,
    required this.onTap,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : item.color.darken(0.52);

    return Material(
      color: item.color.withValues(alpha: isDark ? 0.20 : 0.24),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: isDark ? 0.34 : 0.72),
                item.color.withValues(alpha: isDark ? 0.18 : 0.42),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: item.color.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SizedBox(
              height: fillHeight ? double.infinity : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: foreground, size: 22),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
