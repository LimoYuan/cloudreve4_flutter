import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/date_utils.dart';

/// 文件网格项
class FileGridItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;

  const FileGridItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.onTap,
    this.onSelect,
    this.onDownload,
    this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) => LayoutBuilder(
        builder: (context, constraints) {
          // 根据容器宽度计算字体大小
          final fontSize = (constraints.maxWidth * 0.13).clamp(11.0, 14.0);

          return GestureDetector(
            onTap: onTap,
            onLongPress: () => _showMenu(builderContext),
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
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标区域 - 占 70%
                  Expanded(
                    flex: 7,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: file.isFolder
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            file.isFolder ? Icons.folder : _getFileIcon(file.name),
                            color: file.isFolder
                                ? Theme.of(context).colorScheme.primary
                                : _getFileIconColor(file.name),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 文本区域 - 占 30%
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 文件名
                        Text(
                          _truncateFileName(file.name),
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        // 文件大小
                        if (!file.isFolder)
                          Text(
                            _formatFileSize(file.size),
                            style: TextStyle(
                              fontSize: fontSize * 0.85,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            );
        },
      ),
    );
  }

  /// 截断文件名：开头...结尾 格式
  String _truncateFileName(String name) {
    const maxChars = 15;

    if (name.length <= maxChars) {
      return name;
    }

    // 尝试保留扩展名
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < name.length - 1) {
      final prefix = name.substring(0, 6);
      final extension = name.substring(dotIndex);
      final middleLength = maxChars - prefix.length - extension.length - 3;

      if (middleLength > 0) {
        return '$prefix...$extension';
      }
    }

    // 没有扩展名或扩展名太长，简单截断
    final half = (maxChars - 3) ~/ 2;
    return '${name.substring(0, half)}...${name.substring(name.length - half)}';
  }

  void _showMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('_showMenu: renderBox is null');
      return;
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy,
      offset.dx + renderBox.size.width,
      offset.dy + renderBox.size.height,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String>>[
        if (onSelect != null)
          const PopupMenuItem(
            value: 'select',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 12),
                Text('选择'),
              ],
            ),
          ),
        if (onDownload != null)
          const PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: 12),
                Text('下载'),
              ],
            ),
          ),
        if (onOpenInBrowser != null)
          const PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_browser, size: 20),
                SizedBox(width: 12),
                Text('在浏览器中打开'),
              ],
            ),
          ),
      ],
    ).then((value) {
      debugPrint('_showMenu: selected value: $value');
      if (value == 'select') {
        onSelect?.call();
      } else if (value == 'download') {
        onDownload?.call();
      } else if (value == 'open') {
        onOpenInBrowser?.call();
      }
    });
  }

  IconData _getFileIcon(String fileName) {
    if (FileUtils.isImageFile(fileName)) {
      return Icons.image;
    } else if (FileUtils.isVideoFile(fileName)) {
      return Icons.videocam;
    } else if (FileUtils.isPdfFile(fileName)) {
      return Icons.picture_as_pdf;
    } else if (FileUtils.isArchiveFile(fileName)) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _getFileIconColor(String fileName) {
    if (FileUtils.isImageFile(fileName)) {
      return Colors.blue.shade600;
    } else if (FileUtils.isVideoFile(fileName)) {
      return Colors.red.shade600;
    } else if (FileUtils.isPdfFile(fileName)) {
      return Colors.red.shade500;
    } else if (FileUtils.isArchiveFile(fileName)) {
      return Colors.orange.shade600;
    }
    return Colors.grey.shade600;
  }

  String _formatFileSize(int bytes) {
    return DateUtils.formatFileSize(bytes);
  }
}
