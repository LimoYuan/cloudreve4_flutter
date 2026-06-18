// PATCH_MARKER: preview_half_size_fix_20260611
// AI_PATCH_FORCE_PREVIEW_NO_SECOND_REQUEST_V3_20260611
import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:flutter/material.dart' hide DateUtils;
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/file_icon_utils.dart';
import '../../core/utils/file_utils.dart';
import 'file_menu_helper.dart';
import 'thumbnail_image.dart';

/// AI_PATCH_FORCE_PREVIEW_NO_SECOND_REQUEST_20260611
/// 文件网格项
class FileGridItem extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isHighlighted;
  final bool showCheckbox;
  final bool alwaysShowMobileCheckbox;
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
  final String? contextHint;
  final void Function(List<XFile> files)? onDropFiles;

  const FileGridItem({
    super.key,
    required this.file,
    this.isSelected = false,
    this.isHighlighted = false,
    this.showCheckbox = false,
    this.alwaysShowMobileCheckbox = false,
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
    this.contextHint,
    this.onDropFiles,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Builder(
        builder: (builderContext) => LayoutBuilder(
          builder: (context, constraints) {
            final fontSize = (constraints.maxWidth * 0.1).clamp(10.0, 13.0);

            return _FileGridItemHover(
              file: file,
              isSelected: isSelected,
              isHighlighted: isHighlighted,
              showCheckbox: showCheckbox,
              alwaysShowMobileCheckbox: alwaysShowMobileCheckbox,
              contextHint: contextHint,
              fontSize: fontSize,
              tapToShowMenu: tapToShowMenu,
              onTap: tapToShowMenu ? null : onTap,
              onLongPress: () => _showMenu(builderContext),
              onSelect: onSelect,
              onMore: () => _showMenu(builderContext),
              onDropFiles: onDropFiles,
            );
          },
        ),
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


class _FullPreviewImage extends StatelessWidget {
  final FileModel file;
  final String? contextHint;
  final double borderRadius;

  const _FullPreviewImage({
    required this.file,
    required this.contextHint,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Do not request /file/url here. The hover preview intentionally reuses
    // the already available Cloudreve thumbnail cache so the image does not
    // flash from thumbnail -> original image and no second API request is made.
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ThumbnailImage(
        file: file,
        contextHint: contextHint,
        borderRadius: borderRadius,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _FileGridItemHover extends StatefulWidget {
  final FileModel file;
  final bool isSelected;
  final bool isHighlighted;
  final bool showCheckbox;
  final bool alwaysShowMobileCheckbox;
  final String? contextHint;
  final double fontSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelect;
  final VoidCallback? onMore;
  final bool tapToShowMenu;
  final void Function(List<XFile> files)? onDropFiles;

  const _FileGridItemHover({
    required this.file,
    required this.isSelected,
    required this.isHighlighted,
    required this.showCheckbox,
    required this.alwaysShowMobileCheckbox,
    required this.contextHint,
    required this.fontSize,
    this.onTap,
    this.onLongPress,
    this.onSelect,
    this.onMore,
    this.tapToShowMenu = false,
    this.onDropFiles,
  });

  @override
  State<_FileGridItemHover> createState() => _FileGridItemHoverState();
}

class _FileGridItemHoverState extends State<_FileGridItemHover> {
  bool _isHovered = false;
  bool _isDropTargetHovered = false;
  Timer? _previewTimer;
  Timer? _previewRemoveTimer;
  OverlayEntry? _previewOverlay;
  ValueNotifier<bool>? _previewVisible;
  final GlobalKey _thumbnailKey = GlobalKey();

  bool get _canPreview =>
      !widget.file.isFolder && FileUtils.isThumbnailableFile(widget.file.name);

  bool get _isDesktopFolderDropTarget =>
      widget.file.isFolder &&
      widget.onDropFiles != null &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void dispose() {
    _previewTimer?.cancel();
    _previewRemoveTimer?.cancel();
    _previewOverlay?.remove();
    _previewVisible?.dispose();
    _previewTimer = null;
    _previewRemoveTimer = null;
    _previewOverlay = null;
    _previewVisible = null;
    super.dispose();
  }

  void _onCardHoverEnter() {
    if (!mounted) return;
    setState(() => _isHovered = true);
  }

  void _onCardHoverExit() {
    if (!mounted) return;
    setState(() => _isHovered = false);
    _cancelPreview();
  }

  void _onPreviewHoverEnter() {
    if (!mounted || !_canPreview) return;

    // The preview trigger is intentionally bound only to the thumbnail area.
    // Hovering the selection circle or the text area must not start a preview.
    _previewTimer?.cancel();
    _previewRemoveTimer?.cancel();

    if (_previewOverlay != null) {
      _previewVisible?.value = true;
      return;
    }

    _previewTimer = Timer(const Duration(seconds: 2), _showPreviewOverlay);
  }

  void _onPreviewHoverExit() {
    _cancelPreview();
  }

  void _cancelPreview() {
    _previewTimer?.cancel();
    _previewTimer = null;

    final visible = _previewVisible;
    final overlay = _previewOverlay;
    if (visible == null || overlay == null) {
      return;
    }

    visible.value = false;
    _previewRemoveTimer?.cancel();
    _previewRemoveTimer = Timer(const Duration(milliseconds: 280), () {
      overlay.remove();
      visible.dispose();
      if (identical(_previewOverlay, overlay)) {
        _previewOverlay = null;
        _previewVisible = null;
      }
      _previewRemoveTimer = null;
    });
  }

  double? _readMetadataNumber(List<String> keys) {
    final metadata = widget.file.metadata;
    if (metadata == null) return null;

    for (final key in keys) {
      final value = metadata[key];
      if (value is num && value > 0) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  double? _previewAspectRatio() {
    // Prefer the real decoded thumbnail ratio. This keeps the hover frame
    // adaptive to the actual image instead of leaving a wide empty rectangle
    // around vertical pictures.
    final cachedRatio = ThumbnailImageSizeCache.aspectRatioFor(widget.file);
    if (cachedRatio != null && cachedRatio > 0) return cachedRatio;

    final width = _readMetadataNumber(const [
      'width',
      'image_width',
      'imageWidth',
      'w',
      'Width',
    ]);
    final height = _readMetadataNumber(const [
      'height',
      'image_height',
      'imageHeight',
      'h',
      'Height',
    ]);

    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  Size _previewSizeFor(Rect thumbnailRect, Size screenSize) {
    final aspectRatio = (_previewAspectRatio() ??
            (thumbnailRect.width > 0 && thumbnailRect.height > 0
                ? thumbnailRect.width / thumbnailRect.height
                : 1.0))
        .clamp(0.28, 3.2)
        .toDouble();

    final maxWidth = (screenSize.width - 24).clamp(180.0, 440.0).toDouble();
    final maxHeight = (screenSize.height - 24).clamp(140.0, 380.0).toDouble();

    var width = (thumbnailRect.width * 1.78).clamp(170.0, maxWidth).toDouble();
    var height = width / aspectRatio;

    final minHeight = (thumbnailRect.height * 1.42).clamp(140.0, maxHeight).toDouble();
    if (height < minHeight) {
      height = minHeight;
      width = height * aspectRatio;
    }

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    if (width > maxWidth) {
      width = maxWidth;
      height = width / aspectRatio;
    }

    return Size(width, height);
  }

  void _showPreviewOverlay() {
    if (!mounted || !_isHovered || !_canPreview || _previewOverlay != null) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final thumbnailRenderObject = _thumbnailKey.currentContext?.findRenderObject();
    if (thumbnailRenderObject is! RenderBox || !thumbnailRenderObject.hasSize) {
      return;
    }

    final thumbnailRect =
        thumbnailRenderObject.localToGlobal(Offset.zero) & thumbnailRenderObject.size;

    final screenSize = MediaQuery.sizeOf(context);
    // The preview should come out of the exact thumbnail image area.
    // It is larger than the card, but still a local hover preview rather than
    // a full-screen dialog.  When image dimensions are available in metadata,
    // size the overlay to that aspect ratio to avoid wide empty shadows around
    // vertical images.
    final previewSize = _previewSizeFor(thumbnailRect, screenSize);
    final previewWidth = previewSize.width;
    final previewHeight = previewSize.height;
    final previewVisible = ValueNotifier<bool>(false);
    final collapsedScale = (thumbnailRect.width / previewWidth).clamp(0.58, 0.84).toDouble();

    _previewRemoveTimer?.cancel();
    _previewVisible = previewVisible;

    _previewOverlay = OverlayEntry(
      builder: (overlayContext) {
        final overlayScreenSize = MediaQuery.sizeOf(overlayContext);
        final idealLeft = thumbnailRect.center.dx - previewWidth / 2;
        final idealTop = thumbnailRect.center.dy - previewHeight / 2;
        final left = idealLeft
            .clamp(8.0, overlayScreenSize.width - previewWidth - 8.0)
            .toDouble();
        final top = idealTop
            .clamp(8.0, overlayScreenSize.height - previewHeight - 8.0)
            .toDouble();

        return Positioned(
          left: left,
          top: top,
          width: previewWidth,
          height: previewHeight,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: previewVisible,
              builder: (context, visible, child) {
                return AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: AnimatedScale(
                    scale: visible ? 1 : collapsedScale,
                    duration: const Duration(milliseconds: 260),
                    curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                    alignment: Alignment.center,
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FullPreviewImage(
                      file: widget.file,
                      contextHint: widget.contextHint,
                      borderRadius: 16,
                    ),
                    if (FileUtils.isVideoFile(widget.file.name))
                      Center(
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.play,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_previewOverlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_previewVisible, previewVisible)) return;
      previewVisible.value = true;
    });
  }

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
      cardBg = colorScheme.primary.withValues(alpha: 0.075);
      border = Border.all(color: colorScheme.primary.withValues(alpha: 0.92), width: 2);
      shadows = [
        BoxShadow(
          color: colorScheme.primary.withValues(alpha: 0.18),
          blurRadius: 18,
          spreadRadius: -5,
          offset: const Offset(0, 8),
        ),
      ];
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
    final showSelectionCircle =
        _isHovered || widget.showCheckbox || widget.isSelected || widget.alwaysShowMobileCheckbox;

    final content = MouseRegion(
      onEnter: (_) => _onCardHoverEnter(),
      onExit: (_) => _onCardHoverExit(),
      child: GestureDetector(
        onTap: widget.tapToShowMenu ? widget.onLongPress : widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: border,
            boxShadow: shadows,
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (_isDesktopFolderDropTarget)
                Positioned.fill(
                  child: _DropHoverFade(
                    visible: _isDropTargetHovered,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: _FolderDropFrame(compact: false),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 图标区：默认保持文件图标/缩略图原位，选择框只在右上角浮现。
                  Expanded(
                    child: _buildIconArea(context),
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
              // Hover / selected selection circle. Keep the icon in the real corner and
              // animate opacity/scale instead of hard inserting/removing it.
              if (_isDesktopFolderDropTarget)
                Positioned.fill(
                  child: _DropHoverFade(
                    visible: _isDropTargetHovered,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: _FolderDropChip(
                        label: '释放上传到此文件夹',
                        compact: false,
                      ),
                    ),
                  ),
                ),
              if (widget.onSelect != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: MouseRegion(
                    onEnter: (_) => _cancelPreview(),
                    child: IgnorePointer(
                      ignoring: !showSelectionCircle,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        opacity: showSelectionCircle ? 1 : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          scale: widget.isSelected ? 1.0 : 0.88,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onSelect,
                              customBorder: const CircleBorder(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surface.withValues(alpha: 0.94),
                                  border: Border.all(
                                    color: widget.isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline.withValues(alpha: 0.48),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.isSelected
                                          ? colorScheme.primary.withValues(alpha: 0.24)
                                          : Colors.black.withValues(alpha: 0.10),
                                      blurRadius: widget.isSelected ? 8 : 4,
                                      spreadRadius: widget.isSelected ? -1 : -2,
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
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: widget.isSelected
                                      ? const Icon(
                                          LucideIcons.check,
                                          key: ValueKey('selected'),
                                          color: Colors.white,
                                          size: 13,
                                        )
                                      : const SizedBox(key: ValueKey('empty')),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!_isDesktopFolderDropTarget) {
      return content;
    }

    return DropTarget(
      onDragEntered: (_) {
        _cancelPreview();
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
    final isThumbnailable =
        !file.isFolder && FileUtils.isThumbnailableFile(file.name);

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

    return MouseRegion(
      opaque: true,
      onEnter: (_) => _onPreviewHoverEnter(),
      onExit: (_) => _onPreviewHoverExit(),
      child: KeyedSubtree(
        key: _thumbnailKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailImage(
              file: file,
              contextHint: widget.contextHint,
              borderRadius: 10,
            ),
        if (FileUtils.isVideoFile(file.name))
          Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                LucideIcons.play,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        if (FileUtils.isPsdFile(file.name))
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PSD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
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

class _FolderDropFrame extends StatelessWidget {
  final bool compact;

  const _FolderDropFrame({required this.compact});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = compact ? 8.0 : 10.0;
    const borderWidth = 1.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
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

class _FolderDropChip extends StatelessWidget {
  final String label;
  final bool compact;

  const _FolderDropChip({
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.94),
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
              size: compact ? 13 : 15,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
