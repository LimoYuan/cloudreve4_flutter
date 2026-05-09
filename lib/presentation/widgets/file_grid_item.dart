import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_icon_utils.dart';
import '../../core/utils/file_utils.dart';
import 'file_menu_helper.dart';
import 'thumbnail_image.dart';

/// 文件网格项
class FileGridItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isHighlighted;
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
  final VoidCallback? onInfo;
  final bool tapToShowMenu;
  final String? contextHint;

  const FileGridItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.isHighlighted = false,
    this.showCheckbox = false,
    this.tapToShowMenu = false,
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
    this.onInfo,
    this.contextHint,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (builderContext) => LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = (constraints.maxWidth * 0.1).clamp(10.0, 13.0);

          return _FileGridItemHover(
            file: file,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            showCheckbox: showCheckbox,
            contextHint: contextHint,
            fontSize: fontSize,
            tapToShowMenu: tapToShowMenu,
            onTap: tapToShowMenu ? null : onTap,
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
      hasInfo: onInfo != null,
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
      case FileMenuAction.info:
        onInfo?.call();
      case null:
        break;
    }
  }
}

class _FileGridItemHover extends StatefulWidget {
  final FileModel file;
  final bool isSelected;
  final bool isHighlighted;
  final bool showCheckbox;
  final String? contextHint;
  final double fontSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final VoidCallback? onMore;
  final bool tapToShowMenu;

  const _FileGridItemHover({
    required this.file,
    required this.isSelected,
    required this.isHighlighted,
    required this.showCheckbox,
    required this.contextHint,
    required this.fontSize,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.onMore,
    this.tapToShowMenu = false,
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
    final isDark = theme.brightness == Brightness.dark;

    // 卡片背景
    Color cardBg;
    BoxBorder? border;
    List<BoxShadow>? shadows;

    if (widget.isSelected) {
      cardBg = colorScheme.primary.withValues(alpha: 0.06);
      border = Border.all(color: colorScheme.primary, width: 2);
    } else if (widget.isHighlighted) {
      cardBg = colorScheme.primary.withValues(alpha: 0.06);
      border = Border.all(color: colorScheme.primary.withValues(alpha: 0.3));
      shadows = [
        BoxShadow(
          color: colorScheme.primary.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (_isHovered) {
      cardBg = isDark ? const Color(0xFF263548) : const Color(0xFFF1F5F9);
      border = Border.all(color: colorScheme.primary.withValues(alpha: 0.2));
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      cardBg = colorScheme.surfaceContainerLow;
      border = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : theme.dividerColor.withValues(alpha: 0.15),
      );
    }

    // 文字颜色
    final nameColor = widget.isSelected ? colorScheme.primary : colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.tapToShowMenu ? widget.onLongPress : widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: border,
            boxShadow: shadows,
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 图标区
                  Expanded(
                    child: widget.showCheckbox
                        ? Center(
                            child: Checkbox(
                              value: widget.isSelected,
                              onChanged: (_) => widget.onSelect?.call(),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                        : _buildIconArea(context),
                  ),
                  const SizedBox(height: 6),
                  // 文字区：左对齐
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 第一行：文件名
                        Text(
                          _truncateFileName(widget.file.name),
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w500,
                            color: nameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // 第二行：类型 | 大小
                        Text(
                          widget.file.isFolder
                              ? FileIconUtils.getFileTypeLabel(widget.file.name, isFolder: true)
                              : '${FileIconUtils.getFileTypeLabel(widget.file.name)}  |  ${DateUtils.formatFileSize(widget.file.size)}',
                          style: TextStyle(
                            fontSize: widget.fontSize * 0.85,
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        // 第三行：修改时间
                        Text(
                          DateUtils.formatDateTime(widget.file.updatedAt),
                          style: TextStyle(
                            fontSize: widget.fontSize * 0.8,
                            color: theme.hintColor.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Hover 操作按钮
              if (_isHovered && !widget.showCheckbox)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: widget.onMore,
                      borderRadius: BorderRadius.circular(14),
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
    const maxChars = 20;
    if (name.length <= maxChars) return name;

    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < name.length - 1) {
      final prefix = name.substring(0, 8);
      final extension = name.substring(dotIndex);
      final middleLength = maxChars - prefix.length - extension.length - 3;
      if (middleLength > 0) return '$prefix...$extension';
    }

    final half = (maxChars - 3) ~/ 2;
    return '${name.substring(0, half)}...${name.substring(name.length - half)}';
  }

  Widget _buildIconArea(BuildContext context) {
    final file = widget.file;
    final ext = FileUtils.getFileExtension(file.name);
    final isThumbnailable = !file.isFolder
        && FileUtils.isImageFile(file.name)
        && ext != 'svg';

    if (!isThumbnailable) {
      return Center(
        child: FileIconUtils.buildIconWidget(
          context: context,
          file: file,
          size: 40,
          iconSize: 22,
          borderRadius: 10,
        ),
      );
    }

    return ThumbnailImage(
      file: file,
      contextHint: widget.contextHint,
      borderRadius: 10,
    );
  }
}
