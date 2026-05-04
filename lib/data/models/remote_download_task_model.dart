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
  final String state;
  final int total;
  final int downloaded;
  final int downloadSpeed;
  final int uploaded;
  final int uploadSpeed;
  final String hash;
  final List<DownloadFileInfo> files;
  final int numPieces;

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
    this.numPieces = 0,
  });

  double get progress => total > 0 ? downloaded / total : 0.0;

  String get speedText {
    if (downloadSpeed <= 0) return '';
    if (downloadSpeed < 1024) return '$downloadSpeed B/s';
    if (downloadSpeed < 1024 * 1024) {
      return '${(downloadSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
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
      files: filesList
          .map((f) => DownloadFileInfo.fromJson(f as Map<String, dynamic>))
          .toList(),
      numPieces: (json['num_pieces'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 处理节点信息
class TaskNode {
  final String id;
  final String name;
  final String type;

  const TaskNode({
    required this.id,
    required this.name,
    required this.type,
  });

  String get displayName {
    switch (type) {
      case 'master':
        return '$name（本机）';
      default:
        return name;
    }
  }

  factory TaskNode.fromJson(Map<String, dynamic> json) {
    return TaskNode(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
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
          ? DownloadInfo.fromJson(
              json['props']!['download'] as Map<String, dynamic>)
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
  final TaskNode? node;
  final TaskSummary? summary;
  final int resumeTime;
  final int retryCount;

  const RemoteDownloadTaskModel({
    required this.id,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.duration,
    this.error,
    this.node,
    this.summary,
    this.resumeTime = 0,
    this.retryCount = 0,
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
      if (srcStr == null || srcStr.isEmpty) return id;

      final fileName = getFileNameFromUrl(srcStr);
      if (fileName.isEmpty) return id;
      return fileName;
    }
  }

  /// 格式化耗时（duration 单位为毫秒）
  String get durationText {
    final seconds = duration ~/ 1000;
    if (seconds <= 0) return '-';
    if (seconds < 60) return '$seconds 秒';
    if (seconds < 3600) return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours 小时 $minutes 分';
  }

  /// 输入源显示文本
  String get srcDisplayText {
    final srcStr = summary?.srcStr;
    if (srcStr != null && srcStr.isNotEmpty) return srcStr;
    final src = summary?.src;
    if (src!.isNotEmpty) {
      // 从 cloudreve URI 提取文件名
      final parts = src.split('/');
      return parts.isNotEmpty ? parts.last : src;
    }
    return '-';
  }

  /// 输出目标显示文本（从 cloudreve URI 转换为相对路径）
  String get dstDisplayText {
    final dst = summary?.dst ?? '';
    if (dst.isEmpty) return '-';
    if (dst.startsWith('cloudreve://my')) {
      final relative = dst.replaceFirst('cloudreve://my', '');
      return relative.isEmpty ? '/' : relative;
    }
    return dst;
  }

  factory RemoteDownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return RemoteDownloadTaskModel(
      id: json['id'] as String,
      status: RemoteDownloadStatus.fromString(json['status'] as String),
      type: json['type'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : DateTime.now(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      node: json['node'] != null
          ? TaskNode.fromJson(json['node'] as Map<String, dynamic>)
          : null,
      summary: json['summary'] != null
          ? TaskSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      resumeTime: (json['resume_time'] as num?)?.toInt() ?? 0,
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
    );
  }
}
