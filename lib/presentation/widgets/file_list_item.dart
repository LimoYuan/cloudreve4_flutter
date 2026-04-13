import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';

/// 文件列表项
class FileListItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onDownload,
    this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          leading: _buildIcon(context),
          title: Text(
            file.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          subtitle: file.isFolder
                  ? null
                  : Text(
                      DateUtils.formatFileSize(file.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (file.metadata?.isNotEmpty == true)
                Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              const SizedBox(width: 8),
              if (onDownload != null || onOpenInBrowser != null)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showMenu(context);
                  },
                  tooltip: '更多选项',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color iconColor;

    if (file.isFolder) {
      icon = Icons.folder_outlined;
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.insert_drive_file_outlined;
      iconColor = Colors.grey.shade600;
    }

    return Icon(
      icon,
      color: iconColor,
      size: 32,
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height + 200,
      ),
      items: [
        if (onDownload != null)
          PopupMenuItem(
            value: 'download',
            child: Row(
              children: const [
                Icon(Icons.download_outlined, size: 18),
                SizedBox(width: 12),
                Text('下载'),
              ],
            ),
          ),
        if (onOpenInBrowser != null)
          PopupMenuItem(
            value: 'openInBrowser',
            child: Row(
              children: const [
                Icon(Icons.open_in_browser, size: 18),
                SizedBox(width: 12),
                Text('在浏览器中打开'),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'download') {
        onDownload?.call();
      } else if (value == 'openInBrowser') {
        onOpenInBrowser?.call();
      }
    });
  }
}
