import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/models/file_model.dart';
import '../../router/app_router.dart';

/// 文本/代码文件点击菜单：仅预览 / 编辑器。
///
/// 用法：`await TextActionMenu.show(context, file)`
class TextActionMenu {
  TextActionMenu._();

  static Future<void> show(
    BuildContext context,
    FileModel file, {
    String previewRoute = RouteNames.documentPreview,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.fileText,
                      size: 20,
                      color: Color(0xFF06B6D4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetCtx)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.eye),
                title: const Text('仅预览'),
                subtitle: const Text('只读查看文件内容'),
                onTap: () => Navigator.of(sheetCtx).pop('preview'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.edit3),
                title: const Text('编辑器'),
                subtitle: const Text('在编辑器中打开并修改'),
                onTap: () => Navigator.of(sheetCtx).pop('editor'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case 'preview':
        Navigator.of(context).pushNamed(
          previewRoute,
          arguments: file,
        );
        break;
      case 'editor':
        Navigator.of(context).pushNamed(
          RouteNames.documentEditor,
          arguments: file,
        );
        break;
    }
  }
}
