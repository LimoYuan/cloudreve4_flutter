import 'package:flutter/material.dart';

/// 下载状态
enum DownloadStatus {
  waiting,    // 等待中
  downloading, // 下载中
  completed,   // 已完成
  paused,      // 已暂停
  failed,      // 失败
  cancelled,    // 已取消
}

/// 下载任务模型
class DownloadTaskModel {
  final String id;
  final String fileName;
  final String fileUri;       // cloudreve URI
  final String? downloadUrl;   // 实际下载URL
  final int fileSize;
  final String savePath;
  DownloadStatus status;
  int downloadedBytes;
  final DateTime createdAt;
  DateTime? completedAt;
  String? errorMessage;

  double get progress => fileSize > 0 ? downloadedBytes / fileSize : 0.0;
  int get remainingBytes => fileSize - downloadedBytes;
  String get progressText {
    if (status == DownloadStatus.completed) {
      return '100%';
    }
    debugPrint('DownloadTaskModel -> 已经初始化, status: $status');
    final percent = (progress * 100).toStringAsFixed(1);
    debugPrint('DownloadTaskModel -> 已经初始化, percent: $percent');
    return '$percent%';
  }
  String get statusText {
    switch (status) {
      case DownloadStatus.waiting:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.failed:
        return '下载失败';
      case DownloadStatus.cancelled:
        return '已取消';
    }
  }

  DownloadTaskModel({
    required this.id,
    required this.fileName,
    required this.fileUri,
    this.downloadUrl,
    required this.fileSize,
    required this.savePath,
    this.status = DownloadStatus.waiting,
    this.downloadedBytes = 0,
    DateTime? createdAt,
    this.completedAt,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  DownloadTaskModel copyWith({
    String? id,
    String? fileName,
    String? fileUri,
    String? downloadUrl,
    int? fileSize,
    String? savePath,
    DownloadStatus? status,
    int? downloadedBytes,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return DownloadTaskModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileUri: fileUri ?? this.fileUri,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUri': fileUri,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'savePath': savePath,
      'status': status.index,
      'downloadedBytes': downloadedBytes,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory DownloadTaskModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskModel(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileUri: json['fileUri'] as String,
      downloadUrl: json['downloadUrl'] as String?,
      fileSize: json['fileSize'] as int,
      savePath: json['savePath'] as String,
      status: DownloadStatus.values[json['status'] as int? ?? 0],
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
