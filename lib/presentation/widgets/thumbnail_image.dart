import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/file_model.dart';
import '../../services/cache_manager_service.dart';
import '../../services/thumbnail_service.dart';
import '../../core/utils/file_icon_utils.dart';

/// 缩略图加载组件 — 异步获取 URL 并用 CachedNetworkImage 渲染
class ThumbnailImage extends StatefulWidget {
  final FileModel file;
  final String? contextHint;
  final double borderRadius;

  const ThumbnailImage({
    super.key,
    required this.file,
    this.contextHint,
    this.borderRadius = 10,
  });

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  String? _imageUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final url = await ThumbnailService.instance.getThumbnailUrl(
      fileUri: widget.file.relativePath,
      contextHint: widget.contextHint,
    );

    if (!mounted) return;

    setState(() {
      _imageUrl = url;
      _isLoading = false;
      _hasError = url == null;
    });
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: FileIconUtils.buildIconWidget(
        context: context,
        file: widget.file,
        size: 40,
        iconSize: 22,
        borderRadius: widget.borderRadius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildPlaceholder(context);
    if (_hasError || _imageUrl == null) return _buildPlaceholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CachedNetworkImage(
        imageUrl: _imageUrl!,
        cacheManager: CacheManagerService.instance.manager,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      ),
    );
  }
}
