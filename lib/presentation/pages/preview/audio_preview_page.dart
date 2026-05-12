import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../data/models/file_model.dart';
import '../../../services/file_service.dart';

/// 音频预览页面
class AudioPreviewPage extends StatefulWidget {
  final FileModel file;
  final String? entityId;

  const AudioPreviewPage({super.key, required this.file, this.entityId});

  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage> {
  late final Player player;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    player = Player();
    _loadAudioUrl();
  }

  Future<void> _loadAudioUrl() async {
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
            _errorMessage = '无法获取音频URL';
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadAudioUrl();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return AudioPlayerWidget(player: player, fileName: widget.file.name);
  }
}

/// 音频播放器组件
class AudioPlayerWidget extends StatefulWidget {
  final Player player;
  final String fileName;

  const AudioPlayerWidget({super.key, required this.player, required this.fileName});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 专辑封面
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE94560), Color(0xFF533483)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE94560).withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note,
                size: 120,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),

            // 文件名
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.fileName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),

            // 文件类型
            Text(
              '音频文件',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 48),

            // 进度条
            _buildProgressBar(),
            const SizedBox(height: 32),

            // 播放控制
            _buildPlaybackControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        StreamBuilder(
          stream: widget.player.stream.position,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            return StreamBuilder(
              stream: widget.player.stream.duration,
              builder: (context, snapshot) {
                final duration = snapshot.data ?? Duration.zero;
                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: const Color(0xFFE94560),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: const Color(0xFFE94560),
                    overlayColor: const Color(0xFFE94560).withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: position.inMilliseconds.toDouble(),
                    max: duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (value) {
                      widget.player.seek(
                        Duration(milliseconds: value.toInt()),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder(
            stream: widget.player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return StreamBuilder(
                stream: widget.player.stream.duration,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一首（暂无功能）
          Flexible(
            child: IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: isSmallScreen ? 28 : 36,
              color: Colors.white,
              onPressed: () {},
            ),
          ),

          // 快退10秒
          Flexible(
            child: IconButton(
              icon: const Icon(Icons.replay_10),
              iconSize: isSmallScreen ? 32 : 42,
              color: Colors.white,
              onPressed: () {
                final position = widget.player.state.position;
                widget.player.seek(position - const Duration(seconds: 10));
              },
            ),
          ),

          // 播放/暂停
          StreamBuilder(
            stream: widget.player.stream.playing,
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return Container(
                width: isSmallScreen ? 56 : 72,
                height: isSmallScreen ? 56 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE94560),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE94560).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  iconSize: isSmallScreen ? 28 : 36,
                  color: Colors.white,
                  onPressed: () {
                    if (playing) {
                      widget.player.pause();
                    } else {
                      widget.player.play();
                    }
                  },
                ),
              );
            },
          ),

          // 快进10秒
          Flexible(
            child: IconButton(
              icon: const Icon(Icons.forward_10),
              iconSize: isSmallScreen ? 32 : 42,
              color: Colors.white,
              onPressed: () {
                final position = widget.player.state.position;
                widget.player.seek(position + const Duration(seconds: 10));
              },
            ),
          ),

          // 下一首（暂无功能）
          Flexible(
            child: IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: isSmallScreen ? 28 : 36,
              color: Colors.white,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
