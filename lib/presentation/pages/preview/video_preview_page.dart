import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';
import 'widgets/video_controls_overlay.dart';

/// 视频预览页面
class VideoPreviewPage extends StatefulWidget {
  final FileModel file;
  final String? entityId;

  const VideoPreviewPage({super.key, required this.file, this.entityId});

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  late final Player player;
  late final VideoController controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _loadVideoUrl();
  }

  Future<void> _loadVideoUrl() async {
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
          setState(() => _isLoading = false);
          player.open(Media(url), play: true);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = '无法获取视频URL';
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
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadVideoUrl();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : ExcludeSemantics(
                  child: Video(
                    controller: controller,
                    controls: (state) => VideoControlsOverlay(state: state, title: widget.file.name),
                  ),
                ),
    );
  }
}
