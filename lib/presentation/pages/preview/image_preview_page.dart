import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';
import '../../../services/cache_manager_service.dart';

/// 图片预览页面
class ImagePreviewPage extends StatefulWidget {
  final FileModel file;

  const ImagePreviewPage({
    super.key,
    required this.file,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  String? _imageUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    try {
      final response = await FileService().getDownloadUrls(
        uris: [widget.file.relativePath],
        download: false,
      );

      final urls = response['urls'] as List<dynamic>? ?? [];
      if (urls.isNotEmpty) {
        final urlData = urls[0] as Map<String, dynamic>;
        final url = urlData['url'] as String;

        if (mounted) {
          setState(() {
            _imageUrl = url;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '无法获取图片URL';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                _shareImage();
              } else if (value == 'save') {
                _saveImage();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('分享'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('保存'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadImageUrl();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_imageUrl == null) {
      return const Center(
        child: Text('无法加载图片'),
      );
    }

    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        _imageUrl!,
        cacheManager: CacheManagerService.instance.manager,
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.error_outline, size: 48, color: Colors.red),
      ),
    );
  }

  void _shareImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能待实现')),
    );
  }

  void _saveImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存功能待实现')),
    );
  }
}
