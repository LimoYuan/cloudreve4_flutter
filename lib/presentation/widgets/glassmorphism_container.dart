import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double sigmaX;
  final double sigmaY;
  final EdgeInsetsGeometry? padding;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.sigmaX = 10,
    this.sigmaY = 10,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final size = MediaQuery.sizeOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    // BackdropFilter is one of the most expensive effects on low-end phones.
    // Keep the same translucent appearance but skip the blur on mobile.
    final shouldBlur = !disableAnimations && !isMobile && size.shortestSide >= 700;

    final bgColor = isLight
        ? Colors.white.withValues(alpha: shouldBlur ? 0.72 : 0.94)
        : const Color(0xFF0F172A).withValues(alpha: shouldBlur ? 0.62 : 0.96);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    if (!shouldBlur || sigmaX <= 0 || sigmaY <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigmaX.clamp(0, 8),
          sigmaY: sigmaY.clamp(0, 8),
        ),
        child: content,
      ),
    );
  }
}
