import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/utils/app_logger.dart';

/// 文件菜单选项
enum FileMenuAction {
  select,
  download,
  openInBrowser,
  rename,
  move,
  copy,
  share,
  info,
  delete,
  restore,
}

/// 显示文件菜单
Future<FileMenuAction?> showFileMenu({
  required BuildContext context,
  required bool hasSelect,
  required bool hasDownload,
  required bool hasOpenInBrowser,
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

  final offset = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;

  // 计算菜单位置，居中显示
  final centerX = offset.dx + size.width / 2;
  final position = RelativeRect.fromLTRB(
    centerX - 120, // 菜单宽度约240，居中显示
    offset.dy + size.height / 2,
    centerX + 120,
    offset.dy + size.height / 2,
  );

  AppLogger.d('showFileMenu: widget offset: $offset, size: $size, center: $centerX');

  final result = await showMenu<FileMenuAction>(
    context: context,
    position: position,
    items: <PopupMenuEntry<FileMenuAction>>[
      if (hasSelect)
        const PopupMenuItem(
          value: FileMenuAction.select,
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 12),
              Text('选择'),
            ],
          ),
        ),
      if (hasDownload)
        const PopupMenuItem(
          value: FileMenuAction.download,
          child: Row(
            children: [
              Icon(Icons.download, size: 20),
              SizedBox(width: 12),
              Text('下载'),
            ],
          ),
        ),
      if (hasOpenInBrowser)
        const PopupMenuItem(
          value: FileMenuAction.openInBrowser,
          child: Row(
            children: [
              Icon(Icons.open_in_browser, size: 20),
              SizedBox(width: 12),
              Text('在浏览器中打开'),
            ],
          ),
        ),
      if (hasRename)
        const PopupMenuItem(
          value: FileMenuAction.rename,
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('重命名'),
            ],
          ),
        ),
      if (hasMove)
        const PopupMenuItem(
          value: FileMenuAction.move,
          child: Row(
            children: [
              Icon(Icons.drive_file_move, size: 20),
              SizedBox(width: 12),
              Text('移动'),
            ],
          ),
        ),
      if (hasCopy)
        const PopupMenuItem(
          value: FileMenuAction.copy,
          child: Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 12),
              Text('复制'),
            ],
          ),
        ),
      if (hasShare)
        const PopupMenuItem(
          value: FileMenuAction.share,
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 12),
              Text('分享'),
            ],
          ),
        ),
      if (hasInfo)
        const PopupMenuItem(
          value: FileMenuAction.info,
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 20),
              SizedBox(width: 12),
              Text('详情'),
            ],
          ),
        ),
      if (hasDelete)
        const PopupMenuItem(
          value: FileMenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      if (hasRestore)
        const PopupMenuItem(
          value: FileMenuAction.restore,
          child: Row(
            children: [
              Icon(Icons.restore, size: 20),
              SizedBox(width: 12),
              Text('恢复'),
            ],
          ),
        ),
    ],
  );

  AppLogger.d('showFileMenu: selected value: $result');
  return result;
}
