class SyncTaskModel {
  final String id;
  final String trigger;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? finishedAt;

  const SyncTaskModel({
    required this.id,
    required this.trigger,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.finishedAt,
  });

  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  String get triggerLabel => switch (trigger) {
        'initial_sync' => '初始同步',
        'continuous' => '持续同步',
        'manual' => '手动同步',
        'wcf_event' => '镜像事件',
        'hydration' => '按需水合',
        _ => trigger,
      };

  String get statusLabel => switch (status) {
        'pending' => '等待中',
        'running' => '执行中',
        'completed' => '已完成',
        'failed' => '失败',
        'cancelled' => '已取消',
        _ => status,
      };

  double get progress =>
      totalCount > 0 ? completedCount / totalCount : 0.0;
}

class SyncTaskItemModel {
  final int id;
  final String taskId;
  final String relativePath;
  final String actionType;
  final String status;
  final int fileSize;
  final String? errorMessage;
  final String createdAt;
  final String updatedAt;

  const SyncTaskItemModel({
    required this.id,
    required this.taskId,
    required this.relativePath,
    required this.actionType,
    required this.status,
    required this.fileSize,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  String get actionLabel => switch (actionType) {
        'upload' => '上传',
        'download' => '下载',
        'delete_local' => '删本地',
        'delete_remote' => '删远程',
        'rename' => '重命名',
        'move' => '移动',
        'mkdir_remote' => '创建远程目录',
        'mkdir_local' => '创建本地目录',
        'conflict_resolve' => '冲突解决',
        'create_placeholder' => '创建占位符',
        'hydration' => '水合下载',
        _ => actionType,
      };

  String get statusLabel => switch (status) {
        'pending' => '未开始',
        'running' => '进行中',
        'completed' => '已完成',
        'failed' => '失败',
        'skipped' => '跳过',
        _ => status,
      };

  String get filename {
    final parts = relativePath.split('/');
    return parts.isNotEmpty ? parts.last : relativePath;
  }
}
