import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_utils.dart';
import 'file_menu_helper.dart';

/// 文件列表项
class FileListItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool showCheckbox;
  final int index;
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
    this.index = 0,
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
    return _FileListItemHover(
      isSelected: isSelected,
      index: index,
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      showCheckbox: showCheckbox,
      onSelect: onSelect,
      file: file,
    );
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

  static IconData _getFileIcon(String fileName) {
    if (FileUtils.isImageFile(fileName)) return LucideIcons.image;
    if (FileUtils.isVideoFile(fileName)) return LucideIcons.video;
    if (FileUtils.isAudioFile(fileName)) return LucideIcons.music;
    if (FileUtils.isPdfFile(fileName)) return LucideIcons.fileText;
    if (FileUtils.isTextFile(fileName)) return LucideIcons.fileText;
    if (FileUtils.isCodeFile(fileName)) return LucideIcons.code;
    if (FileUtils.isArchiveFile(fileName)) return LucideIcons.archive;
    if (FileUtils.isDocumentFile(fileName)) return LucideIcons.file;
    return LucideIcons.file;
  }

  static Color _getFileIconColor(String fileName) {
    if (FileUtils.isImageFile(fileName)) return const Color(0xFFA855F7);
    if (FileUtils.isVideoFile(fileName)) return const Color(0xFFF97316);
    if (FileUtils.isAudioFile(fileName)) return const Color(0xFF3B82F6);
    if (FileUtils.isPdfFile(fileName)) return const Color(0xFFEF4444);
    if (FileUtils.isTextFile(fileName)) return const Color(0xFF14B8A6);
    if (FileUtils.isCodeFile(fileName)) return const Color(0xFF06B6D4);
    if (FileUtils.isArchiveFile(fileName)) return const Color(0xFFF59E0B);
    if (FileUtils.isDocumentFile(fileName)) return const Color(0xFF6366F1);
    return const Color(0xFF64748B);
  }
}

class _FileListItemHover extends StatefulWidget {
  final bool isSelected;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showCheckbox;
  final VoidCallback? onSelect;
  final FileModel file;

  const _FileListItemHover({
    required this.isSelected,
    required this.index,
    this.onTap,
    this.onLongPress,
    required this.showCheckbox,
    this.onSelect,
    required this.file,
  });

  @override
  State<_FileListItemHover> createState() => _FileListItemHoverState();
}

class _FileListItemHoverState extends State<_FileListItemHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bgColor;
    if (widget.isSelected) {
      bgColor = colorScheme.primary.withValues(alpha: 0.08);
    } else if (_isHovered) {
      bgColor = colorScheme.primary.withValues(alpha: 0.04);
    } else if (widget.index.isOdd) {
      bgColor = theme.scaffoldBackgroundColor;
    } else {
      bgColor = colorScheme.surface;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showCheckbox)
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onSelect?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (!widget.showCheckbox) _buildIcon(context),
              ],
            ),
            title: Text(
              widget.file.name,
              style: TextStyle(
                fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: widget.file.isFolder
                ? null
                : Text(
                    DateUtils.formatFileSize(widget.file.size),
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.file.isFolder) {
      return Icon(LucideIcons.folder, color: colorScheme.primary, size: 28);
    }

    final icon = FileListItem._getFileIcon(widget.file.name);
    final iconColor = FileListItem._getFileIconColor(widget.file.name);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
