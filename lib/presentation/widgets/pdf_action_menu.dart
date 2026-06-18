import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/file_model.dart';
import '../../router/app_router.dart';
import '../../services/file_service.dart';
import 'toast_helper.dart';

/// PDF 文件点击菜单：原生预览 / Open Externally / Copy URL。
///
/// 用法：`await PdfActionMenu.show(context, file)`
/// 历史版本场景传 `entityId`，原生预览路由会带上 entityId 走对应版本。
class PdfActionMenu {
  PdfActionMenu._();

  static Future<void> show(
    BuildContext context,
    FileModel file, {
    String? entityId,
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
                      color: Color(0xFFEF4444),
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
                leading: const Icon(LucideIcons.bookOpen),
                title: const Text('原生预览'),
                subtitle: const Text('使用应用内 PDF 预览器打开'),
                onTap: () => Navigator.of(sheetCtx).pop('inline'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open Externally'),
                subtitle: const Text('调用系统默认 PDF 阅读器'),
                onTap: () => Navigator.of(sheetCtx).pop('external'),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy URL'),
                subtitle: const Text('复制临时下载链接到剪贴板'),
                onTap: () => Navigator.of(sheetCtx).pop('copy'),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case 'inline':
        final args = entityId == null
            ? file
            : <String, dynamic>{'file': file, 'entityId': entityId};
        Navigator.of(context).pushNamed(RouteNames.pdfPreview, arguments: args);
        break;
      case 'external':
        await _openExternally(context, file, entityId);
        break;
      case 'copy':
        await _copyUrl(context, file, entityId);
        break;
    }
  }

  static Future<String?> _resolveUrl(
    BuildContext context,
    FileModel file,
    String? entityId,
  ) async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [file.relativePath],
        download: false,
        entity: entityId,
      );
      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isEmpty) return null;
      final first = urls.first as Map<String, dynamic>;
      return first['url']?.toString();
    } catch (e) {
      if (context.mounted) ToastHelper.failure('获取 PDF 链接失败：$e');
      return null;
    }
  }

  static Future<void> _openExternally(
    BuildContext context,
    FileModel file,
    String? entityId,
  ) async {
    final url = await _resolveUrl(context, file, entityId);
    if (url == null || url.isEmpty) {
      if (context.mounted) ToastHelper.failure('无法获取 PDF 链接');
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) ToastHelper.failure('无法打开 PDF');
  }

  static Future<void> _copyUrl(
    BuildContext context,
    FileModel file,
    String? entityId,
  ) async {
    final url = await _resolveUrl(context, file, entityId);
    if (url == null || url.isEmpty) {
      if (context.mounted) ToastHelper.failure('无法获取 PDF 链接');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) ToastHelper.success('PDF URL 已复制');
  }
}
