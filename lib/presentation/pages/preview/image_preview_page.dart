import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';
import '../../../services/cache_manager_service.dart';
import '../../widgets/toast_helper.dart';

/// 图片预览页面
class ImagePreviewPage extends StatefulWidget {
  final FileModel file;
  final String? entityId;

  const ImagePreviewPage({super.key, required this.file, this.entityId});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  String? _imageUrl;
  bool _isLoading = true;
  String? _errorMessage;
  // 定义一个变量，防止多个动画冲突
  bool _isAnimating = false;

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
        entity: widget.entityId,
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
              if (value == 'bingo') {
                _bingoHahah();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bingo',
                child: Row(
                  children: [
                    Icon(Icons.handshake, size: 20),
                    SizedBox(width: 12),
                    Text('bingo'),
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
      return const Center(child: Text('无法加载图片'));
    }

    return _buildPhotoView();
  }

  void _bingoHahah() {
    ToastHelper.info('彩蛋彩蛋彩蛋蛋, 对下联');
  }

  Listener _buildPhotoView() {
    // 1. 自定义控制器, 用于支持Linux/Windows 键盘 Ctrl + 鼠标滚轮缩放图片
    final PhotoViewController photoController = PhotoViewController();

    // 2. 包装组件
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          // 检查是否按下了 Ctrl 键 (在 Linux/Windows 上很常用)
          // 如果你希望直接滚动滚轮就缩放，可以去掉 RawKeyboardGui... 这一行判断
          final isControlPressed =
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlRight,
              );

          // 计算缩放增量：向上滚为负，向下滚为正
          // 这里的 0.001 是灵敏度系数，可以根据手感调整
          if (isControlPressed) {
            if (photoController.scale == null) return;
            // double newScale =
            //     photoController.scale! - (pointerSignal.scrollDelta.dy * 0.001);
            // 限制缩放范围，防止无限缩小或放大
            _smoothScale(photoController, pointerSignal.scrollDelta.dy);
          }
        }
      },
      child: PhotoView(
        controller: photoController, // 绑定控制器
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
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.error_outline, size: 48, color: Colors.red),
        ),
      ),
    );
  }

  // 2. 编写平滑缩放函数
  void _smoothScale(PhotoViewController photoController, double delta) {
    // 如果正在动画中，忽略新的滚轮脉冲，防止冲突
    if (_isAnimating) return; 
    _isAnimating = true;

    // 计算目标缩放值
    double targetScale = (photoController.scale ?? 1.0) - (delta * 0.001);
    targetScale = targetScale.clamp(0.1, 5.0);

    // 如果不想写复杂的 AnimationController，可以用这种简易插值
    // 这里的 10 次循环和 5 毫秒延迟可以根据你的手感微调
    int steps = 5;
    double stepDelta = (targetScale - photoController.scale!) / steps;

    Future.doWhile(() async {
      if (steps <= 0) {
        _isAnimating = false;
        return false;
      }
      photoController.scale = photoController.scale! + stepDelta;
      steps--;
      await Future.delayed(const Duration(milliseconds: 16)); // 约 60 帧的速度
      return true;
    });
  }
}
