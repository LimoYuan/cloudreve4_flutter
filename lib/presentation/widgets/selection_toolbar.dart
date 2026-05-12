import 'package:flutter/material.dart';

/// 选择工具栏组件
class SelectionToolbar extends StatelessWidget {
  final int selectionCount;
  final VoidCallback onCancel;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onCopy;
  final VoidCallback onDelete;

  const SelectionToolbar({
    super.key,
    required this.selectionCount,
    required this.onCancel,
    this.onRename,
    this.onMove,
    this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '已选择 $selectionCount 项',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: onCancel,
            tooltip: '取消选择',
          ),
          if (selectionCount == 1 && onRename != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onRename,
              tooltip: '重命名',
            ),
          if (onMove != null)
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: onMove,
              tooltip: '移动',
            ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: onCopy,
              tooltip: '复制',
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
            tooltip: '删除',
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
