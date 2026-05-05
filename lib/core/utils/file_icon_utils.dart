import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/file_model.dart';
import 'file_utils.dart';

/// 文件图标、颜色、类型标签统一管理
class FileIconUtils {
  // ---- 文件图标 ----

  // 后缀分类映射：安装包/可执行/字体/数据库/镜像等
  static const _installerExtensions = {'apk', 'exe', 'msi', 'dmg', 'deb', 'rpm', 'appimage', 'snap'};
  static const _executableExtensions = {'sh', 'bat', 'cmd', 'ps1', 'bin', 'run'};
  static const _fontExtensions = {'ttf', 'otf', 'woff', 'woff2', 'eot'};
  static const _databaseExtensions = {'db', 'sqlite', 'sqlite3', 'mdb', 'sql'};
  static const _imageDiskExtensions = {'iso', 'img', 'vmdk', 'vdi', 'qcow2'};
  static const _torrentExtensions = {'torrent'};

  static IconData getFileIcon(String fileName) {
    if (FileUtils.isImageFile(fileName)) return LucideIcons.image;
    if (FileUtils.isVideoFile(fileName)) return LucideIcons.video;
    if (FileUtils.isAudioFile(fileName)) return LucideIcons.music;
    if (FileUtils.isPdfFile(fileName)) return LucideIcons.fileText;
    if (FileUtils.isTextFile(fileName)) return LucideIcons.fileText;
    if (FileUtils.isCodeFile(fileName)) return LucideIcons.code;
    if (FileUtils.isArchiveFile(fileName)) return LucideIcons.archive;
    if (FileUtils.isDocumentFile(fileName)) return LucideIcons.file;
    // fallback: 按后缀分类
    final ext = FileUtils.getFileExtension(fileName);
    if (_installerExtensions.contains(ext)) return LucideIcons.package;
    if (_executableExtensions.contains(ext)) return LucideIcons.terminal;
    if (_fontExtensions.contains(ext)) return LucideIcons.type;
    if (_databaseExtensions.contains(ext)) return LucideIcons.database;
    if (_imageDiskExtensions.contains(ext)) return LucideIcons.hardDrive;
    if (_torrentExtensions.contains(ext)) return LucideIcons.download;
    return LucideIcons.file;
  }

  static Color getFileIconColor(String fileName) {
    if (FileUtils.isImageFile(fileName)) return const Color(0xFFA855F7);
    if (FileUtils.isVideoFile(fileName)) return const Color(0xFFF97316);
    if (FileUtils.isAudioFile(fileName)) return const Color(0xFF3B82F6);
    if (FileUtils.isPdfFile(fileName)) return const Color(0xFFEF4444);
    if (FileUtils.isTextFile(fileName)) return const Color(0xFF14B8A6);
    if (FileUtils.isCodeFile(fileName)) return const Color(0xFF06B6D4);
    if (FileUtils.isArchiveFile(fileName)) return const Color(0xFFF59E0B);
    if (FileUtils.isDocumentFile(fileName)) return const Color(0xFF6366F1);
    // fallback: 按后缀分类
    final ext = FileUtils.getFileExtension(fileName);
    if (_installerExtensions.contains(ext)) return const Color(0xFF22C55E);
    if (_executableExtensions.contains(ext)) return const Color(0xFF10B981);
    if (_fontExtensions.contains(ext)) return const Color(0xFF8B5CF6);
    if (_databaseExtensions.contains(ext)) return const Color(0xFF6366F1);
    if (_imageDiskExtensions.contains(ext)) return const Color(0xFF64748B);
    if (_torrentExtensions.contains(ext)) return const Color(0xFF06B6D4);
    // 真正未知：基于后缀名 hash 生成稳定颜色
    if (ext.isNotEmpty) return _stableColor(ext);
    return const Color(0xFF64748B);
  }

