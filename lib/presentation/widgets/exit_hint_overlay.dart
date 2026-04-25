import 'package:flutter/material.dart';
import 'dart:ui';

/// 退出提示覆盖层
class ExitHintOverlay {
  OverlayEntry? _overlay;
  AnimationController? _animationController;

  /// 显示退出提示
  void show(BuildContext context) {
    remove();

    _overlay = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: _ExitHintWidget(
              onDismiss: remove,
              onAnimationReady: (controller, fadeAnimation) {
                _animationController = controller;
                controller.forward();
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  /// 移除退出提示
  void remove() {
    // 立即移除 overlay
    _overlay?.remove();
    _overlay = null;

    // 停止动画
    _animationController?.stop();

    // 清理控制器引用
    _animationController = null;
  }
}

class _ExitHintWidget extends StatefulWidget {
  final VoidCallback onDismiss;
  final Function(AnimationController controller, Animation<double> fadeAnimation) onAnimationReady;

  const _ExitHintWidget({
    required this.onDismiss,
    required this.onAnimationReady,
  });

  @override
  State<_ExitHintWidget> createState() => _ExitHintWidgetState();
}

class _ExitHintWidgetState extends State<_ExitHintWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    widget.onAnimationReady(_controller, _fadeAnimation);
  }

  @override
  void dispose() {
    _controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: child,
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final cardWidth = screenWidth * 0.65;

          return GestureDetector(
            onTap: widget.onDismiss,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(maxWidth: cardWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.touch_app_rounded,
                          color: theme.colorScheme.error,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '再次左滑退出应用',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '点击屏幕任意位置取消',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}