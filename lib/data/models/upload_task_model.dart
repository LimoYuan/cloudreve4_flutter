import 'dart:io';

/// 上传状态
enum UploadStatus {
  waiting,   // 等待中
  uploading, // 上传中
  completed, // 已完成
  paused,    // 已暂停
  failed,    // 失败
  cancelled, // 已取消
}

/// 上传会话模型（从 API 返回的上传会话信息）
class UploadSessionModel {
  final String sessionId;
  final String? uploadId;
  final int chunkSize;
  final int expires;
  final List<String>? uploadUrls;
  final String? credential;
  final String? completeUrl;
  final StoragePolicyModel storagePolicy;
  final String? mimeType;
  final String? uploadPolicy;
  final String? callbackSecret;

  UploadSessionModel({
    required this.sessionId,
    this.uploadId,
    required this.chunkSize,
    required this.expires,
    this.uploadUrls,
    this.credential,
    this.completeUrl,
    required this.storagePolicy,
    this.mimeType,
    this.uploadPolicy,
    this.callbackSecret,
  });

  factory UploadSessionModel.fromJson(Map<String, dynamic> json) {
    return UploadSessionModel(
      sessionId: json['session_id'] as String,
      uploadId: json['upload_id'] as String?,
      chunkSize: json['chunk_size'] as int,
      expires: json['expires'] as int,
      uploadUrls: json['upload_urls'] != null
          ? (json['upload_urls'] as List).map((e) => e as String).toList()
          : null,
      credential: json['credential'] as String?,
      completeUrl: json['completeURL'] as String?,
      storagePolicy: StoragePolicyModel.fromJson(json['storage_policy'] as Map<String, dynamic>),
      mimeType: json['mime_type'] as String?,
      uploadPolicy: json['upload_policy'] as String?,
      callbackSecret: json['callback_secret'] as String?,
    );
  }

  /// 是否支持分片上传
  bool get isMultipartEnabled => chunkSize > 0;

  /// 是否使用中继上传（上传到 Cloudreve 服务器）
  bool get isRelayUpload => storagePolicy.relay == true || storagePolicy.type == 'local';
}

/// 存储策略模型
class StoragePolicyModel {
  final String id;
  final String name;
  final String type;
  final int maxSize;
  final bool? relay;

  StoragePolicyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.maxSize,
    this.relay,
  });

  factory StoragePolicyModel.fromJson(Map<String, dynamic> json) {
    return StoragePolicyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      maxSize: json['max_size'] as int,
      relay: json['relay'] as bool?,
    );
  }
}

/// 上传任务模型
class UploadTaskModel {
  final String id;
  final File file;
  final String fileName;
  final int fileSize;
  final String targetPath; // 目标路径，例如 cloudreve://my/subfolder
  final DateTime createdAt;
  DateTime? completedAt;
  final UploadStatus status;
  final int uploadedBytes;
  final double progress;
  final int uploadedChunks; // 已上传的分片数量
  final int totalChunks; // 总分片数量
  final String? errorMessage;
  final UploadSessionModel? session; // 上传会话信息
  final int speed; // 上传速度，字节/秒

  UploadTaskModel({
    required this.id,
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.targetPath,
    DateTime? createdAt,
    this.completedAt,
    UploadStatus? status,
    this.uploadedBytes = 0,
    this.progress = 0,
    this.uploadedChunks = 0,
    this.totalChunks = 1,
    this.errorMessage,
    this.session,
    this.speed = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
      status = status ?? UploadStatus.waiting;

  /// 计算总分片数
  int calculateTotalChunks(int chunkSize) {
    if (chunkSize <= 0) return 1;
    return (fileSize / chunkSize).ceil();
  }

  /// 获取状态文本
  String get statusText {
    switch (status) {
      case UploadStatus.waiting:
        return '等待中';
      case UploadStatus.uploading:
        return '上传中...';
      case UploadStatus.completed:
        return '上传完成';
      case UploadStatus.paused:
        return '已暂停';
      case UploadStatus.failed:
        return '上传失败';
      case UploadStatus.cancelled:
        return '已取消';
    }
  }

  /// 获取进度文本
  String get progressText {
    if (status == UploadStatus.completed) {
      return '100%';
    }
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  /// 获取可读的文件大小
  String get readableFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 获取可读的上传速度
  String get speedText {
    if (speed <= 0) return '';
    if (speed < 1024) return '$speed B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// 克隆任务
  UploadTaskModel copyWith({
    UploadStatus? status,
    int? uploadedBytes,
    double? progress,
    int? uploadedChunks,
    int? totalChunks,
    String? errorMessage,
    UploadSessionModel? session,
    DateTime? completedAt,
    int? speed,
  }) {
    return UploadTaskModel(
      id: id,
      file: file,
      fileName: fileName,
      fileSize: fileSize,
      targetPath: targetPath,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      progress: progress ?? this.progress,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
      totalChunks: totalChunks ?? this.totalChunks,
      errorMessage: errorMessage ?? this.errorMessage,
      session: session ?? this.session,
      speed: speed ?? this.speed,
    );
  }

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_path': file.path,
      'file_name': fileName,
      'file_size': fileSize,
      'target_path': targetPath,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status.index,
      'uploaded_bytes': uploadedBytes,
      'progress': progress,
      'uploaded_chunks': uploadedChunks,
      'total_chunks': totalChunks,
      'error_message': errorMessage,
      'speed': speed,
    };
  }

  /// 从 JSON 创建（用于持久化恢复）
  factory UploadTaskModel.fromJson(Map<String, dynamic> json) {
    return UploadTaskModel(
      id: json['id'] as String,
      file: File(json['file_path'] as String),
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      targetPath: json['target_path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      status: UploadStatus.values[json['status'] as int],
      uploadedBytes: json['uploaded_bytes'] as int,
      progress: json['progress'] as double,
      uploadedChunks: json['uploaded_chunks'] as int,
      totalChunks: json['total_chunks'] as int,
      errorMessage: json['error_message'] as String?,
      speed: json['speed'] as int? ?? 0,
    );
  }
}
