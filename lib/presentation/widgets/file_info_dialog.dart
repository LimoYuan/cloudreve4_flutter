import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/file_icon_utils.dart';
import '../../services/file_service.dart';
import 'toast_helper.dart';

/// 文件/文件夹详情（右侧抽屉）
class FileInfoPanel extends StatefulWidget {
  final FileModel file;
  const FileInfoPanel({super.key, required this.file});

  /// 在指定 context 的 Scaffold 上打开右侧抽屉
  static void show(BuildContext context, FileModel file) {
    Scaffold.of(context).openEndDrawer();
  }

  @override
  State<FileInfoPanel> createState() => _FileInfoPanelState();
}

class _FileInfoPanelState extends State<FileInfoPanel> {
  FileInfoModel? _fileInfo;
  bool _isLoading = true;
  bool _isCalculatingFolder = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFileInfo();
  }

  Future<void> _loadFileInfo() async {
    try {
      final response = await FileService().getFileInfo(
        uri: widget.file.relativePath,
        folderSummary: false,
      );
      if (mounted) {
        setState(() {
          _fileInfo = FileInfoModel.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateFolderSize() async {
    setState(() => _isCalculatingFolder = true);
    try {
      final response = await FileService().getFileInfo(
        uri: widget.file.relativePath,
        folderSummary: true,
      );
      if (mounted) {
        setState(() {
          _fileInfo = FileInfoModel.fromJson(response);
          _isCalculatingFolder = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculatingFolder = false);
        ToastHelper.failure('计算文件夹大小失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        right: false,
        child: Column(
        children: [
          // 抽屉头部
          Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                FileIconUtils.buildIconWidget(
                  context: context,
                  file: widget.file,
                  size: 32,
                  iconSize: 18,
                  borderRadius: 8,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.file.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // 内容区
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(theme)
                    : _buildContent(theme, colorScheme),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text('加载失败', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? '', style: TextStyle(color: theme.hintColor, fontSize: 12), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _loadFileInfo, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final file = _fileInfo?.file ?? widget.file;
    final typeLabel = file.isFolder
        ? '文件夹'
        : FileIconUtils.getFileTypeLabel(file.name);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 基本信息
          _buildInfoRow(LucideIcons.folderOpen, '位置', file.relativePath),
          _buildInfoRow(
            LucideIcons.hardDrive,
            '大小',
            file.isFolder ? '--' : date_utils.DateUtils.formatFileSize(file.size),
          ),
          _buildInfoRow(LucideIcons.calendarPlus, '创建时间', date_utils.DateUtils.formatDateTime(file.createdAt)),
          _buildInfoRow(LucideIcons.calendar, '修改时间', date_utils.DateUtils.formatDateTime(file.updatedAt)),
          if (file.owned != null)
            _buildInfoRow(LucideIcons.shield, '所有者', file.owned! ? '是' : '否'),

          // 文件夹信息
          if (file.isFolder) ...[
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('文件夹信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildFolderSummary(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderSummary(ThemeData theme, ColorScheme colorScheme) {
    final summary = _fileInfo?.folderSummary;

    if (summary != null) {
      return Column(
        children: [
          _buildInfoRow(LucideIcons.file, '包含文件', '${summary.files}'),
          _buildInfoRow(LucideIcons.folder, '包含文件夹', '${summary.folders}'),
          _buildInfoRow(LucideIcons.hardDrive, '总大小', date_utils.DateUtils.formatFileSize(summary.size)),
          if (!summary.completed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 14, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Text('计算未完成，结果可能不完整', style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '计算于 ${date_utils.DateUtils.formatDateTime(summary.calculatedAt)}',
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
        ],
      );
    }

    return _isCalculatingFolder
        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        : SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _calculateFolderSize,
              icon: const Icon(LucideIcons.calculator, size: 16),
              label: const Text('计算文件夹大小'),
            ),
          );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.hintColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 13, color: theme.hintColor)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
