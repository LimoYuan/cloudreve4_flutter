import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/upload_manager_provider.dart';
import '../providers/file_manager_provider.dart';
import '../providers/navigation_provider.dart';
import 'glassmorphism_container.dart';
import 'toast_helper.dart';

/// 显示上传对话框（毛玻璃风格）
void showUploadDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '上传',
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
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _UploadDialogContent(),
  );
}

class _UploadDialogContent extends StatelessWidget {
  const _UploadDialogContent();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth >= 600 ? 420.0 : screenWidth - 48.0;

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
                  _buildHeader(context),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: _buildFileSelectionButtons(context),
                  ),
                  const Divider(height: 1),
                  _buildViewTasksButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Icon(LucideIcons.uploadCloud, size: 20, color: theme.hintColor),
          const SizedBox(width: 10),
          Text(
            '选择要上传的文件',
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

  Widget _buildFileSelectionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildUploadOption(
          context,
          icon: LucideIcons.image,
          label: '选择图片',
          description: 'JPG, PNG, GIF, WebP 等',
          color: Colors.purple.shade400,
          onTap: () => _pickFiles(context, FileType.image),
        ),
        const SizedBox(height: 12),
        _buildUploadOption(
          context,
          icon: LucideIcons.video,
          label: '选择视频',
          description: 'MP4, AVI, MKV 等',
          color: Colors.orange.shade400,
          onTap: () => _pickFiles(context, FileType.video),
        ),
        const SizedBox(height: 12),
        _buildUploadOption(
          context,
          icon: LucideIcons.file,
          label: '选择所有文件',
          description: '任意类型文件',
          color: colorScheme.primary,
          onTap: () => _pickFiles(context, FileType.any),
        ),
      ],
    );
  }

  Widget _buildUploadOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTasksButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.list, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '查看上传任务',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles(BuildContext context, FileType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) {
        ToastHelper.warning('未选择文件');
        return;
      }

      final files = <File>[];
      for (final file in result.files) {
        if (file.path != null) {
          files.add(File(file.path!));
        }
      }

      if (files.isEmpty) {
        if (!context.mounted) return;
        ToastHelper.error('无法获取文件路径');
        return;
      }

      final uploadManager = Provider.of<UploadManagerProvider>(
        context,
        listen: false,
      );
      final fileManager = Provider.of<FileManagerProvider>(
        context,
        listen: false,
      );

      uploadManager.markShouldShowDialog();
      await uploadManager.startUpload(files, fileManager.currentPath);

      if (context.mounted) {
        ToastHelper.info('上传已开始，查看任务页');
      }
    } catch (e) {
      if (!context.mounted) return;
      ToastHelper.failure('选择文件失败: $e');
    }
  }
}
