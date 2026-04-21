import 'package:flutter/material.dart';

/// 退出提示覆盖层
class ExitHintOverlay {
  OverlayEntry? _overlay;

  /// 显示退出提示
  void show(BuildContext context) {
    remove();
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '再次左滑退出应用',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  /// 移除退出提示
  void remove() {
    _overlay?.remove();
    _overlay = null;
  }
}
