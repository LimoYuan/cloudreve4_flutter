import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
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

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onTap,
    this.onSelect,
    this.onDownload,
    this.onOpenInBrowser,
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
      icon = Icons.insert_drive_file_outlined;
      iconColor = Colors.grey.shade600;
    }

    return Icon(
      icon,
      color: iconColor,
      size: 32,
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final result = await showFileMenu(
      context: context,
      hasSelect: onSelect != null,
      hasDownload: onDownload != null,
      hasOpenInBrowser: onOpenInBrowser != null,
    );

    switch (result) {
      case FileMenuAction.select:
        onSelect?.call();
      case FileMenuAction.download:
        onDownload?.call();
      case FileMenuAction.openInBrowser:
        onOpenInBrowser?.call();
      case null:
        break;
    }
  }
}
