import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/date_utils.dart';
import 'file_menu_helper.dart';

/// 文件网格项
class FileGridItem extends StatelessWidget {
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

  const FileGridItem({
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
      builder: (builderContext) => LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = (constraints.maxWidth * 0.13).clamp(11.0, 14.0);

          return _FileGridItemHover(
            file: file,
            isSelected: isSelected,
            showCheckbox: showCheckbox,
            fontSize: fontSize,
            onTap: onTap,
            onLongPress: () => _showMenu(builderContext),
            onSelect: onSelect,
            onMore: () => _showMenu(builderContext),
          );
        },
      ),
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

class _FileGridItemHover extends StatefulWidget {
  final FileModel file;
  final bool isSelected;
  final bool showCheckbox;
  final double fontSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final VoidCallback? onMore;

  const _FileGridItemHover({
    required this.file,
    required this.isSelected,
    required this.showCheckbox,
    required this.fontSize,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.onMore,
  });

  @override
  State<_FileGridItemHover> createState() => _FileGridItemHoverState();
}

class _FileGridItemHoverState extends State<_FileGridItemHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = widget.file.isFolder
        ? colorScheme.primary
        : FileGridItem._getFileIconColor(widget.file.name);
    final icon = widget.file.isFolder
        ? LucideIcons.folder
        : FileGridItem._getFileIcon(widget.file.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _isHovered
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : theme.dividerColor.withValues(alpha: 0.5),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 65,
                    child: Center(
                      child: widget.showCheckbox
                          ? Checkbox(
                              value: widget.isSelected,
                              onChanged: (_) => widget.onSelect?.call(),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )
                          : FittedBox(
                              fit: BoxFit.contain,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: iconColor, size: 24),
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    flex: 35,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _truncateFileName(widget.file.name),
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (!widget.file.isFolder)
                          Text(
                            DateUtils.formatFileSize(widget.file.size),
                            style: TextStyle(
                              fontSize: widget.fontSize * 0.85,
                              color: theme.hintColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Hover action button
              if (_isHovered && !widget.showCheckbox)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: widget.onMore,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(LucideIcons.moreVertical, size: 14, color: colorScheme.primary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateFileName(String name) {
    const maxChars = 15;
    if (name.length <= maxChars) return name;

    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < name.length - 1) {
      final prefix = name.substring(0, 6);
      final extension = name.substring(dotIndex);
      final middleLength = maxChars - prefix.length - extension.length - 3;
      if (middleLength > 0) return '$prefix...$extension';
    }

    final half = (maxChars - 3) ~/ 2;
    return '${name.substring(0, half)}...${name.substring(name.length - half)}';
  }
}
