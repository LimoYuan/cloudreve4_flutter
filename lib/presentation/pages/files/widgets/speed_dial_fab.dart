import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SpeedDialFab extends StatefulWidget {
  final VoidCallback onSearch;
  final VoidCallback onUpload;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateFile;
  final VoidCallback onRemoteDownload;
  final VoidCallback onToggleViewType;
  final bool isListView;

  const SpeedDialFab({
    super.key,
    required this.onSearch,
    required this.onUpload,
    required this.onCreateFolder,
    required this.onCreateFile,
    required this.onRemoteDownload,
    required this.onToggleViewType,
    required this.isListView,
  });

  @override
  State<SpeedDialFab> createState() => SpeedDialFabState();
}

class SpeedDialFabState extends State<SpeedDialFab> {
  bool _isFabVisible = true;
  bool _isFabExpanded = false;
  Timer? _fabShowTimer;

  @override
  void dispose() {
    _fabShowTimer?.cancel();
    super.dispose();
  }

  void hide() {
    _fabShowTimer?.cancel();
    if (_isFabVisible) {
      setState(() {
        _isFabVisible = false;
        _isFabExpanded = false;
      });
    }
  }

  void scheduleShow() {
    _fabShowTimer?.cancel();
    _fabShowTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && !_isFabVisible) {
        setState(() => _isFabVisible = true);
      }
    });
  }

  bool onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      hide();
    } else if (notification is ScrollEndNotification) {
      scheduleShow();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSlide(
      offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _isFabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildSubItem(
              index: 0,
              icon: LucideIcons.search,
              label: '搜索',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onSearch,
            ),
            _buildSubItem(
              index: 1,
              icon: LucideIcons.upload,
              label: '上传',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onUpload,
            ),
            _buildSubItem(
              index: 2,
              icon: LucideIcons.folderPlus,
              label: '新建文件夹',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onCreateFolder,
            ),
            _buildSubItem(
              index: 3,
              icon: Icons.note_add_outlined,
              label: '新建文件',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onCreateFile,
            ),
            _buildSubItem(
              index: 4,
              icon: LucideIcons.download,
              label: '离线下载',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onRemoteDownload,
            ),
            _buildSubItem(
              index: 5,
              icon: widget.isListView ? LucideIcons.layoutGrid : LucideIcons.list,
              label: widget.isListView ? '网格视图' : '列表视图',
              isDark: isDark,
              colorScheme: colorScheme,
              onTap: widget.onToggleViewType,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: AnimatedScale(
                scale: _isFabExpanded ? 1.0 : 1.08,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _buildFabButton(
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => setState(() => _isFabExpanded = !_isFabExpanded),
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      LucideIcons.plus,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final staggerDelay = Duration(milliseconds: 50 * index);

    return AnimatedSlide(
      offset: _isFabExpanded ? Offset.zero : const Offset(0, 1.2),
      duration: const Duration(milliseconds: 250) + staggerDelay,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isFabExpanded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200) + staggerDelay,
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _isFabExpanded ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 250) + staggerDelay,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFabButton(
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () {
                    setState(() => _isFabExpanded = false);
                    onTap();
                  },
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabButton({
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required Widget child,
  }) {
    const size = 44.0;
    const radius = 22.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
