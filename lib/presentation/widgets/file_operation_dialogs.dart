import 'dart:io';

import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/file_manager_provider.dart';
import 'folder_picker.dart';
import 'glassmorphism_container.dart';
import 'share/share_dialog.dart';
import 'toast_helper.dart';

/// 文件操作对话框工具类
class FileOperationDialogs {
  /// 显示创建文件夹对话框（毛玻璃风格）
  static Future<void> showCreateDialog(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    final controller = TextEditingController();

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '创建文件夹',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).drive(Tween(begin: 0.92, end: 1.0));
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).drive(Tween(begin: 0.0, end: 1.0));
        return ScaleTransition(
          scale: scaleAnim,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth >= 600 ? 400.0 : screenWidth - 48.0;
        return Center(
          child: SizedBox(
            width: dialogWidth,
            child: GlassmorphismContainer(
              borderRadius: 16,
              sigmaX: 20,
              sigmaY: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTitle(context, LucideIcons.folderPlus, '创建文件夹'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: '文件夹名称',
                            prefixIcon: const Icon(LucideIcons.folder, size: 20),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: (_) => Navigator.of(context).pop(true),
                        ),
                      ),
                      _buildDialogActions(
                        context,
                        onCancel: () => Navigator.of(context).pop(false),
                        onConfirm: () => Navigator.of(context).pop(true),
                        confirmLabel: '创建',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      final error = await fileManager.createFolder(controller.text);
      if (error != null && context.mounted) {
        ToastHelper.failure('创建文件夹失败: $error');
      } else if (context.mounted) {
        ToastHelper.success('文件夹创建成功');
      }
    }
  }

  /// 显示重命名对话框（毛玻璃风格）
  static Future<void> showRenameDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final controller = TextEditingController(text: file.name);

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '重命名',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).drive(Tween(begin: 0.92, end: 1.0));
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).drive(Tween(begin: 0.0, end: 1.0));
        return ScaleTransition(
          scale: scaleAnim,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth >= 600 ? 400.0 : screenWidth - 48.0;

        return Center(
          child: SizedBox(
            width: dialogWidth,
            child: GlassmorphismContainer(
              borderRadius: 16,
              sigmaX: 20,
              sigmaY: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTitle(context, LucideIcons.pencil, '重命名'),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: '新名称',
                            prefixIcon: const Icon(LucideIcons.edit3, size: 20),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: (_) => Navigator.of(context).pop(true),
                        ),
                      ),
                      _buildDialogActions(
                        context,
                        onCancel: () => Navigator.of(context).pop(false),
                        onConfirm: () => Navigator.of(context).pop(true),
                        confirmLabel: '确定',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      await fileManager.renameFile(file.path, controller.text);
    }
  }

  /// 显示删除确认对话框（多个文件，毛玻璃风格）
  static Future<void> showDeleteConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
    List<String> filePaths,
  ) async {
    final confirmed = await _showConfirmDialog(
      context,
      icon: LucideIcons.trash2,
      title: '删除确认',
      message: '确定删除这 ${filePaths.length} 个文件吗？',
      confirmLabel: '删除',
      isDestructive: true,
    );

    if (confirmed == true) {
      final error = await fileManager.deleteSelectedFiles();
      if (error != null && context.mounted) {
        ToastHelper.failure('删除失败: $error');
      } else if (context.mounted) {
        ToastHelper.success('删除成功');
      }
    }
  }

  /// 显示删除确认对话框（单个文件，毛玻璃风格）
  static Future<void> showDeleteSingleConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final confirmed = await _showConfirmDialog(
      context,
      icon: LucideIcons.trash2,
      title: '删除确认',
      message: '确定删除文件 "${file.name}" 吗？',
      confirmLabel: '删除',
      isDestructive: true,
    );

    if (confirmed == true) {
      final error = await fileManager.deleteFile(file.path);
      if (context.mounted) {
        if (error != null) {
          ToastHelper.failure('删除失败: $error');
        } else {
          ToastHelper.success('删除成功');
        }
      }
    }
  }

  /// 显示移动/复制文件对话框
  static void showMoveDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
    bool copy,
  ) {
    _showMoveDialog(context, fileManager, [file.path], copy);
  }

  /// 显示多选移动/复制文件对话框
  static void showBatchMoveDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    List<String> uris,
    bool copy,
  ) {
    _showMoveDialog(context, fileManager, uris, copy);
  }

  static void _showMoveDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    List<String> uris,
    bool copy,
  ) {
    final title = uris.length == 1
        ? (copy ? '复制文件' : '移动文件')
        : (copy ? '复制 ${uris.length} 个文件' : '移动 ${uris.length} 个文件');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: 400,
          child: FolderPicker(
            currentPath: fileManager.currentPath,
            onFolderSelected: (selectedPath) async {
              Navigator.of(dialogContext).pop();
              final error = await fileManager.moveFiles(
                uris,
                selectedPath,
                copy: copy,
              );
              if (context.mounted) {
                if (error != null) {
                  ToastHelper.failure('${copy ? '复制' : '移动'}失败: $error');
                } else {
                  ToastHelper.success(copy ? '复制成功' : '移动成功');
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示创建分享对话框
  static Future<void> showShareDialog(
    BuildContext context,
    FileModel file,
  ) {
    // 委托给 share/share_dialog.dart 中的顶层函数
    return showShareCreationDialog(context, file);
  }

  static Future<void> showExportDirectoryDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    List<FileModel> folders,
  ) async {
    if (folders.isEmpty) {
      ToastHelper.info('请选择文件夹后再导出目录');
      return;
    }

    final defaultExportDir = await _defaultExportDir();
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final firstFolder = folders.first;
    final exportDirController = TextEditingController(text: defaultExportDir);
    final fileNameController = TextEditingController(
      text: folders.length == 1
          ? '${_sanitizeFileName(firstFolder.name)}_文件目录'
          : '选中文件夹_文件目录',
    );
    var treeStyle = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            final colorScheme = Theme.of(dialogContext).colorScheme;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 18, 18, 14),
                      child: Row(
                        children: [
                          Text(
                            '导出文件目录',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(false),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.45),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 22, 26, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildExportDialogRow(
                            context: dialogContext,
                            label: '导出文件夹',
                            help: true,
                            child: _buildReadonlyExportField(
                              dialogContext,
                              value: folders.length == 1
                                  ? _formatExportCloudPath(firstFolder)
                                  : '已选择 ${folders.length} 个文件夹',
                              leading: const Icon(
                                Icons.folder,
                                color: Color(0xFFFFB923),
                              ),
                              trailing: const Icon(Icons.folder_open_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildExportDialogRow(
                            context: dialogContext,
                            label: '存储为',
                            child: TextField(
                              controller: fileNameController,
                              decoration: InputDecoration(
                                isDense: true,
                                suffixText: '.txt',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildExportDialogRow(
                            context: dialogContext,
                            label: '存储位置',
                            child: TextField(
                              controller: exportDirController,
                              readOnly: true,
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.folder_outlined),
                                  onPressed: () async {
                                    final selected = await FilePicker.platform
                                        .getDirectoryPath();
                                    if (selected != null &&
                                        selected.isNotEmpty) {
                                      setState(
                                        () => exportDirController.text = selected,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '导出目录样式',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildExportStyleCard(
                                  context: dialogContext,
                                  selected: treeStyle,
                                  title: '目录树',
                                  lines: const [
                                    '我的网盘',
                                    '├  文件夹名称 1',
                                    '│  ├  文件夹名称 1-1',
                                    '│  └  文件夹名称 1-2',
                                    '└  文件夹名称 2',
                                  ],
                                  onTap: () => setState(() => treeStyle = true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildExportStyleCard(
                                  context: dialogContext,
                                  selected: !treeStyle,
                                  title: '目录列表',
                                  lines: const [
                                    '我的网盘/文件夹名称/文件夹名称 1',
                                    '我的网盘/文件夹名称/文件夹名称 1-1',
                                    '我的网盘/文件夹名称/文件夹名称 1-2',
                                    '我的网盘/文件夹名称 2/文件夹名称 1',
                                    '我的网盘/文件夹名称 3/文件夹名称 1',
                                  ],
                                  onTap: () => setState(() => treeStyle = false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.45),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(false),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 42,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 18),
                          FilledButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 46,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text('导出'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final exportDir = exportDirController.text.trim();
    final rawName = fileNameController.text.trim().isEmpty
        ? '文件目录'
        : fileNameController.text.trim();
    final outputName = '${_sanitizeFileName(rawName)}.txt';
    final outputPath =
        '${exportDir.replaceAll(RegExp(r'[\\/]+$'), '')}'
        '${Platform.pathSeparator}$outputName';

    try {
      ToastHelper.info('正在导出目录...');
      final content = await _buildDirectoryExportContent(
        folders,
        treeStyle: treeStyle,
      );
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(content);
      if (context.mounted) {
        ToastHelper.success('目录已导出：$outputPath');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.failure('导出目录失败：$e');
      }
    }
  }

  static Widget _buildExportDialogRow({
    required BuildContext context,
    required String label,
    required Widget child,
    bool help = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 132,
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (help) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.help_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  static Widget _buildReadonlyExportField(
    BuildContext context, {
    required String value,
    Widget? leading,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  static Widget _buildExportStyleCard({
    required BuildContext context,
    required bool selected,
    required String title,
    required List<String> lines,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.06)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : theme.dividerColor.withValues(alpha: 0.55),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? colorScheme.primary : theme.hintColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<String> _buildDirectoryExportContent(
    List<FileModel> folders, {
    required bool treeStyle,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Cloudreve 文件目录导出');
    buffer.writeln('导出时间：${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (var i = 0; i < folders.length; i++) {
      final folder = folders[i];
      if (treeStyle) {
        buffer.writeln(folder.name);
        await _appendDirectoryTree(buffer, folder.path, '');
      } else {
        await _appendDirectoryList(
          buffer,
          folder.path,
          _formatExportCloudPath(folder),
        );
      }
      if (i != folders.length - 1) buffer.writeln();
    }

    return buffer.toString();
  }

  static Future<void> _appendDirectoryTree(
    StringBuffer buffer,
    String uri,
    String prefix, {
    int depth = 0,
  }) async {
    if (depth > 20) return;
    final children = await _listChildren(uri);
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final last = i == children.length - 1;
      final connector = last ? '└── ' : '├── ';
      buffer.writeln('$prefix$connector${child.name}${child.isFolder ? '/' : ''}');
      if (child.isFolder) {
        await _appendDirectoryTree(
          buffer,
          child.path,
          '$prefix${last ? '    ' : '│   '}',
          depth: depth + 1,
        );
      }
    }
  }

  static Future<void> _appendDirectoryList(
    StringBuffer buffer,
    String uri,
    String displayPath, {
    int depth = 0,
  }) async {
    if (depth > 20) return;
    final children = await _listChildren(uri);
    for (final child in children) {
      final childPath = '$displayPath/${child.name}';
      buffer.writeln(childPath);
      if (child.isFolder) {
        await _appendDirectoryList(
          buffer,
          child.path,
          childPath,
          depth: depth + 1,
        );
      }
    }
  }

  static Future<List<FileModel>> _listChildren(String uri) async {
    final response = await FileService().listFiles(
      uri: uri,
      pageSize: 500,
      orderBy: 'name',
      orderDirection: 'asc',
    );
    final files = response['files'] as List<dynamic>? ?? const [];
    final models = files
        .whereType<Map<String, dynamic>>()
        .map(FileModel.fromJson)
        .toList();
    models.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return models;
  }

  static String _formatExportCloudPath(FileModel folder) {
    final rel = folder.relativePath;
    if (rel == '/' || rel.isEmpty) return '我的网盘/全部文件';
    final parts = rel.split('/').where((p) => p.isNotEmpty).toList();
    return '我的网盘/全部文件/${parts.join('/')}';
  }

  static Future<String> _defaultExportDir() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads.path;
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.isNotEmpty) {
      return '$profile${Platform.pathSeparator}Downloads';
    }
    return Directory.current.path;
  }

  static String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? '文件目录' : sanitized;
  }

  // ─── 内部工具方法 ───

  static Widget _buildDialogTitle(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogActions(
    BuildContext context, {
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? colorScheme.error : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).drive(Tween(begin: 0.92, end: 1.0));
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).drive(Tween(begin: 0.0, end: 1.0));
        return ScaleTransition(
          scale: scaleAnim,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth >= 600 ? 400.0 : screenWidth - 48.0;
        final theme = Theme.of(context);

        return Center(
          child: SizedBox(
            width: dialogWidth,
            child: GlassmorphismContainer(
              borderRadius: 16,
              sigmaX: 20,
              sigmaY: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTitle(context, icon, title),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        child: Text(message, style: theme.textTheme.bodyMedium),
                      ),
                      _buildDialogActions(
                        context,
                        onCancel: () => Navigator.of(context).pop(false),
                        onConfirm: () => Navigator.of(context).pop(true),
                        confirmLabel: confirmLabel,
                        isDestructive: isDestructive,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
