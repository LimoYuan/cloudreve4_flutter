import 'package:flutter/material.dart';
import '../../data/models/share_model.dart';

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
                          child: Text(
                            share.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              Row(
                children: [
                  if (share.isPrivate ?? false) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            '密码保护',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (share.downloaded != null) ...[
                    Text(
                      '${share.downloaded} 次下载',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  ...[
                  Text(
                    '${share.visited} 次查看',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                  if (onEdit != null) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                      tooltip: '编辑',
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  if (onDelete != null) ...[
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                      tooltip: '删除',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
