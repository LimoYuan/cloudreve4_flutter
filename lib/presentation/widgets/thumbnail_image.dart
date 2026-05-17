import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/file_model.dart';
import '../../services/cache_manager_service.dart';
import '../../services/thumbnail_service.dart';
import '../../core/utils/file_icon_utils.dart';

/// 缩略图加载组件
///
/// 逻辑：
/// 1. 优先用稳定 cacheKey 从本地磁盘缓存读取缩略图。
/// 2. 本地没有缓存时，请求 Cloudreve 缩略图 URL。
/// 3. CachedNetworkImage 下载后用同一个 cacheKey 写入本地缓存。
/// 4. 文件更新时间变化时 cacheKey 自动变化，避免显示旧缩略图。
/// 5. 缩略图获取失败或图片解码失败时，回退到原文件图标。
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
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  /// 稳定的缩略图缓存 key。
  ///
  /// 不使用缩略图 URL 作为 cacheKey，因为 Cloudreve 返回的 URL 可能是临时签名 URL
  /// 或混淆 URL，每次打开目录都可能变化。
  ///
  /// 使用 file.id + updatedAt：
  /// - 同一文件未更新：命中本地缓存；
  /// - 文件内容更新：updatedAt 改变，自动重新加载缩略图。
  String get _thumbnailCacheKey {
    final fileId = widget.file.id.toString();
    final identity = fileId.isNotEmpty ? fileId : widget.file.relativePath;
    final updatedAt = widget.file.updatedAt.millisecondsSinceEpoch;

    return 'cloudreve_thumb_${Uri.encodeComponent(identity)}_$updatedAt';
  }

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.updatedAt != widget.file.updatedAt ||
        oldWidget.contextHint != widget.contextHint) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _imageUrl = null;
      _cachedFile = null;
      _isLoading = true;
      _hasError = false;
    });

    // 1. 优先查本地磁盘缓存。命中后不再请求 Cloudreve 缩略图接口。
    try {
      final cached = await CacheManagerService.instance.manager
          .getFileFromCache(_thumbnailCacheKey);
      final cachedFile = cached?.file;
      if (cachedFile != null && await cachedFile.exists()) {
        if (!mounted) return;
        setState(() {
          _cachedFile = cachedFile;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }
    } catch (_) {
      // 缓存读取失败时忽略，继续走网络缩略图。
    }

    // 2. 本地没有缓存时，从 Cloudreve 获取缩略图 URL。
    final url = await ThumbnailService.instance.getThumbnailUrl(
      fileUri: widget.file.relativePath,
      contextHint: widget.contextHint,
    );

    if (!mounted) return;

    setState(() {
      _imageUrl = url;
      _isLoading = false;
      _hasError = url == null || url.isEmpty;
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

  Widget _buildLocalCachedImage(BuildContext context, File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.file(
        file,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildNetworkImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CachedNetworkImage(
        imageUrl: _imageUrl!,
        cacheKey: _thumbnailCacheKey,
        cacheManager: CacheManagerService.instance.manager,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 80),
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cachedFile = _cachedFile;
    if (cachedFile != null) {
      return _buildLocalCachedImage(context, cachedFile);
    }

    if (_isLoading || _hasError || _imageUrl == null || _imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }

    return _buildNetworkImage(context);
  }
}
