import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:cloudreve4_flutter/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/file_manager_provider.dart';
import 'folder_picker.dart';
import 'glassmorphism_container.dart';
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
      try {
        await FileService().deleteFiles(uris: [file.path]);
        if (context.mounted) {
          ToastHelper.success('删除成功');
          await fileManager.loadFiles();
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.failure('删除失败: $e');
        }
      }
    }
  }

  /// 显示移动/复制文件对话框
  static Future<void> showMoveDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
    bool copy,
  ) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy ? '复制文件' : '移动文件'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: FolderPicker(
            currentPath: fileManager.currentPath,
            onFolderSelected: (selectedPath) async {
              Navigator.of(dialogContext).pop();
              try {
                await FileService().moveFiles(
                  uris: [file.path],
                  dst: selectedPath,
                  copy: copy,
                );
                if (context.mounted) {
                  ToastHelper.success(copy ? '复制成功' : '移动成功');
                  await fileManager.loadFiles();
                }
              } catch (e) {
                if (context.mounted) {
                  ToastHelper.failure('${copy ? '复制' : '移动'}失败: $e');
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
  ) async {
    final passwordController = TextEditingController();
    final expireDaysController = TextEditingController(text: '7');
    bool isPrivate = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('创建分享'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '文件名',
                        prefixIcon: Icon(Icons.description),
                      ),
                      controller: TextEditingController(text: file.name),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('密码保护'),
                      subtitle: const Text('需要密码才能访问'),
                      value: isPrivate,
                      onChanged: (value) {
                        setState(() {
                          isPrivate = value;
                        });
                      },
                    ),
                    if (isPrivate)
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: '分享密码',
                          hintText: '留空则自动生成',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: expireDaysController,
                      decoration: const InputDecoration(
                        labelText: '有效期（天）',
                        hintText: '留空则永久有效',
                        prefixIcon: Icon(Icons.timer),
                        suffixText: '天',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('创建'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final expireDaysText = expireDaysController.text.trim();
      final expireDays = expireDaysText.isEmpty
          ? null
          : int.tryParse(expireDaysText);
      final expireSeconds = expireDays != null
          ? expireDays * 24 * 60 * 60
          : null;

      try {
        final shareUrl = await ShareService().createShare(
          uri: file.path,
          isPrivate: isPrivate,
          password: isPrivate
              ? (passwordController.text.isEmpty ? null : passwordController.text)
              : null,
          expire: expireSeconds,
        );

        if (context.mounted) {
          ToastHelper.success('分享创建成功');
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('分享链接'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shareUrl, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制到剪贴板'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.of(dialogContext).pop();
                        ToastHelper.success('已复制到剪贴板');
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.failure('分享创建失败: $e');
        }
      }
    }
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
