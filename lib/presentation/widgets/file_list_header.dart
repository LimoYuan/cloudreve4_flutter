import 'package:flutter/material.dart';

import '../../core/constants/sort_options.dart';

/// 文件列表表头（桌面端），支持点击排序。
class FileListHeader extends StatelessWidget {
  final bool showCheckbox;
  final int totalCount;
  final int selectedCount;
  final SortOption? currentSort;
  final ValueChanged<SortOption>? onSort;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;

  const FileListHeader({
    super.key,
    this.showCheckbox = false,
    this.totalCount = 0,
    this.selectedCount = 0,
    this.currentSort,
    this.onSort,
    this.onSelectAll,
    this.onClearSelection,
  });

  bool get _hasSelection => selectedCount > 0;
  bool get _allSelected => totalCount > 0 && selectedCount >= totalCount;
  bool get _partialSelected => selectedCount > 0 && selectedCount < totalCount;

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
          Expanded(
            flex: 5,
            child: _buildNameHeader(context, theme),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '类型',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(flex: 1, child: _buildSortHeader(context, theme, SortField.size, '大小')),
          Expanded(flex: 2, child: _buildSortHeader(context, theme, SortField.updatedAt, '修改日期')),
        ],
      ),
    );
  }

  Widget _buildNameHeader(BuildContext context, ThemeData theme) {
    final showBulkSelector = showCheckbox || _hasSelection;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: showBulkSelector
              ? SizedBox(
                  key: const ValueKey('bulk-selector'),
                  width: 32,
                  height: 24,
                  child: Tooltip(
                    message: _allSelected ? '取消全选' : '全选当前列表',
                    waitDuration: const Duration(milliseconds: 450),
                    child: Checkbox(
                      value: _partialSelected ? null : _allSelected,
                      tristate: true,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: totalCount <= 0
                          ? null
                          : (_) {
                              if (_allSelected) {
                                onClearSelection?.call();
                              } else {
                                onSelectAll?.call();
                              }
                            },
                    ),
                  ),
                )
              : const SizedBox(
                  key: ValueKey('bulk-selector-empty'),
                  width: 0,
                  height: 24,
                ),
        ),
        _buildSortHeader(context, theme, SortField.name, '名称'),
      ],
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
      final newDir = currentSort!.direction == SortDirection.asc
          ? SortDirection.desc
          : SortDirection.asc;
      onSort!(SortOption(field, newDir));
    } else {
      onSort!(SortOption(field, SortDirection.asc));
    }
  }
}
