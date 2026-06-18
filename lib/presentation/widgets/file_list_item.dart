import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
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
  final bool isHighlighted;
  final bool showCheckbox;
  final bool alwaysShowMobileCheckbox;
  final int index;
  final bool isDesktop;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenInBrowser;
  final VoidCallback? onOpenInCloudreveApp;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onInfo;
  final bool tapToShowMenu;
  final void Function(List<XFile> files)? onDropFiles;

  const FileListItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.isHighlighted = false,
    this.showCheckbox = false,
    this.alwaysShowMobileCheckbox = false,
    this.index = 0,
    this.isDesktop = true,
    this.tapToShowMenu = false,
    this.onTap,
    this.onSelect,
    this.onDownload,
    this.onOpenInBrowser,
    this.onOpenInCloudreveApp,
    this.onRename,
    this.onMove,
    this.onCopy,
    this.onShare,
    this.onDelete,
    this.onRestore,
    this.onInfo,
    this.onDropFiles,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _FileListItemHover(
        file: file,
        isSelected: isSelected,
        isHighlighted: isHighlighted,
        index: index,
        isDesktop: isDesktop,
        showCheckbox: showCheckbox,
        alwaysShowMobileCheckbox: alwaysShowMobileCheckbox,
        tapToShowMenu: tapToShowMenu,
        onTap: tapToShowMenu ? null : onTap,
        onLongPress: () => _showMenu(context),
        onSelect: onSelect,
        onDropFiles: onDropFiles,
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final result = await showFileMenu(
      context: context,
      hasSelect: onSelect != null,
      hasDownload: onDownload != null,
      hasOpenInBrowser: onOpenInBrowser != null,
      hasOpenInCloudreveApp: onOpenInCloudreveApp != null,
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
      case FileMenuAction.openInCloudreveApp:
        onOpenInCloudreveApp?.call();
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


class _HoverSelectionSlot extends StatelessWidget {
  final bool visible;
  final bool selected;
  final VoidCallback? onSelect;

  const _HoverSelectionSlot({
    required this.visible,
    required this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // This widget is drawn as an overlay at the left edge of the row.
    // It does not reserve layout width while hidden, so the icon/name keep
    // their original position until the row is hovered or selected.
    return SizedBox(
      width: 40,
      child: ClipRect(
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: visible ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(-0.45, 0),
              child: Center(
                child: Checkbox(
                  value: selected,
                  onChanged: onSelect == null ? null : (_) => onSelect?.call(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSelectionCircle extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;

  const _MobileSelectionCircle({
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.0 : 0.94,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.surface.withValues(alpha: 0.94),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.88),
                width: selected ? 1.7 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.24)
                      : Colors.black.withValues(alpha: 0.10),
                  blurRadius: selected ? 8 : 4,
                  spreadRadius: selected ? -1 : -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: selected
                  ? Icon(
                      LucideIcons.check,
                      key: const ValueKey('selected'),
                      size: 14,
                      color: colorScheme.onPrimary,
                    )
                  : const SizedBox(key: ValueKey('empty')),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileListItemHover extends StatefulWidget {
  final FileModel file;
  final bool isSelected;
  final bool isHighlighted;
  final int index;
  final bool isDesktop;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showCheckbox;
  final bool alwaysShowMobileCheckbox;
  final VoidCallback? onSelect;
  final bool tapToShowMenu;
  final void Function(List<XFile> files)? onDropFiles;

  const _FileListItemHover({
    required this.file,
    required this.isSelected,
    required this.isHighlighted,
    required this.index,
    required this.isDesktop,
    this.onTap,
    this.onLongPress,
    required this.showCheckbox,
    required this.alwaysShowMobileCheckbox,
    this.onSelect,
    this.tapToShowMenu = false,
    this.onDropFiles,
  });

  @override
  State<_FileListItemHover> createState() => _FileListItemHoverState();
}

class _FileListItemHoverState extends State<_FileListItemHover>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isDropTargetHovered = false;
  String? _folderSizeText;
  bool _isCalculatingFolder = false;
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _highlightAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.30), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 0.30, end: 0.18), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _FileListItemHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !_highlightController.isAnimating) {
      _highlightController.repeat();
    } else if (!widget.isHighlighted && _highlightController.isAnimating) {
      _highlightController.stop();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  String _fileOperationUri(FileModel file) {
    if (file.path.startsWith('cloudreve://')) return file.path;
    final relative = file.relativePath;
    return relative == '/' ? file.path : relative;
  }

  bool get _isDesktopFolderDropTarget =>
      widget.file.isFolder &&
      widget.onDropFiles != null &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _calculateFolderSize() async {
    if (_isCalculatingFolder) return;
    if (!mounted) return;
    setState(() => _isCalculatingFolder = true);
    try {
      final response = await FileService().getFileInfo(
        uri: _fileOperationUri(widget.file),
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

    if (widget.isHighlighted) {
      return ListenableBuilder(
        listenable: _highlightController,
        builder: (context, _) {
          final bgColor = colorScheme.primary.withValues(alpha: _highlightAnimation.value);
          return _buildContent(context, bgColor);
        },
      );
    }

    Color bgColor;
    // Keep the row background outside the drop frame unchanged while dragging.
    // The drag target fill is clipped inside _ListFolderDropFrame, so the
    // bottom/edge tint cannot leak outside the rounded frame.
    if (widget.isSelected) {
      bgColor = colorScheme.primary.withValues(alpha: 0.08);
    } else if (_isHovered) {
      bgColor = colorScheme.primary.withValues(alpha: 0.20);
    } else if (widget.index.isOdd) {
      bgColor = colorScheme.surfaceContainerLow;
    } else {
      bgColor = colorScheme.surface;
    }
    return _buildContent(context, bgColor);
  }

  Widget _buildContent(BuildContext context, Color bgColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = widget.isDesktop
        ? _buildDesktopRow(context)
        : _buildMobileRow(context);

    final content = MouseRegion(
      onEnter: (_) {
        if (!_isHovered && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered && mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.tapToShowMenu ? widget.onLongPress : widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: widget.isDesktop
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: widget.isDesktop ? BorderRadius.zero : BorderRadius.circular(14),
            boxShadow: !widget.isDesktop && widget.isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.13),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.hardEdge,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (_isDesktopFolderDropTarget)
                  Positioned.fill(
                    child: _DropHoverFade(
                      visible: _isDropTargetHovered,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(4, 3, 4, 3),
                        child: _ListFolderDropFrame(),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isDesktop ? 24 : 16,
                    vertical: 8,
                  ),
                  child: row,
                ),
                if (_isDesktopFolderDropTarget)
                  Positioned.fill(
                    child: _DropHoverFade(
                      visible: _isDropTargetHovered,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(4, 3, 4, 3),
                        child: _ListFolderDropChip(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_isDesktopFolderDropTarget) {
      return content;
    }

    return DropTarget(
      onDragEntered: (_) {
        if (mounted) setState(() => _isDropTargetHovered = true);
      },
      onDragExited: (_) {
        if (mounted) setState(() => _isDropTargetHovered = false);
      },
      onDragDone: (details) {
        if (mounted) setState(() => _isDropTargetHovered = false);
        widget.onDropFiles?.call(details.files);
      },
      child: content,
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

    return Align(alignment: Alignment.centerLeft, child: _buildCalcButton(context, colorScheme));
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

  /// 桌面端：四列对齐 Row（名称→类型→大小→修改日期）
  Widget _buildDesktopRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameColor = widget.isSelected ? colorScheme.primary : colorScheme.onSurface;
    final typeLabel = FileIconUtils.getFileTypeLabel(widget.file.name, isFolder: widget.file.isFolder);

    final showSelectionBox = widget.showCheckbox || widget.isSelected || _isHovered;

    final row = Row(
      children: [
        Expanded(
          flex: 5,
          child: Row(
            children: [
              FileIconUtils.buildIconWidget(context: context, file: widget.file),
              const SizedBox(width: 16),
              Expanded(
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
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            typeLabel,
            style: TextStyle(fontSize: 13, color: theme.hintColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildSizeCell(context),
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
      ],
    );

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _HoverSelectionSlot(
              visible: showSelectionBox,
              selected: widget.isSelected,
              onSelect: widget.onSelect,
            ),
          ),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(left: showSelectionBox ? 40 : 0),
          child: row,
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
    final showInlineCheckbox = !widget.alwaysShowMobileCheckbox && widget.showCheckbox;
    final showTrailingCircle = widget.alwaysShowMobileCheckbox || widget.isSelected;

    return Row(
      children: [
        if (showInlineCheckbox)
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
        if (showTrailingCircle) ...[
          const SizedBox(width: 10),
          _MobileSelectionCircle(
            selected: widget.isSelected,
            onTap: widget.onSelect,
          ),
        ],
      ],
    );
  }
}


class _DropHoverFade extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _DropHoverFade({
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 280),
      curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
      builder: (context, value, child) {
        if (value <= 0.001) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.975 + value * 0.025,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _ListFolderDropFrame extends StatelessWidget {
  const _ListFolderDropFrame();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const radius = 12.0;
    const borderWidth = 1.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The fill is drawn under the border and clipped by the same radius.
          // Do not rely on the row background for drop feedback; otherwise a
          // blue strip can remain visible outside the rounded target frame.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.046),
              ),
              child: Padding(
                padding: const EdgeInsets.all(borderWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius - borderWidth),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.040),
                          Colors.transparent,
                          colorScheme.primary.withValues(alpha: 0.020),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.72),
                  width: borderWidth,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListFolderDropChip extends StatelessWidget {
  const _ListFolderDropChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.uploadCloud,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '释放上传到此文件夹',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
