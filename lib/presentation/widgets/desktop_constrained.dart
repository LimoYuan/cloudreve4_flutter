import 'package:flutter/material.dart';

/// 桌面端内容宽度约束
/// 屏幕宽度 >= 1000px 时，将子组件内容限制在 maxContentWidth 内居中显示
class DesktopConstrained extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;

  const DesktopConstrained({
    super.key,
    required this.child,
    this.maxContentWidth = 800,
  });

  static const double desktopBreakpoint = 1000;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= desktopBreakpoint) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}
