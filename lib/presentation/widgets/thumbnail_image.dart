// AI_PATCH_FORCE_PREVIEW_NO_SECOND_REQUEST_V3_20260611
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/file_model.dart';
import '../../services/cache_manager_service.dart';
import '../../services/thumbnail_service.dart';
import '../../core/utils/file_icon_utils.dart';


class ThumbnailImageSizeCache {
  static final Map<String, Size> _sizes = <String, Size>{};

  static String keyFor(FileModel file) {
    final fileId = file.id.toString();
    final identity = fileId.isNotEmpty ? fileId : file.relativePath;
    final updatedAt = file.updatedAt.millisecondsSinceEpoch;
    return 'cloudreve_thumb_${Uri.encodeComponent(identity)}_$updatedAt';
  }

  static Size? get(FileModel file) => _sizes[keyFor(file)];

  static double? aspectRatioFor(FileModel file) {
    final size = get(file);
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    return size.width / size.height;
  }

  static void remember(FileModel file, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _sizes[keyFor(file)] = size;
  }
}

/// Compatibility stub for older hover-preview code.
///
/// Hover previews must not call /file/url. They reuse the thumbnail cache only,
/// so moving the mouse over the same image does not trigger a second API
/// request or a thumbnail -> original-image swap flicker.
class PreviewImageUrlCache {
  static Future<String?> getOriginalImageUrl({
    required FileModel file,
    String? contextHint,
  }) {
    // Keep parameters intentionally referenced to avoid accidental future
    // cleanup changing this API surface while category pages still call it.
    Object.hash(file.id, file.updatedAt, contextHint);
    return Future<String?>.value(null);
  }
}



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
  final BoxFit fit;

  const ThumbnailImage({
    super.key,
    required this.file,
    this.contextHint,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  String? _imageUrl;
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;
  String? _lastResolvedSizeKey;

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


  void _rememberImageProviderSize(ImageProvider provider) {
    final cacheKey = _thumbnailCacheKey;
    if (_lastResolvedSizeKey == cacheKey) return;
    _lastResolvedSizeKey = cacheKey;

    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        ThumbnailImageSizeCache.remember(
          widget.file,
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
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
    final provider = FileImage(file);
    _rememberImageProviderSize(provider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image(
        image: provider,
        width: double.infinity,
        height: double.infinity,
        fit: widget.fit,
        gaplessPlayback: true,
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
        imageBuilder: (context, provider) {
          _rememberImageProviderSize(provider);
          return Image(
            image: provider,
            width: double.infinity,
            height: double.infinity,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        },
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
