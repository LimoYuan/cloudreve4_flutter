import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/date_utils.dart';

/// 文件网格项
class FileGridItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;

  const FileGridItem({
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图标区域
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: file.isFolder
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: _buildIcon(context),
                ),
              ),
            ),

            // 文件名区域
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!file.isFolder)
                          Text(
                            _formatFileSize(file.size),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // 操作按钮
                        if (!file.isFolder && (onDownload != null || onOpenInBrowser != null))
                          IconButton(
                            icon: const Icon(Icons.more_horiz, size: 20),
                            onPressed: () => _showMenu(context),
                            visualDensity: VisualDensity.compact,
                            tooltip: '更多选项',
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )
           ],
        ),
      )
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color iconColor;

    if (file.isFolder) {
      icon = Icons.folder;
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (FileUtils.isImageFile(file.name)) {
      icon = Icons.image;
      iconColor = Colors.blue.shade600;
    } else if (FileUtils.isVideoFile(file.name)) {
      icon = Icons.videocam;
      iconColor = Colors.red.shade600;
    } else if (FileUtils.isPdfFile(file.name)) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red.shade500;
    } else if (FileUtils.isArchiveFile(file.name)) {
      icon = Icons.folder_zip;
      iconColor = Colors.orange.shade600;
    } else {
      icon = Icons.insert_drive_file_outlined;
      iconColor = Colors.grey.shade600;
    }

    return Icon(
      icon,
      color: iconColor,
      size: file.isFolder ? 56 : 40,
    );
  }

  String _formatFileSize(int bytes) {
    return DateUtils.formatFileSize(bytes);
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
                Icon(Icons.download, size: 18),
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
