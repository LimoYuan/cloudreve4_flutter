import 'package:flutter/material.dart';

import '../../core/constants/sort_options.dart';

/// 文件列表表头（桌面端），支持点击排序
class FileListHeader extends StatelessWidget {
  final bool showCheckbox;
  final SortOption? currentSort;
  final ValueChanged<SortOption>? onSort;

  const FileListHeader({
    super.key,
    this.showCheckbox = false,
    this.currentSort,
    this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          if (showCheckbox) const SizedBox(width: 40),
          Expanded(flex: 5, child: _buildSortHeader(context, theme, SortField.name, '名称')),
          Expanded(flex: 1, child: Text('类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.hintColor))),
          Expanded(flex: 1, child: _buildSortHeader(context, theme, SortField.size, '大小')),
          Expanded(flex: 2, child: _buildSortHeader(context, theme, SortField.updatedAt, '修改日期')),
        ],
      ),
    );
  }

  Widget _buildSortHeader(BuildContext context, ThemeData theme, SortField field, String label) {
    final isActive = currentSort?.field == field;
    final style = TextStyle(
      color: isActive ? theme.colorScheme.primary : theme.hintColor,
      fontSize: 12,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
    );

    return InkWell(
      onTap: () => _onHeaderTap(field),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                currentSort!.direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onHeaderTap(SortField field) {
    if (onSort == null) return;
    if (currentSort?.field == field) {
      // 同一列：切换方向
      final newDir = currentSort!.direction == SortDirection.asc
          ? SortDirection.desc
          : SortDirection.asc;
      onSort!(SortOption(field, newDir));
    } else {
      // 新列：默认升序
      onSort!(SortOption(field, SortDirection.asc));
    }
  }
}
