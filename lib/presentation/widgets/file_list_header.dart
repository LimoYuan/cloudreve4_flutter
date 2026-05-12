import 'package:flutter/material.dart';

/// 文件列表表头（桌面端）
class FileListHeader extends StatelessWidget {
  final bool showCheckbox;
  const FileListHeader({super.key, this.showCheckbox = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = TextStyle(
      color: theme.hintColor,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

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
          // 图标占位
          const SizedBox(width: 36 + 16),
          Expanded(flex: 5, child: Text('名称', style: style)),
          Expanded(flex: 2, child: Text('修改日期', style: style)),
          Expanded(flex: 1, child: Text('大小', style: style)),
        ],
      ),
    );
  }
}
