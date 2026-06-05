import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../glassmorphism_container.dart';

// ============================================================================
// SettingsSection — 设置分组容器
// ============================================================================

/// 通用设置分组 widget：标题 + Card 包裹的子项列表
///
/// 用于设置页面中将 ListTile / SwitchListTile 等归组的场景。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// showGlassOptionDialog — 泛型毛玻璃选项弹窗
// ============================================================================

/// 通用毛玻璃选项选择对话框
///
/// [T] 选项值类型，[options] 为 `(值, 显示文本, 是否选中)` 三元组列表。
/// 返回用户点击的选项值，取消或关闭返回 `null`。
///
/// 示例:
/// ```dart
/// final size = await showGlassOptionDialog<int>(
///   context,
///   title: '最大缓存大小',
///   icon: LucideIcons.hardDrive,
///   options: [(128, '128 MB', false), (256, '256 MB', true)],
/// );
/// ```
Future<T?> showGlassOptionDialog<T>(
  BuildContext context, {
  required String title,
  required IconData icon,
  String? subtitle,
  required List<(T, String, bool)> options,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scaleAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ).drive(Tween(begin: 0.92, end: 1.0));
      final fadeAnim = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ).drive(Tween(begin: 0.0, end: 1.0));
      return ScaleTransition(
        scale: scaleAnim,
        child: FadeTransition(opacity: fadeAnim, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dialogWidth = screenWidth >= 600 ? 380.0 : screenWidth - 48.0;
      final colorScheme = Theme.of(context).colorScheme;
      final theme = Theme.of(context);

      return Center(
        child: SizedBox(
          width: dialogWidth,
          child: GlassmorphismContainer(
            borderRadius: 16,
            sigmaX: 20,
            sigmaY: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subtitle,
                            style: TextStyle(fontSize: 13, color: theme.hintColor),
                          ),
                        ),
                      ),
                    const Divider(height: 1),
                    // Options
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final (value, label, isSelected) = options[index];
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.circle,
                              size: 20,
                              color: isSelected
                                  ? colorScheme.primary
                                  : theme.hintColor,
                            ),
                            title: Text(label),
                            selected: isSelected,
                            onTap: () => Navigator.of(context).pop(value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================================
// formatBytes — 字节格式化工具
// ============================================================================

/// 将字节数格式化为人类可读的字符串（B / KB / MB / GB）
String formatBytes(int? bytes) {
  if (bytes == null) return '未知';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
