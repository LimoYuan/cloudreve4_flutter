import 'package:cloudreve4_flutter/core/utils/app_logger.dart';

/// 离线下载任务状态
enum RemoteDownloadStatus {
  queued,
  running,
  completed,
  error,
  suspending,
  suspended;

  static RemoteDownloadStatus fromString(String value) {
    return RemoteDownloadStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RemoteDownloadStatus.queued,
    );
  }

  String get text {
    switch (this) {
      case RemoteDownloadStatus.queued:
        return '排队中';
      case RemoteDownloadStatus.running:
        return '下载中';
      case RemoteDownloadStatus.completed:
        return '已完成';
      case RemoteDownloadStatus.error:
        return '出错';
      case RemoteDownloadStatus.suspending:
        return '暂停中';
      case RemoteDownloadStatus.suspended:
        return '已暂停';
    }
  }

  bool get isOngoing =>
      this == RemoteDownloadStatus.queued ||
      this == RemoteDownloadStatus.running ||
      this == RemoteDownloadStatus.suspending ||
      this == RemoteDownloadStatus.suspended;
}

/// 种子文件信息
class DownloadFileInfo {
  final int index;
  final String name;
  final int size;
  final double progress;
  final bool selected;

  const DownloadFileInfo({
    required this.index,
    required this.name,
    required this.size,
    required this.progress,
    required this.selected,
  });

  factory DownloadFileInfo.fromJson(Map<String, dynamic> json) {
    return DownloadFileInfo(
      index: json['index'] as int,
      name: json['name'] as String,
      size: json['size'] as int,
      progress: (json['progress'] as num).toDouble(),
      selected: json['selected'] as bool? ?? true,
    );
  }
}

/// 下载详情（aria2 返回的信息）
class DownloadInfo {
  final String name;
  final String state; // downloading, completed, seeding, paused
  final int total;
  final int downloaded;
  final int downloadSpeed;
  final int uploaded;
  final int uploadSpeed;
  final String hash;
  final List<DownloadFileInfo> files;

  const DownloadInfo({
    required this.name,
    required this.state,
    required this.total,
    required this.downloaded,
    required this.downloadSpeed,
    required this.uploaded,
    required this.uploadSpeed,
    required this.hash,
    required this.files,
  });

  double get progress => total > 0 ? downloaded / total : 0.0;

  String get speedText {
    if (downloadSpeed <= 0) return '';
    if (downloadSpeed < 1024) return '$downloadSpeed B/s';
    if (downloadSpeed < 1024 * 1024) return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    return '${(downloadSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    final filesList = json['files'] as List<dynamic>? ?? [];
    return DownloadInfo(
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      downloadSpeed: (json['download_speed'] as num?)?.toInt() ?? 0,
      uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
      uploadSpeed: (json['upload_speed'] as num?)?.toInt() ?? 0,
      hash: json['hash'] as String? ?? '',
      files: filesList.map((f) => DownloadFileInfo.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

/// 任务摘要
class TaskSummary {
  final String phase;
  final String dst;
  final int failed;
  final String src;
  final String srcStr;
  final DownloadInfo? download;

  const TaskSummary({
    required this.phase,
    required this.dst,
    required this.failed,
    required this.src,
    required this.srcStr,
    this.download,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      phase: json['phase'] as String? ?? '',
      dst: json['props']?['dst'] as String? ?? '',
      failed: (json['props']?['failed'] as num?)?.toInt() ?? 0,
      src: json['props']?['src'] as String? ?? '',
      srcStr: json['props']?['src_str'] as String? ?? '',
      download: json['props']?['download'] != null
          ? DownloadInfo.fromJson(json['props']!['download'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 离线下载任务模型
class RemoteDownloadTaskModel {
  final String id;
  final RemoteDownloadStatus status;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int duration;
  final String? error;
  final TaskSummary? summary;

  const RemoteDownloadTaskModel({
    required this.id,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.duration,
    this.error,
    this.summary,
  });

  String getFileNameFromUrl(String url) {
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return '';
      final fileName = segments.last;
      return fileName.isNotEmpty ? fileName : '';
    } catch (e) {
      return '';
    }
  }
  /// 显示名称：优先使用 download.name，其次 srcStr，最后 id
  String get displayName {
    final dlName = summary?.download?.name;
    if (dlName != null && dlName.isNotEmpty) {
      return dlName;
    } else {
      final srcStr = summary?.srcStr;
      if (srcStr == null || srcStr.isNotEmpty) return id;

      final fileName = getFileNameFromUrl(srcStr);
      if (fileName.isEmpty) return id;
      return fileName;
    }
  }

  factory RemoteDownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return RemoteDownloadTaskModel(
      id: json['id'] as String,
      status: RemoteDownloadStatus.fromString(json['status'] as String),
      type: json['type'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      summary: json['summary'] != null
          ? TaskSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }
}
