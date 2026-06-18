import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/utils/app_logger.dart';

/// 文件菜单选项
enum FileMenuAction {
  select,
  download,
  openInBrowser,
  openInCloudreveApp,
  rename,
  move,
  copy,
  share,
  info,
  delete,
  restore,
}

/// 显示文件菜单。
///
/// 桌面端使用一个自定义 hover-dismiss 菜单：鼠标移出菜单区域且未选择操作时自动关闭，
/// 避免右键后长菜单残留在文件列表上。移动端/触屏仍然可以通过点击外部关闭。
Future<FileMenuAction?> showFileMenu({
  required BuildContext context,
  required bool hasSelect,
  required bool hasDownload,
  required bool hasOpenInBrowser,
  bool hasOpenInCloudreveApp = false,
  required bool hasRename,
  required bool hasMove,
  required bool hasCopy,
  required bool hasShare,
  required bool hasDelete,
  required bool hasRestore,
  bool hasInfo = false,
}) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    AppLogger.d('showFileMenu: renderBox is null');
    return null;
  }

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    AppLogger.d('showFileMenu: overlay is null');
    return null;
  }

  final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final size = renderBox.size;
  final centerX = offset.dx + size.width / 2;
  final top = offset.dy + size.height / 2;

  AppLogger.d('showFileMenu: widget offset: $offset, size: $size, center: $centerX');

  final items = <_FileMenuItem>[
    if (hasSelect)
      _FileMenuItem(FileMenuAction.select, Icons.check_circle_outline, '选择'),
    if (hasDownload)
      _FileMenuItem(FileMenuAction.download, Icons.download, '下载'),
    if (hasOpenInBrowser)
      _FileMenuItem(FileMenuAction.openInBrowser, Icons.open_in_browser, '在浏览器中打开'),
    if (hasOpenInCloudreveApp)
      _FileMenuItem(FileMenuAction.openInCloudreveApp, Icons.web_asset, '在 Cloudreve 中打开'),
    if (hasRename)
      _FileMenuItem(FileMenuAction.rename, Icons.edit, '重命名'),
    if (hasMove)
      _FileMenuItem(FileMenuAction.move, Icons.drive_file_move, '移动'),
    if (hasCopy)
      _FileMenuItem(FileMenuAction.copy, Icons.copy, '复制'),
    if (hasShare)
      _FileMenuItem(FileMenuAction.share, Icons.share, '分享'),
    if (hasInfo)
      _FileMenuItem(FileMenuAction.info, LucideIcons.info, '详情'),
    if (hasDelete)
      _FileMenuItem(FileMenuAction.delete, Icons.delete, '删除', isDanger: true),
    if (hasRestore)
      _FileMenuItem(FileMenuAction.restore, Icons.restore, '恢复'),
  ];

  if (items.isEmpty) return null;

  final result = await showGeneralDialog<FileMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.sizeOf(dialogContext).width;
      const menuWidth = 240.0;
      final left = (centerX - menuWidth / 2).clamp(8.0, screenWidth - menuWidth - 8.0);

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: MouseRegion(
              onExit: (_) {
                final navigator = Navigator.of(dialogContext);
                if (navigator.canPop()) {
                  navigator.pop();
                }
              },
              child: FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero)
                      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: Material(
                    color: Theme.of(dialogContext).colorScheme.surface,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in items)
                            _FileMenuTile(
                              item: item,
                              onTap: () => Navigator.of(dialogContext).pop(item.action),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  AppLogger.d('showFileMenu: selected value: $result');
  return result;
}

class _FileMenuItem {
  final FileMenuAction action;
  final IconData icon;
  final String label;
  final bool isDanger;

  const _FileMenuItem(this.action, this.icon, this.label, {this.isDanger = false});
}

class _FileMenuTile extends StatelessWidget {
  final _FileMenuItem item;
  final VoidCallback onTap;

  const _FileMenuTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = item.isDanger ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
