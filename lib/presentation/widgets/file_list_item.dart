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
                _MenuButton(
                  onDownload: onDownload,
                  onOpenInBrowser: onOpenInBrowser,
                ),
            ],
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
}

/// 菜单按钮
class _MenuButton extends StatelessWidget {
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;

  const _MenuButton({
    required this.onDownload,
    required this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-160, 0),
      style: MenuStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevation: WidgetStateProperty.all(8),
        backgroundColor: WidgetStateProperty.all(Colors.white),
      ),
      builder: (context, controller, child) {
        return IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          tooltip: '更多选项',
          visualDensity: VisualDensity.compact,
        );
      },
      menuChildren: [
        if (onDownload != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.download_outlined, size: 20),
            child: const Text('下载'),
            onPressed: () {
              onDownload?.call();
            },
          ),
        if (onOpenInBrowser != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.open_in_browser, size: 20),
            child: const Text('在浏览器中打开'),
            onPressed: () {
              onOpenInBrowser?.call();
            },
          ),
      ],
    );
  }
}
