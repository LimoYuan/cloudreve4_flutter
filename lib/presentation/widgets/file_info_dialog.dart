import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/file_model.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../core/utils/file_icon_utils.dart';
import '../../core/utils/file_type_utils.dart';
import '../../services/file_service.dart';
import '../../router/app_router.dart';
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
  bool _isVersionLoading = false;
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
        extended: widget.file.isFile,
        folderSummary: false,
      );
      if (mounted) {
        setState(() {
          _fileInfo = FileInfoModel.fromJson(response);
          _isLoading = false;
          _isVersionLoading = false;
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
        extended: true,
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
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
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
          Icon(LucideIcons.alertCircle, size: 48, color: theme.colorScheme.error),
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
    final extendedInfo = _fileInfo?.extendedInfo;
    final versionEntities = extendedInfo?.entities
            ?.where((e) => e.type == 0)
            .toList() ??
        [];

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
          _buildInfoRow(LucideIcons.folderOpen, '位置', Uri.decodeComponent(file.relativePath)),
          if (file.isFile)
            _buildInfoRow(
              LucideIcons.hardDrive,
              '大小',
              date_utils.DateUtils.formatFileSize(file.size),
            ),
          _buildInfoRow(LucideIcons.calendarPlus, '创建时间', date_utils.DateUtils.formatDateTime(file.createdAt)),
          _buildInfoRow(LucideIcons.calendar, '修改时间', date_utils.DateUtils.formatDateTime(file.updatedAt)),
          if (file.owned != null)
            _buildInfoRow(LucideIcons.shield, '所有者', file.owned! ? '是' : '否'),

          // 文件扩展信息
          if (file.isFile && extendedInfo != null) ...[
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('扩展信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildInfoRow(LucideIcons.fingerprint, '文件ID', file.id),
            if (file.primaryEntity != null)
              _buildInfoRow(LucideIcons.hash, '主版本', file.primaryEntity!),
            if (extendedInfo.storagePolicy != null)
              _buildInfoRow(
                LucideIcons.server,
                '存储策略',
                '${extendedInfo.storagePolicy!.name} (${extendedInfo.storagePolicy!.type})',
              ),
            if (extendedInfo.storageUsed != null)
              _buildInfoRow(
                LucideIcons.database,
                '总占用',
                date_utils.DateUtils.formatFileSize(extendedInfo.storageUsed!),
              ),
          ],

          // 版本历史
          if (file.isFile && versionEntities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            _buildVersionSection(theme, colorScheme, versionEntities),
          ],

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

  Widget _buildVersionSection(
    ThemeData theme,
    ColorScheme colorScheme,
    List<EntityModel> entities,
  ) {
    final file = _fileInfo!.file;
    final primaryEntity = file.primaryEntity;
    final isPreviewable = FileTypeUtils.isPreviewable(file.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('版本历史', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${entities.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...entities.asMap().entries.map((entry) {
          final index = entry.key;
          final entity = entry.value;
          final isCurrent = entity.id == primaryEntity;
          final versionNumber = entities.length - index;
          return _buildVersionItem(
            theme,
            colorScheme,
            entity: entity,
            versionNumber: versionNumber,
            isCurrent: isCurrent,
            isPreviewable: isPreviewable,
            file: file,
          );
        }),
      ],
    );
  }

  Widget _buildVersionItem(
    ThemeData theme,
    ColorScheme colorScheme, {
    required EntityModel entity,
    required int versionNumber,
    required bool isCurrent,
    required bool isPreviewable,
    required FileModel file,
  }) {
    final shortId = entity.id.length > 6 ? entity.id.substring(0, 6) : entity.id;
    final createdBy = entity.createdBy?.nickname ?? '未知';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : null,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 380;

          final actionButtons = <Widget>[
            if (isPreviewable)
              _buildVersionActionButton(
                icon: LucideIcons.externalLink,
                tooltip: '打开',
                onPressed: _isVersionLoading ? null : () => _openVersion(entity),
              ),
            _buildVersionActionButton(
              icon: LucideIcons.download,
              tooltip: '下载',
              onPressed: _isVersionLoading ? null : () => _downloadVersion(entity),
            ),
            if (!isCurrent) ...[
              _buildVersionActionButton(
                icon: LucideIcons.pin,
                tooltip: '设为当前版本',
                onPressed: _isVersionLoading ? null : () => _setCurrentVersion(entity),
              ),
              _buildVersionActionButton(
                icon: LucideIcons.trash2,
                tooltip: '删除',
                color: colorScheme.error,
                onPressed: _isVersionLoading ? null : () => _deleteVersion(entity),
              ),
            ],
          ];

          final versionBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrent
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isCurrent ? '当前' : 'v$versionNumber',
              style: TextStyle(
                fontSize: 11,
                color: isCurrent
                    ? colorScheme.onPrimaryContainer
                    : theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

          final versionInfo = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showVersionDetail(entity),
                  onLongPress: () => _showVersionDetail(entity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$shortId · ${date_utils.DateUtils.formatFileSize(entity.size)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${date_utils.DateUtils.formatDateTime(entity.createdAt)} · $createdBy',
                        style: const TextStyle(fontSize: 11, color: null)
                            .copyWith(color: theme.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isNarrow) ...[
                  const SizedBox(height: 4),
                  Row(children: actionButtons),
                ],
              ],
            ),
          );

          if (isNarrow) {
            return Row(
              children: [versionBadge, const SizedBox(width: 8), versionInfo],
            );
          }

          return Row(
            children: [
              versionBadge,
              const SizedBox(width: 8),
              versionInfo,
              ...actionButtons,
            ],
          );
        },
      ),
    );
  }

  void _showVersionDetail(EntityModel entity) {
    final createdBy = entity.createdBy;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('版本详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(LucideIcons.hash, 'ID', entity.id),
            _buildInfoRow(LucideIcons.hardDrive, '大小', date_utils.DateUtils.formatFileSize(entity.size)),
            _buildInfoRow(LucideIcons.calendarPlus, '创建时间', date_utils.DateUtils.formatDateTime(entity.createdAt)),
            if (createdBy != null) ...[
              _buildInfoRow(LucideIcons.user, '创建者', createdBy.nickname),
              _buildInfoRow(LucideIcons.fingerprint, '创建者ID', createdBy.id),
            ],
            if (entity.storagePolicy != null)
              _buildInfoRow(LucideIcons.server, '存储策略', '${entity.storagePolicy!.name} (${entity.storagePolicy!.type})'),
            if (entity.encryptedWith != null)
              _buildInfoRow(LucideIcons.lock, '加密', entity.encryptedWith!),
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

  Widget _buildVersionActionButton({
    required IconData icon,
    required String tooltip,
    Color? color,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(28, 28),
      ),
    );
  }

  // ─── 版本操作 ───

  void _openVersion(EntityModel entity) {
    final file = _fileInfo!.file;
    if (!FileTypeUtils.isPreviewable(file.name)) {
      ToastHelper.info('暂不支持预览此文件类型');
      return;
    }

    final args = {'file': file, 'entityId': entity.id};

    if (FileTypeUtils.isImage(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.imagePreview, arguments: args);
    } else if (FileTypeUtils.isPdf(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.pdfPreview, arguments: args);
    } else if (FileTypeUtils.isVideo(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.videoPreview, arguments: args);
    } else if (FileTypeUtils.isAudio(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.audioPreview, arguments: args);
    } else if (FileTypeUtils.isMarkdown(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.markdownPreview, arguments: args);
    } else if (FileTypeUtils.isTextCode(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.documentPreview, arguments: args);
    }
  }

  Future<void> _downloadVersion(EntityModel entity) async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        entity: entity.id,
        download: true,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isNotEmpty) {
        final urlData = urls[0] as Map<String, dynamic>;
        final url = urlData['url'] as String;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          if (mounted) ToastHelper.error('无法打开下载链接');
        }
      } else {
        if (mounted) ToastHelper.error('获取下载链接失败');
      }
    } catch (e) {
      if (mounted) ToastHelper.failure('获取下载链接失败: $e');
    }
  }

  Future<void> _setCurrentVersion(EntityModel entity) async {
    setState(() => _isVersionLoading = true);
    try {
      await FileService().setFileVersion(
        uri: widget.file.relativePath,
        version: entity.id,
      );
      if (mounted) {
        ToastHelper.success('已设为当前版本');
        _loadFileInfo();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVersionLoading = false);
        ToastHelper.failure('操作失败: $e');
      }
    }
  }

  Future<void> _deleteVersion(EntityModel entity) async {
    final colorScheme = Theme.of(context).colorScheme;
    final shortId = entity.id.length > 6 ? entity.id.substring(0, 6) : entity.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除版本'),
        content: Text('确定要删除版本 "$shortId" (${date_utils.DateUtils.formatFileSize(entity.size)}) 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isVersionLoading = true);
    try {
      await FileService().deleteFileVersion(
        uri: widget.file.relativePath,
        version: entity.id,
      );
      if (mounted) {
        ToastHelper.success('版本已删除');
        _loadFileInfo();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVersionLoading = false);
        ToastHelper.failure('删除失败: $e');
      }
    }
  }

  // ─── 文件夹摘要 ───

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
