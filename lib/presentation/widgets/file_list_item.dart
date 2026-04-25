import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_utils.dart';
import 'file_menu_helper.dart';

/// 文件列表项
class FileListItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onTap,
    this.onSelect,
    this.onDownload,
    this.onOpenInBrowser,
    this.onRename,
    this.onMove,
    this.onCopy,
    this.onShare,
    this.onDelete,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) => GestureDetector(
        onTap: onTap,
        onLongPress: () => _showMenu(builderContext),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheckbox)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelect?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (!showCheckbox) _buildIcon(context),
              ],
            ),
            title: Text(
              file.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: file.isFolder
                    ? null
                    : Text(
                        DateUtils.formatFileSize(file.size),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color iconColor;

    if (file.isFolder) {
      icon = Icons.folder_outlined;
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = _getFileIcon(file.name);
      iconColor = _getFileIconColor(file.name);
    }

    return Icon(
      icon,
      color: iconColor,
      size: 32,
    );
  }

  /// 获取文件图标
  IconData _getFileIcon(String fileName) {
    if (FileUtils.isImageFile(fileName)) {
      return Icons.image;
    } else if (FileUtils.isVideoFile(fileName)) {
      return Icons.videocam;
    } else if (FileUtils.isAudioFile(fileName)) {
      return Icons.audiotrack;
    } else if (FileUtils.isPdfFile(fileName)) {
      return Icons.picture_as_pdf;
    } else if (FileUtils.isTextFile(fileName)) {
      return Icons.description;
    } else if (FileUtils.isCodeFile(fileName)) {
      return Icons.code;
    } else if (FileUtils.isArchiveFile(fileName)) {
      return Icons.folder_zip;
    } else if (FileUtils.isDocumentFile(fileName)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  /// 获取文件图标颜色
  Color _getFileIconColor(String fileName) {
    if (FileUtils.isImageFile(fileName)) {
      return Colors.purple.shade600;
    } else if (FileUtils.isVideoFile(fileName)) {
      return Colors.orange.shade600;
    } else if (FileUtils.isAudioFile(fileName)) {
      return Colors.blue.shade600;
    } else if (FileUtils.isPdfFile(fileName)) {
      return Colors.red.shade600;
    } else if (FileUtils.isTextFile(fileName)) {
      return Colors.teal.shade600;
    } else if (FileUtils.isCodeFile(fileName)) {
      return Colors.cyan.shade700;
    } else if (FileUtils.isArchiveFile(fileName)) {
      return Colors.amber.shade600;
    } else if (FileUtils.isDocumentFile(fileName)) {
      return Colors.indigo.shade600;
    }
    return Colors.grey.shade600;
  }

  Future<void> _showMenu(BuildContext context) async {
    final result = await showFileMenu(
      context: context,
      hasSelect: onSelect != null,
      hasDownload: onDownload != null,
      hasOpenInBrowser: onOpenInBrowser != null,
      hasRename: onRename != null,
      hasMove: onMove != null,
      hasCopy: onCopy != null,
      hasShare: onShare != null,
      hasDelete: onDelete != null,
      hasRestore: onRestore != null,
    );

    switch (result) {
      case FileMenuAction.select:
        onSelect?.call();
      case FileMenuAction.download:
        onDownload?.call();
      case FileMenuAction.openInBrowser:
        onOpenInBrowser?.call();
      case FileMenuAction.rename:
        onRename?.call();
      case FileMenuAction.move:
        onMove?.call();
      case FileMenuAction.copy:
        onCopy?.call();
      case FileMenuAction.share:
        onShare?.call();
      case FileMenuAction.delete:
        onDelete?.call();
      case FileMenuAction.restore:
        onRestore?.call();
      case null:
        break;
    }
  }
}
