import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';

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
  double _playbackSpeed = 1.0;

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
          setState(() {
            _isLoading = false;
          });
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

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    player.setRate(speed);
  }

  void _showSpeedMenu() {
    final size = MediaQuery.of(context).size;
    showMenu<double>(
      context: context,
      position: RelativeRect.fromLTRB(
        size.width - 160,
        size.height / 2,
        size.width,
        size.height / 2 + 200,
      ),
      items: [
        for (final rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0])
          PopupMenuItem<double>(
            value: rate,
            child: Row(
              children: [
                Text('${rate}x'),
                if (rate == _playbackSpeed)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 16, color: Color(0xFFE94560)),
                  ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        _setSpeed(value);
      }
    });
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
      appBar: AppBar(
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 30,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            iconSize: 20,
            onPressed: _showSpeedMenu,
            tooltip: '倍速',
            color: Colors.white,
          ),
        ],
      ),
      body: GestureDetector(
        onSecondaryTap: _showSpeedMenu,
        onLongPress: _showSpeedMenu,
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white,
                    ),
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
            else
              ExcludeSemantics(
                child: Video(controller: controller),
              )
          ],
        ),
      ),
    );
  }
}