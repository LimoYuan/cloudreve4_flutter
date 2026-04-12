import 'package:flutter/material.dart' hide DateUtils;
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';

/// 文件列表项
class FileListItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
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
          trailing: file.metadata?.isNotEmpty == true
                  ? Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade400,
                    )
                  : null,
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
