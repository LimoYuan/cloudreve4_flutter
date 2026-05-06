import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_icon_utils.dart';
import '../../services/file_service.dart';
import 'file_menu_helper.dart';

/// 文件列表项
class FileListItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool showCheckbox;
  final int index;
  final bool isDesktop;
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

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.showCheckbox = false,
    this.index = 0,
    this.isDesktop = true,
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
  });

  @override
  Widget build(BuildContext context) {
    return _FileListItemHover(
      file: file,
      isSelected: isSelected,
      index: index,
      isDesktop: isDesktop,
      showCheckbox: showCheckbox,
      tapToShowMenu: tapToShowMenu,
      onTap: tapToShowMenu ? null : onTap,
      onLongPress: () => _showMenu(context),
      onSelect: onSelect,
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

class _FileListItemHover extends StatefulWidget {
  final FileModel file;
  final bool isSelected;
  final int index;
  final bool isDesktop;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showCheckbox;
  final VoidCallback? onSelect;
  final bool tapToShowMenu;

  const _FileListItemHover({
    required this.file,
    required this.isSelected,
    required this.index,
    required this.isDesktop,
    this.onTap,
    this.onLongPress,
    required this.showCheckbox,
    this.onSelect,
    this.tapToShowMenu = false,
  });

  @override
  State<_FileListItemHover> createState() => _FileListItemHoverState();
}

class _FileListItemHoverState extends State<_FileListItemHover> {
  bool _isHovered = false;
  String? _folderSizeText;
  bool _isCalculatingFolder = false;

  Future<void> _calculateFolderSize() async {
    setState(() => _isCalculatingFolder = true);
    try {
      final response = await FileService().getFileInfo(
        uri: widget.file.relativePath,
        folderSummary: true,
      );
      final summary = response['folder_summary'];
      if (summary is Map<String, dynamic> && summary.containsKey('size')) {
        if (mounted) {
          setState(() {
            _folderSizeText = DateUtils.formatFileSize(summary['size'] as int);
            _isCalculatingFolder = false;
          });
        }
      } else {
        if (mounted) setState(() => _isCalculatingFolder = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCalculatingFolder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bgColor;
    if (widget.isSelected) {
      bgColor = colorScheme.primary.withValues(alpha: 0.08);
    } else if (_isHovered) {
      bgColor = colorScheme.primary.withValues(alpha: 0.05);
    } else if (widget.index.isOdd) {
      bgColor = colorScheme.surfaceContainerLow;
    } else {
      bgColor = colorScheme.surface;
    }

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
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDesktop ? 24 : 16,
            vertical: 8,
          ),
          child: widget.isDesktop
              ? _buildDesktopRow(context)
              : _buildMobileRow(context),
        ),
      ),
    );
  }

  Widget _buildSizeCell(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!widget.file.isFolder) {
      return Text(
        DateUtils.formatFileSize(widget.file.size),
        style: TextStyle(fontSize: 13, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 文件夹：已计算 -> 显示大小，未计算 -> 小按钮
    if (_folderSizeText != null) {
      return Text(
        _folderSizeText!,
        style: TextStyle(fontSize: 13, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return _buildCalcButton(context, colorScheme);
  }

  Widget _buildCalcButton(BuildContext context, ColorScheme colorScheme) {
    if (_isCalculatingFolder) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: colorScheme.primary,
        ),
      );
    }

    return InkWell(
      onTap: _calculateFolderSize,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calculator, size: 11, color: colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              '计算',
              style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// 桌面端：三列对齐 Row
  Widget _buildDesktopRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameColor = widget.isSelected ? colorScheme.primary : colorScheme.onSurface;

    return Row(
      children: [
        if (widget.showCheckbox)
          SizedBox(
            width: 40,
            child: Checkbox(
              value: widget.isSelected,
              onChanged: (_) => widget.onSelect?.call(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        FileIconUtils.buildIconWidget(context: context, file: widget.file),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Text(
            widget.file.name,
            style: TextStyle(
              fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
              fontSize: 14,
              color: nameColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            DateUtils.formatDateTime(widget.file.updatedAt),
            style: TextStyle(fontSize: 13, color: theme.hintColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildSizeCell(context),
        ),
      ],
    );
  }

  /// 窄屏端：两行紧凑布局
  Widget _buildMobileRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameColor = widget.isSelected ? colorScheme.primary : colorScheme.onSurface;

    // 构建第二行内容
    final typeLabel = FileIconUtils.getFileTypeLabel(widget.file.name, isFolder: widget.file.isFolder);
    final dateStr = DateUtils.formatDateTime(widget.file.updatedAt);

    return Row(
      children: [
        if (widget.showCheckbox)
          SizedBox(
            width: 40,
            child: Checkbox(
              value: widget.isSelected,
              onChanged: (_) => widget.onSelect?.call(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        FileIconUtils.buildIconWidget(context: context, file: widget.file),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.file.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: nameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // 第二行：文件夹显示 计算按钮，文件显示类型|大小|日期
              if (widget.file.isFolder)
                Row(
                  children: [
                    Text('$typeLabel  |  $dateStr', style: TextStyle(fontSize: 12, color: theme.hintColor)),
                    const SizedBox(width: 6),
                    if (_folderSizeText != null)
                      Text('|  $_folderSizeText', style: TextStyle(fontSize: 12, color: theme.hintColor))
                    else
                      _buildCalcButton(context, colorScheme),
                  ],
                )
              else
                Text(
                  '$typeLabel  |  ${DateUtils.formatFileSize(widget.file.size)}  |  $dateStr',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
