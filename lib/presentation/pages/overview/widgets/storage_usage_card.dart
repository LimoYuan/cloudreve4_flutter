import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';

class StorageUsageCard extends StatefulWidget {
  const StorageUsageCard({super.key});

  @override
  State<StorageUsageCard> createState() => _StorageUsageCardState();
}

class _StorageUsageCardState extends State<StorageUsageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _targetPercentage = 0;
  double _lastTarget = -1;
  bool _hasRealData = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1120),
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _animatedProgress {
    final t = _controller.value;
    // Phase 1 (0-0.46): easeOutCubic 0→1
    // Phase 2 (0.46-1.0): easeOutBack 1→target
    if (t <= 0.0) return 0;
    if (t <= 0.46) {
      final local = t / 0.46;
      final eased = 1 - pow(1 - local, 3).toDouble();
      return eased * _targetPercentage / 100;
    }
    final local = (t - 0.46) / 0.54;
    // easeOutBack
    final c1 = 1.70158;
    final c3 = c1 + 1;
    final eased = 1 + c3 * pow(local - 1, 3) + c1 * pow(local - 1, 2);
    return _targetPercentage / 100 * eased;
  }

  void _restartIfNeeded(double percentage, bool hasCapacity) {
    if (!hasCapacity && !_hasRealData) return;
    if (hasCapacity) _hasRealData = true;
    if (percentage != _lastTarget) {
      _lastTarget = percentage;
      _targetPercentage = percentage;
      // 必须延迟到 build 完成后启动动画，否则 controller listener 中的
      // setState() 会在 build 阶段被调用而抛异常
      Future.microtask(() {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<UserSettingProvider>(
      builder: (context, userSetting, _) {
        final capacity = userSetting.capacity;
        final total = capacity?.total ?? 0;
        final percentage = capacity?.usagePercentage ?? 0;

        _restartIfNeeded(percentage, capacity != null);

        final displayUsed = (total * _animatedProgress).round();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.hardDrive,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '存储空间',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 90,
                    child: CustomPaint(
                      painter: _SemiCircleProgressPainter(
                        progress: _animatedProgress.clamp(0.0, 1.0),
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${_formatBytes(displayUsed)} / ${_formatBytes(total)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '已使用 ${(_animatedProgress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _SemiCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _SemiCircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final center = Offset(size.width / 2, size.height);
    final radius = min(size.width / 2, size.height) - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      bgPaint,
    );

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sweepAngle = pi * progress.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SemiCircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
