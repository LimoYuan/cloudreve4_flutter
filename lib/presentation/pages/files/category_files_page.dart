import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/utils/date_utils.dart' as date_utils;
import '../../../core/utils/file_icon_utils.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../../data/models/file_model.dart';
import '../../../router/app_router.dart';
import '../../../services/file_service.dart';
import '../../widgets/thumbnail_image.dart';
import '../../widgets/toast_helper.dart';

/// 快捷入口分类页面参数。
///
/// category 对应 Cloudreve V4 文件 URI 查询条件：
/// image / video / audio / document。
class CategoryFilesPageArgs {
  final String category;
  final String title;
  final IconData icon;
  final Color color;

  const CategoryFilesPageArgs({
    required this.category,
    required this.title,
    required this.icon,
    required this.color,
  });

  factory CategoryFilesPageArgs.fromMap(Map<String, dynamic> map) {
    return CategoryFilesPageArgs(
      category: map['category'] as String,
      title: map['title'] as String,
      icon: map['icon'] as IconData? ?? LucideIcons.file,
      color: map['color'] as Color? ?? const Color(0xFF64748B),
    );
  }
}

/// 分类文件瀑布流页面。
///
/// 使用 Cloudreve V4 的文件 URI 查询：
/// cloudreve://my?category=image
/// cloudreve://my?category=video
/// cloudreve://my?category=audio
/// cloudreve://my?category=document
class CategoryFilesPage extends StatefulWidget {
  final CategoryFilesPageArgs args;

  const CategoryFilesPage({
    super.key,
    required this.args,
  });

  @override
  State<CategoryFilesPage> createState() => _CategoryFilesPageState();
}

class _CategoryFilesPageState extends State<CategoryFilesPage> {
  final _fileService = FileService();
  final _scrollController = ScrollController();

  final List<FileModel> _files = [];
  String? _nextPageToken;
  String? _contextHint;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFiles(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant CategoryFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.category != widget.args.category) {
      _loadFiles(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_nextPageToken == null || _isLoading || _isLoadingMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadFiles(refresh: false);
    }
  }

