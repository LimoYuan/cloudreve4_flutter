import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/upload_manager_provider.dart';
import '../providers/file_manager_provider.dart';
import 'toast_helper.dart';

/// 显示上传对话框
void showUploadDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) => const _UploadDialogContent(),
  );
}

class _UploadDialogContent extends StatelessWidget {
  const _UploadDialogContent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildFileSelectionButtons(context),
          ),
          _buildViewTasksButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '选择要上传的文件',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectionButtons(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          _buildUploadButton(
            context,
            icon: Icons.photo_library,
            label: '选择图片',
            type: FileType.image,
          ),
          const SizedBox(height: 12),
          _buildUploadButton(
            context,
            icon: Icons.video_library,
            label: '选择视频',
            type: FileType.video,
          ),
          const SizedBox(height: 12),
          _buildUploadButton(
            context,
            icon: Icons.attach_file,
            label: '选择所有文件',
            type: FileType.any,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required FileType type,
  }) {
    return FilledButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: () => _pickFiles(context, type),
      style: FilledButton.styleFrom(
        minimumSize: const Size(200, 50),
      ),
    );
  }

  Widget _buildViewTasksButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.list),
          label: const Text('查看上传任务'),
          onPressed: () {
            Navigator.of(context).pop();
            showUploadDialogWidget(context);
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 50),
          ),
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

      // 标记应该显示上传对话框
      uploadManager.markShouldShowDialog();

      await uploadManager.startUpload(files, fileManager.currentPath);

      if (context.mounted) {
        showUploadDialogWidget(context);
      }
    } catch (e) {
      if (!context.mounted) return;
      ToastHelper.failure('选择文件失败: $e');
    }
  }
}
