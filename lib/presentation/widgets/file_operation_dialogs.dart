import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:cloudreve4_flutter/services/file_service.dart';
import 'package:cloudreve4_flutter/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/file_manager_provider.dart';
import 'folder_picker.dart';

/// 文件操作对话框工具类
class FileOperationDialogs {
  /// 显示创建文件夹对话框
  static Future<void> showCreateDialog(
    BuildContext context,
    FileManagerProvider fileManager,
  ) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '文件夹名称',
            prefixIcon: Icon(Icons.folder),
          ),
          autofocus: true,
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
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      final error = await fileManager.createFolder(controller.text);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建文件夹失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件夹创建成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 显示重命名对话框
  static Future<void> showRenameDialog(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final controller = TextEditingController(text: file.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '新名称',
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      await fileManager.renameFile(file.path, controller.text);
    }
  }

  /// 显示删除确认对话框（多个文件）
  static Future<void> showDeleteConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
    List<String> filePaths,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除这 ${filePaths.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final error = await fileManager.deleteSelectedFiles();
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 显示删除确认对话框（单个文件）
  static Future<void> showDeleteSingleConfirmation(
    BuildContext context,
    FileManagerProvider fileManager,
    FileModel file,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除确认'),
        content: Text('确定删除文件 "${file.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FileService().deleteFiles(uris: [file.path]);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除成功'),
              backgroundColor: Colors.green,
            ),
          );
          await fileManager.loadFiles();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(copy ? '复制成功' : '移动成功'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await fileManager.loadFiles();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${copy ? '复制' : '移动'}失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('分享创建成功'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: shareUrl),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板'),
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分享创建失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
