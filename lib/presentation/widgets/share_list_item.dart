import 'package:flutter/material.dart';
import '../../data/models/share_model.dart';

/// 截断文件名，智能截断避免多个小数点
String _truncateFileName(String name, int maxLength) {
  if (name.length <= maxLength) {
    return name;
  }

  // 查找最后一个点
  final lastDotIndex = name.lastIndexOf('.');

  // 如果没有点，或者点在开头或末尾，直接截断
  if (lastDotIndex <= 0 || lastDotIndex >= name.length - 1) {
    return '${name.substring(0, maxLength - 3)}...';
  }

  // 有扩展名的情况
  final extension = name.substring(lastDotIndex);
  final nameWithoutExt = name.substring(0, lastDotIndex);

  // 扩展名太长，直接截断整个文件名
  if (extension.length >= maxLength) {
    return '${name.substring(0, maxLength - 3)}...';
  }

  // 计算主体部分能显示的长度
  const ellipsis = '...';
  final maxNameLength = maxLength - extension.length - ellipsis.length;

  // 空间太小，主体部分至少保留3个字符
  if (maxNameLength < 3) {
    return '${name.substring(0, maxLength - 3)}...';
  }

  // 主体部分能完整显示
  if (nameWithoutExt.length <= maxNameLength) {
    return '$nameWithoutExt$ellipsis$extension';
  }

  // 主体部分需要截断
  return '${nameWithoutExt.substring(0, maxNameLength)}$ellipsis$extension';
}

/// 文件名显示组件
class _FileNameDisplay extends StatelessWidget {
  final String name;
  final Color? textColor;

  const _FileNameDisplay({
    required this.name,
    this.textColor,
  });

  /// 精确计算文本宽度
  String _fitText(String text, double maxWidth, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    if (textPainter.width <= maxWidth) {
      return text;
    }

    // 二分查找最佳长度
    int min = 1;
    int max = text.length;
    int best = 0;

    while (min <= max) {
      final mid = ((min + max) / 2).floor();
      final candidate = _truncateFileName(text, mid);

      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      );
      painter.layout();

      if (painter.width <= maxWidth) {
        best = mid;
        min = mid + 1;
      } else {
        max = mid - 1;
      }
    }

    return _truncateFileName(text, best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final style = TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        );

        final fittedName = _fitText(name, maxWidth, style);

        return Text(
          fittedName,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// 分享列表项
class ShareListItem extends StatelessWidget {
  final ShareModel share;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ShareListItem({
    super.key,
    required this.share,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final expired = share.expired;
    final textColor = expired ? Colors.grey.shade600 : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          share.isFolder
                              ? Icons.folder
                              : Icons.insert_drive_file_outlined,
                          color: textColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FileNameDisplay(
                            name: share.name,
                            textColor: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      share.url,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded( 
                flex: 35,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (share.isPrivate ?? false) ...[
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 14, color: Colors.blue),
                              ],
                            ),
                          ),
                        ],
                        if (share.downloaded != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${share.downloaded}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                                Icon(Icons.download, size: 14, color: Colors.green.shade700),
                              ],
                            ),
                          ),
                          
                        ],
                        ...[
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${share.visited}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                                Icon(Icons.visibility, size: 14, color: Colors.yellow.shade700),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onEdit != null) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, size: 24),
                            onPressed: onEdit,
                            tooltip: '编辑',
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                        if (onDelete != null) ...[
                          IconButton(
                            icon: const Icon(Icons.delete, size: 24),
                            onPressed: onDelete,
                            tooltip: '删除',
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