  Future<void> _loadFiles({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
        _nextPageToken = null;
        _contextHint = null;
        _files.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _fileService.listFilesByCategory(
        category: widget.args.category,
        pageSize: 100,
        nextPageToken: refresh ? null : _nextPageToken,
      );

      final filesData = response['files'] as List<dynamic>? ?? const [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? const {};
      final newFiles = filesData
          .map((item) => FileModel.fromJson(item as Map<String, dynamic>))
          .where((file) => file.isFile)
          .toList();

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _files
            ..clear()
            ..addAll(newFiles);
        } else {
          final existingIds = _files.map((e) => e.id).toSet();
          _files.addAll(newFiles.where((file) => !existingIds.contains(file.id)));
        }

        _nextPageToken = pagination['next_token'] as String?;
        _contextHint = response['context_hint'] as String?;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() => _loadFiles(refresh: true);

  @override
  Widget build(BuildContext context) {
    final args = widget.args;

    return Scaffold(
      appBar: AppBar(
        title: Text(args.title),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            LucideIcons.alertTriangle,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }

    if (_files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Icon(
            widget.args.icon,
            size: 52,
            color: widget.args.color,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '没有找到${widget.args.title}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnCount = _columnCountForWidth(width);
        final spacing = width >= 720 ? 14.0 : 10.0;
        final horizontalPadding = width >= 720 ? 16.0 : 10.0;
        final columnWidth =
            (width - horizontalPadding * 2 - spacing * (columnCount - 1)) / columnCount;

        final columns = List.generate(columnCount, (_) => <FileModel>[]);
        final heights = List.generate(columnCount, (_) => 0.0);

        for (final file in _files) {
          final targetIndex = _indexOfMin(heights);
          columns[targetIndex].add(file);
          heights[targetIndex] += _estimatedTileHeight(file, columnWidth) + spacing;
        }

        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            24,
          ),
          children: [
            _buildSummaryHeader(context),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < columnCount; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        for (final file in columns[i])
                          Padding(
                            padding: EdgeInsets.only(bottom: spacing),
                            child: _CategoryFileTile(
                              file: file,
                              contextHint: _contextHint,
                              category: widget.args.category,
                              accentColor: widget.args.color,
                              onTap: () => _openFile(context, file),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (i != columnCount - 1) SizedBox(width: spacing),
                ],
              ],
            ),
            if (_isLoadingMore) ...[
              const SizedBox(height: 8),
              const Center(child: CircularProgressIndicator()),
            ] else if (_nextPageToken != null) ...[
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _loadFiles(refresh: false),
                  icon: const Icon(LucideIcons.chevronsDown, size: 16),
                  label: const Text('加载更多'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.args.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(widget.args.icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.args.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${_files.length} 项',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  int _columnCountForWidth(double width) {
    if (width < 460) return 2;
    if (width < 720) return 3;
    if (width < 1100) return 4;
    return 6;
  }

  int _indexOfMin(List<double> values) {
    var index = 0;
    var minValue = values[0];

    for (var i = 1; i < values.length; i++) {
      if (values[i] < minValue) {
        minValue = values[i];
        index = i;
      }
    }

    return index;
  }

  double _estimatedTileHeight(FileModel file, double width) {
    final ext = FileTypeUtils.getExtension(file.name);
    if (widget.args.category == 'audio') return 112;
    if (widget.args.category == 'document') return 124;
    if (ext == 'psd' || ext == 'psb') return width * 1.18 + 54;

    // 用文件名 hash 做轻微错落，避免完全像普通网格。
    final variance = (file.name.hashCode.abs() % 46).toDouble();
    return width * 0.92 + 54 + variance;
  }

  void _openFile(BuildContext context, FileModel file) {
    if (FileTypeUtils.isImage(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.imagePreview, arguments: file);
    } else if (FileTypeUtils.isPdf(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.pdfPreview, arguments: file);
    } else if (FileTypeUtils.isVideo(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.videoPreview, arguments: file);
    } else if (FileTypeUtils.isAudio(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.audioPreview, arguments: file);
    } else if (FileTypeUtils.isMarkdown(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.markdownPreview, arguments: file);
    } else if (FileTypeUtils.isTextCode(file.name)) {
      Navigator.of(context).pushNamed(RouteNames.documentPreview, arguments: file);
    } else {
      ToastHelper.info('暂不支持预览 ${FileTypeUtils.getFileTypeDescription(file.name)}');
    }
  }
}

class _CategoryFileTile extends StatelessWidget {
  final FileModel file;
  final String? contextHint;
  final String category;
  final Color accentColor;
  final VoidCallback onTap;

  const _CategoryFileTile({
    required this.file,
    required this.contextHint,
    required this.category,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMedia = category == 'image' || category == 'video';
    final isAudio = category == 'audio';
    final isDocument = category == 'document';

    final ext = FileTypeUtils.getExtension(file.name);
    final isPsd = ext == 'psd' || ext == 'psb';

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: isMedia || isPsd ? 1 : 1.45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ThumbnailImage(
                      file: file,
                      contextHint: contextHint,
                      borderRadius: 0,
                    ),
                    Positioned(
                      top: 7,
                      left: 7,
                      child: _TypeBadge(
                        icon: _badgeIcon(),
                        label: _badgeLabel(ext),
                        color: accentColor,
                        compact: isMedia,
                      ),
                    ),
                    if (category == 'video')
                      const Center(
                        child: _PlayOverlay(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: isAudio || isDocument ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${FileTypeUtils.getFileTypeDescription(file.name)} · ${date_utils.DateUtils.formatFileSize(file.size)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _badgeIcon() {
    switch (category) {
      case 'image':
        return LucideIcons.image;
      case 'video':
        return LucideIcons.video;
      case 'audio':
        return LucideIcons.music;
      case 'document':
        return LucideIcons.fileText;
      default:
        return LucideIcons.file;
    }
  }

  String _badgeLabel(String ext) {
    if (ext == 'psd' || ext == 'psb') return ext.toUpperCase();
    switch (category) {
      case 'image':
        return '图片';
      case 'video':
        return '视频';
      case 'audio':
        return '音乐';
      case 'document':
        return '文档';
      default:
        return '文件';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const _TypeBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 7,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(
          LucideIcons.play,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
