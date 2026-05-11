import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/utils/video_fullscreen.dart';

/// 自定义视频控制栏叠加层（Bilibili 风格）
///
/// 作为 [Video.controls] 传入，确保 context 在 VideoStateInheritedWidget 下，
/// 使 toggleFullscreen/isFullscreen 等 API 正常工作。
class VideoControlsOverlay extends StatefulWidget {
  final VideoState state;
  final String title;

  const VideoControlsOverlay({super.key, required this.state, required this.title});

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> with WindowListener {
  Player get player => widget.state.widget.controller.player;

  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isLongPressing = false;
  double _rateBeforeLongPress = 1.0;

  // 进度条拖拽状态
  bool _isSeeking = false;
  Duration _seekPosition = Duration.zero;

  // 音量控制
  bool _volumeSliderVisible = false;
  double _volumeBeforeMute = 100.0;

  // 桌面端自管全屏状态（不走 media_kit 路由全屏）
  bool _desktopFullscreen = false;

  // 键盘焦点
  final FocusNode _focusNode = FocusNode();

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
    // 自动聚焦以接收键盘事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() {
    if (!_desktopFullscreen && mounted) {
      setState(() => _desktopFullscreen = true);
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (_desktopFullscreen && mounted) {
      setState(() => _desktopFullscreen = false);
      videoFullscreenNotifier.value = false;
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLongPressing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  void _onLongPressStart() {
    _hideTimer?.cancel();
    _rateBeforeLongPress = player.state.rate;
    player.setRate(2.0);
    setState(() {
      _isLongPressing = true;
      _controlsVisible = false;
    });
  }

  void _onLongPressEnd() {
    player.setRate(_rateBeforeLongPress);
    setState(() {
      _isLongPressing = false;
      _controlsVisible = true;
    });
    _startHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    if (_isDesktop) {
      // 桌面端：直接控制窗口全屏，不走 media_kit 路由
      final isFull = await windowManager.isFullScreen();
      if (isFull) {
        await windowManager.setFullScreen(false);
        videoFullscreenNotifier.value = false;
        setState(() => _desktopFullscreen = false);
      } else {
        videoFullscreenNotifier.value = true;
        await windowManager.setFullScreen(true);
        setState(() => _desktopFullscreen = true);
      }
    } else {
      // 移动端：使用 media_kit 的路由全屏 + 系统 UI 控制
      if (isFullscreen(context)) {
        exitFullscreen(context);
      } else {
        enterFullscreen(context);
      }
    }
  }

  void _onBack() {
    if (_isDesktop && _desktopFullscreen) {
      windowManager.setFullScreen(false);
      videoFullscreenNotifier.value = false;
      setState(() => _desktopFullscreen = false);
    } else if (!_isDesktop && isFullscreen(context)) {
      exitFullscreen(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  bool get _isInFullscreen {
    if (_isDesktop) return _desktopFullscreen;
    return isFullscreen(context);
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      player.playOrPause();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.escape) {
      if (_isInFullscreen) _onBack();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final pos = player.state.position - const Duration(seconds: 5);
      player.seek(pos < Duration.zero ? Duration.zero : pos);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final pos = player.state.position + const Duration(seconds: 5);
      final dur = player.state.duration;
      player.seek(pos > dur ? dur : pos);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final vol = (player.state.volume + 5).clamp(0.0, 100.0);
      player.setVolume(vol);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final vol = (player.state.volume - 5).clamp(0.0, 100.0);
      player.setVolume(vol);
    }
  }

  void _showSpeedMenu() {
    _hideTimer?.cancel();
    final rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];
    final currentRate = player.state.rate;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('倍速播放',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  )),
            ),
            const Divider(height: 1, color: Colors.white24),
            Wrap(
              children: rates.map((rate) {
                final selected = (rate - currentRate).abs() < 0.01;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 32) / 4,
                  child: ListTile(
                    title: Text(
                      '${rate}x',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? const Color(0xFFE94560) : Colors.white,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      player.setRate(rate);
                      Navigator.of(ctx).pop();
                      _startHideTimer();
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isInFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleControls,
          onDoubleTap: () => player.playOrPause(),
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: (_) => _onLongPressEnd(),
          child: Stack(
          fit: StackFit.expand,
          children: [
            // 长按2倍速提示
            if (_isLongPressing)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fast_forward, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '2.0x 快进中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Buffering 指示器
            StreamBuilder<bool>(
              stream: player.stream.buffering,
              builder: (context, snapshot) {
                final buffering = snapshot.data ?? false;
                if (!buffering) return const SizedBox.shrink();
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              },
            ),

            // 控制栏
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Column(
                  children: [
                    _buildTopBar(),
                    const Spacer(),
                    _buildBottomBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _onBack,
          ),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSeekBar(),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: _buildControlsRow(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow() {
    return Row(
      children: [
        // 播放/暂停
        StreamBuilder<bool>(
          stream: player.stream.playing,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: () => player.playOrPause(),
            );
          },
        ),
        // 音量控制
        _buildVolumeControl(),
        // 时间
        StreamBuilder<Duration>(
          stream: player.stream.position,
          builder: (context, posSnapshot) {
            return StreamBuilder<Duration>(
              stream: player.stream.duration,
              builder: (context, durSnapshot) {
                final pos = posSnapshot.data ?? Duration.zero;
                final dur = durSnapshot.data ?? Duration.zero;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              },
            );
          },
        ),
        const Spacer(),
        // 倍速按钮
        StreamBuilder<double>(
          stream: player.stream.rate,
          builder: (context, snapshot) {
            final rate = snapshot.data ?? 1.0;
            return GestureDetector(
              onTap: _showSpeedMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '${rate}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
        // 全屏按钮
        IconButton(
          icon: Icon(
            _isInFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
          ),
          onPressed: _toggleFullscreen,
        ),
      ],
    );
  }

  Widget _buildVolumeControl() {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 100.0;
        final isMuted = volume <= 0;

        IconData volumeIcon;
        if (isMuted) {
          volumeIcon = Icons.volume_off;
        } else if (volume < 50) {
          volumeIcon = Icons.volume_down;
        } else {
          volumeIcon = Icons.volume_up;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(volumeIcon, color: Colors.white, size: 22),
              onPressed: () {
                if (isMuted) {
                  player.setVolume(_volumeBeforeMute);
                } else {
                  _volumeBeforeMute = volume;
                  player.setVolume(0);
                }
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.centerLeft,
              child: _volumeSliderVisible
                  ? SizedBox(
                      width: 100,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: const Color(0xFFE94560),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFE94560),
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 100.0),
                          min: 0,
                          max: 100,
                          onChanged: (v) {
                            _hideTimer?.cancel();
                            player.setVolume(v);
                          },
                          onChangeEnd: (_) => _startHideTimer(),
                        ),
                      ),
                    )
                  : const SizedBox(width: 0),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _volumeSliderVisible = !_volumeSliderVisible);
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 2, right: 4, top: 8, bottom: 8),
                child: Icon(
                  _volumeSliderVisible ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, posSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durSnapshot) {
            final position = posSnapshot.data ?? Duration.zero;
            final duration = durSnapshot.data ?? Duration.zero;

            final displayPos = _isSeeking ? _seekPosition : position;
            final value = duration.inMilliseconds > 0
                ? displayPos.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return SizedBox(
              height: 20,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: const Color(0xFFE94560),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFFE94560),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: (v) {
                    _hideTimer?.cancel();
                    setState(() {
                      _isSeeking = true;
                      _seekPosition = Duration(
                        milliseconds: (duration.inMilliseconds * v).round(),
                      );
                    });
                  },
                  onChangeEnd: (v) {
                    final seekTo = Duration(
                      milliseconds: (duration.inMilliseconds * v).round(),
                    );
                    player.seek(seekTo);
                    setState(() => _isSeeking = false);
                    _startHideTimer();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