  /// 基于字符串生成稳定的颜色（避免同类型不同后缀撞色）
  static Color _stableColor(String key) {
    final hash = key.hashCode.abs();
    const palette = [
      Color(0xFF64748B), Color(0xFF6366F1), Color(0xFF8B5CF6),
      Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF59E0B),
      Color(0xFF22C55E), Color(0xFF0EA5E9), Color(0xFFEF4444),
    ];
    return palette[hash % palette.length];
  }

  /// 文件类型中文标签
  static String getFileTypeLabel(String fileName, {bool isFolder = false}) {
    if (isFolder) return '文件夹';
    if (FileUtils.isImageFile(fileName)) return '图片';
    if (FileUtils.isVideoFile(fileName)) return '视频';
    if (FileUtils.isAudioFile(fileName)) return '音频';
    if (FileUtils.isPdfFile(fileName)) return 'PDF';
    if (FileUtils.isTextFile(fileName)) {
      final ext = FileUtils.getFileExtension(fileName);
      return ext.isNotEmpty ? '${ext.toUpperCase()}文件' : '文本';
    }
    if (FileUtils.isCodeFile(fileName)) {
      final ext = FileUtils.getFileExtension(fileName);
      return ext.isNotEmpty ? '${ext.toUpperCase()}文件' : '代码';
    }
    if (FileUtils.isArchiveFile(fileName)) return '压缩包';
    if (FileUtils.isDocumentFile(fileName)) return '文档';
    // fallback: 未知后缀直接用大写后缀名
    final ext = FileUtils.getFileExtension(fileName);
    if (ext.isNotEmpty) return '${ext.toUpperCase()}文件';
    return '文件';
  }

  // ---- 语义化文件夹图标 ----

  static final _folderIconMap = <String, IconData>{
    'DOCUMENTS': LucideIcons.fileText,
    'DOCS': LucideIcons.fileText,
    'PICTURES': LucideIcons.image,
    'PHOTOS': LucideIcons.image,
    'IMAGES': LucideIcons.image,
    'VIDEOS': LucideIcons.video,
    'MOVIES': LucideIcons.video,
    'MUSIC': LucideIcons.music,
    'AUDIO': LucideIcons.music,
    'DOWNLOADS': LucideIcons.download,
    'GAMES': LucideIcons.gamepad2,
    'OS_IMAGE': LucideIcons.hardDrive,
    'DOCKER': LucideIcons.container,
    'CONTAINERS': LucideIcons.container,
    'ARIA2': LucideIcons.download,
    'BACKUP': LucideIcons.archive,
    'DESKTOP': LucideIcons.monitor,
    'FAVORITES': LucideIcons.star,
    'SHARE': LucideIcons.share2,
    'SHARED': LucideIcons.share2,
    'TRASH': LucideIcons.trash2,
    'RECYCLE': LucideIcons.trash2,
  };

  static final _folderColorMap = <String, Color>{
    'DOCUMENTS': const Color(0xFF3B82F6),
    'DOCS': const Color(0xFF3B82F6),
    'PICTURES': const Color(0xFFA855F7),
    'PHOTOS': const Color(0xFFA855F7),
    'IMAGES': const Color(0xFFA855F7),
    'VIDEOS': const Color(0xFFF97316),
    'MOVIES': const Color(0xFFF97316),
    'MUSIC': const Color(0xFF3B82F6),
    'AUDIO': const Color(0xFF3B82F6),
    'DOWNLOADS': const Color(0xFF22C55E),
    'GAMES': const Color(0xFF8B5CF6),
    'OS_IMAGE': const Color(0xFF64748B),
    'DOCKER': const Color(0xFF0EA5E9),
    'CONTAINERS': const Color(0xFF0EA5E9),
    'ARIA2': const Color(0xFF06B6D4),
    'BACKUP': const Color(0xFFF59E0B),
    'DESKTOP': const Color(0xFF6366F1),
    'FAVORITES': const Color(0xFFEAB308),
    'SHARE': const Color(0xFF14B8A6),
    'SHARED': const Color(0xFF14B8A6),
    'TRASH': const Color(0xFFEF4444),
    'RECYCLE': const Color(0xFFEF4444),
  };

  static final _folderKeywords = <String, IconData>{
    '文档': LucideIcons.fileText,
    '图片': LucideIcons.image,
    '相册': LucideIcons.image,
    '视频': LucideIcons.video,
    '音乐': LucideIcons.music,
    '下载': LucideIcons.download,
    '游戏': LucideIcons.gamepad2,
    '备份': LucideIcons.archive,
    '桌面': LucideIcons.monitor,
    '收藏': LucideIcons.star,
    '分享': LucideIcons.share2,
    '回收站': LucideIcons.trash2,
  };

  static final _folderKeywordColors = <String, Color>{
    '文档': const Color(0xFF3B82F6),
    '图片': const Color(0xFFA855F7),
    '相册': const Color(0xFFA855F7),
    '视频': const Color(0xFFF97316),
    '音乐': const Color(0xFF3B82F6),
    '下载': const Color(0xFF22C55E),
    '游戏': const Color(0xFF8B5CF6),
    '备份': const Color(0xFFF59E0B),
    '桌面': const Color(0xFF6366F1),
    '收藏': const Color(0xFFEAB308),
    '分享': const Color(0xFF14B8A6),
    '回收站': const Color(0xFFEF4444),
  };

  static IconData getFolderIcon(String folderName) {
    final upper = folderName.toUpperCase();
    if (_folderIconMap.containsKey(upper)) return _folderIconMap[upper]!;
    for (final entry in _folderKeywords.entries) {
      if (folderName.contains(entry.key)) return entry.value;
    }
    return LucideIcons.folder;
  }

  static Color? getFolderIconColor(String folderName) {
    final upper = folderName.toUpperCase();
    if (_folderColorMap.containsKey(upper)) return _folderColorMap[upper]!;
    for (final entry in _folderKeywordColors.entries) {
      if (folderName.contains(entry.key)) return entry.value;
    }
    return null; // 使用 colorScheme.primary 作为默认
  }

  // ---- 统一图标容器组件 ----

  static Widget buildIconWidget({
    required BuildContext context,
    required FileModel file,
    double size = 36,
    double iconSize = 20,
    double borderRadius = 8,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (file.isFolder) {
      final folderColor = getFolderIconColor(file.name) ?? colorScheme.primary;
      final folderIcon = getFolderIcon(file.name);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: folderColor.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(folderIcon, color: folderColor, size: iconSize),
      );
    }

    final icon = getFileIcon(file.name);
    final iconColor = getFileIconColor(file.name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}
