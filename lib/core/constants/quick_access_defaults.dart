import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuickAccessConfig {
  final String id;
  final String label;
  final IconData icon;
  final String path;
  final Color color;
  final bool isDefault;

  const QuickAccessConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    required this.color,
    this.isDefault = false,
  });

  QuickAccessConfig copyWith({String? label, String? path, IconData? icon, Color? color}) =>
      QuickAccessConfig(
        id: id,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        path: path ?? this.path,
        color: color ?? this.color,
        isDefault: isDefault,
      );

  static const storageKey = 'quick_access_shortcuts_v2';

  static const defaults = [
    QuickAccessConfig(id: 'img', label: '图片', icon: LucideIcons.image, path: 'cloudreve://my?category=image', color: Color(0xFFF0ABFC), isDefault: true),
    QuickAccessConfig(id: 'vid', label: '视频', icon: LucideIcons.video, path: 'cloudreve://my?category=video', color: Color(0xFFFCD34D), isDefault: true),
    QuickAccessConfig(id: 'doc', label: '文档', icon: LucideIcons.fileText, path: 'cloudreve://my?category=document', color: Color(0xFF93C5FD), isDefault: true),
    QuickAccessConfig(id: 'mus', label: '音乐', icon: LucideIcons.music, path: 'cloudreve://my?category=audio', color: Color(0xFF86EFAC), isDefault: true),
  ];

  static const iconPool = <IconData>[
    LucideIcons.image,
    LucideIcons.video,
    LucideIcons.fileText,
    LucideIcons.music,
    LucideIcons.folder,
    LucideIcons.download,
    LucideIcons.archive,
    LucideIcons.code,
    LucideIcons.bookOpen,
    LucideIcons.camera,
    LucideIcons.film,
    LucideIcons.headphones,
  ];

  static const colorPool = <Color>[
    Color(0xFFF0ABFC),
    Color(0xFFFCD34D),
    Color(0xFF93C5FD),
    Color(0xFF86EFAC),
    Color(0xFFFCA5A5),
    Color(0xFFFDBA74),
    Color(0xFFC4B5FD),
    Color(0xFF67E8F9),
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconCode': icon.codePoint,
        'path': path,
        'color': color.toARGB32(),
        'isDefault': isDefault,
      };

  factory QuickAccessConfig.fromJson(Map<String, dynamic> json) {
    final iconCode = json['iconCode'] as int? ?? LucideIcons.folder.codePoint;
    final matchedIcon = iconPool.cast<IconData?>().firstWhere(
          (i) => i!.codePoint == iconCode,
          orElse: () => LucideIcons.folder,
        )!;
    return QuickAccessConfig(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label'] as String,
      icon: matchedIcon,
      path: json['path'] as String,
      color: Color(json['color'] as int? ?? 0xFF93C5FD),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  static List<QuickAccessConfig> parseSaved(String saved) {
    try {
      final list = jsonDecode(saved) as List<dynamic>;
      return list.map((e) => QuickAccessConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return List.from(defaults);
    }
  }

  static String serialize(List<QuickAccessConfig> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  /// 迁移旧格式（分号分隔的路径列表）
  static List<QuickAccessConfig> migrateV1(String saved) {
    final parts = saved.split(';');
    final items = <QuickAccessConfig>[];
    for (int i = 0; i < defaults.length; i++) {
      if (i < parts.length && parts[i].isNotEmpty) {
        items.add(defaults[i].copyWith(path: parts[i]));
      } else {
        items.add(defaults[i]);
      }
    }
    return items;
  }
}

extension ColorDarken on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
