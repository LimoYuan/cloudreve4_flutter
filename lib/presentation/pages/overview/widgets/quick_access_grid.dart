import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/quick_access_defaults.dart';
import '../../../../router/app_router.dart';
import '../../files/category_files_page.dart';

/// 首页快捷入口。
///
/// 默认四个入口不再跳转到固定文件夹，而是调用 Cloudreve 分类搜索：
/// 图片 / 视频 / 文档 / 音乐。
class QuickAccessGrid extends StatelessWidget {
  final bool fillHeight;

  const QuickAccessGrid({
    super.key,
    this.fillHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = QuickAccessConfig.defaults;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final childAspectRatio = fillHeight
            ? (isWide ? 2.25 : 2.35)
            : (isWide ? 2.55 : 2.45);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.zap,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '快捷入口',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _QuickAccessButton(
                  item: item,
                  onTap: () => _openCategory(context, item),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openCategory(BuildContext context, QuickAccessConfig item) {
    final args = _argsForItem(item);
    Navigator.of(context).pushNamed(
      RouteNames.categoryFiles,
      arguments: args,
    );
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

  const _QuickAccessButton({
    required this.item,
    required this.onTap,
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
            child: Row(
              children: [
                Icon(item.icon, color: foreground, size: 22),
                const SizedBox(width: 9),
                Expanded(
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
    );
  }
}
