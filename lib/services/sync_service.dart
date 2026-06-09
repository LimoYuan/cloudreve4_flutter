import 'dart:async';

import '../core/utils/app_logger.dart';
import '../data/models/sync_config_model.dart';
import '../data/models/sync_event_model.dart';
import '../data/models/sync_status_model.dart';
import '../data/models/sync_task_model.dart';
import '../src/rust/api/ffi.dart' as ffi;
import '../src/rust/api/ffi_types.dart' as ffi_types;
import '../src/rust/frb_generated.dart' show RustSyncApi;

/// 同步服务单例 - 桥接 Flutter UI 和 Rust 同步引擎
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _initialized = false;
  bool _rustBridgeInitialized = false;
  Future<void>? _rustBridgeInitFuture;
  StreamSubscription<ffi_types.SyncEventFfi>? _rustEventSub;

  /// 事件流，供 SyncProvider 订阅
  final _eventController = StreamController<SyncEventModel>.broadcast();
  Stream<SyncEventModel> get events => _eventController.stream;

  /// Ensure flutter_rust_bridge has loaded the native sync library before any FFI call.
  Future<void> _ensureRustBridgeInitialized() async {
    if (_rustBridgeInitialized) {
      return;
    }

    final inFlight = _rustBridgeInitFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initRustBridgeOnce();
    _rustBridgeInitFuture = future;

    try {
      await future;
    } finally {
      if (identical(_rustBridgeInitFuture, future)) {
        _rustBridgeInitFuture = null;
      }
    }
  }

  Future<void> _initRustBridgeOnce() async {
    if (_rustBridgeInitialized) {
      return;
    }

    try {
      await RustSyncApi.init();
      _rustBridgeInitialized = true;
      AppLogger.i('[FFI] RustSyncApi initialized by SyncService');
    } catch (e) {
      if (_isRustBridgeAlreadyInitializedError(e)) {
        _rustBridgeInitialized = true;
        AppLogger.d('[FFI] RustSyncApi was already initialized');
        return;
      }

      AppLogger.e('[FFI] RustSyncApi init failed before sync call: $e');
      rethrow;
    }
  }

  bool _isRustBridgeAlreadyInitializedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('already initialized') ||
        message.contains('already been initialized') ||
        message.contains('initialize flutter_rust_bridge twice') ||
        message.contains('initialized twice');
  }

  /// 初始化同步引擎（已初始化时更新配置）
  Future<void> init(SyncConfigModel config) async {
    await _ensureRustBridgeInitialized();
    if (_initialized) {
      AppLogger.d(
        '[FFI] → updateSyncConfig: mode=${config.syncMode}, conflict=${config.conflictStrategy}, concurrent=${config.maxConcurrentTransfers}, bandwidth=${config.bandwidthLimitKbps}kbps',
      );
      await ffi.updateSyncConfig(config: config.toFfi());
      AppLogger.d('[FFI] ← updateSyncConfig: ok');
      return;
    }

    AppLogger.d(
      '[FFI] → initSyncEngine: localRoot=${config.localRoot}, mode=${config.syncMode}, conflict=${config.conflictStrategy}, logLevel=${config.logLevel}',
    );

    await ffi.initSyncEngine(config: config.toFfi());

    _initialized = true;
    _subscribeRustEvents();
    AppLogger.d('[FFI] ← initSyncEngine: ok');
  }

  /// 执行初始全量同步
  Future<SyncSummaryModel> startInitialSync() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → startInitialSync');
    final summary = await ffi.startInitialSync();
    AppLogger.d(
      '[FFI] ← startInitialSync: uploaded=${summary.uploaded}, downloaded=${summary.downloaded}, conflicts=${summary.conflicts}, failed=${summary.failed}',
    );
    return SyncSummaryModel.fromFfi(summary);
  }

  /// 启动持续同步
  Future<void> startContinuousSync() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → startContinuousSync');
    await ffi.startContinuousSync();
    AppLogger.d('[FFI] ← startContinuousSync: spawned');
  }

  /// 停止同步
  Future<void> stop() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → stopSync');
    await ffi.stopSync();
    AppLogger.d('[FFI] ← stopSync: ok');
  }

  /// 暂停同步
  Future<void> pause() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → pauseSync');
    await ffi.pauseSync();
    AppLogger.d('[FFI] ← pauseSync: ok');
  }

  /// 恢复同步
  Future<void> resume() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → resumeSync');
    await ffi.resumeSync();
    AppLogger.d('[FFI] ← resumeSync: ok');
  }

  /// 强制重新同步
  Future<SyncSummaryModel> forceSync() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → forceSync');
    final summary = await ffi.forceSync();
    AppLogger.d(
      '[FFI] ← forceSync: uploaded=${summary.uploaded}, downloaded=${summary.downloaded}, conflicts=${summary.conflicts}, failed=${summary.failed}',
    );
    return SyncSummaryModel.fromFfi(summary);
  }

  /// Token 变更时推送给 Rust
  Future<void> updateTokens(String accessToken) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → updateTokens: token_len=${accessToken.length}');
    await ffi.updateTokens(accessToken: accessToken);
    AppLogger.d('[FFI] ← updateTokens: ok');
  }

  /// 更新同步配置（推送到 Rust 引擎，引擎未初始化时忽略）
  Future<void> updateConfig(SyncConfigModel config) async {
    await _ensureRustBridgeInitialized();
    if (!_initialized) return;
    AppLogger.d(
      '[FFI] → updateSyncConfig: mode=${config.syncMode}, conflict=${config.conflictStrategy}, concurrent=${config.maxConcurrentTransfers}, bandwidth=${config.bandwidthLimitKbps}kbps',
    );
    try {
      await ffi.updateSyncConfig(config: config.toFfi());
      AppLogger.d('[FFI] ← updateSyncConfig: ok');
    } catch (e) {
      AppLogger.e('[FFI] ← updateSyncConfig: error=$e');
    }
  }

  // ========== 以下为轮询/查询类，用 trace 避免刷屏 ==========

  /// 获取同步状态快照（轮询高频调用，trace 级别）
  Future<SyncStatusModel> getStatus() async {
    await _ensureRustBridgeInitialized();
    final status = await ffi.getSyncStatus();
    AppLogger.t(
      '[FFI] ← getSyncStatus: state=${status.state}, synced=${status.syncedFiles}, total=${status.totalFiles}',
    );
    return SyncStatusModel.fromFfi(status);
  }

  /// 获取活跃 Worker 数量（轮询高频调用，trace 级别）
  Future<int> getActiveWorkerCount() async {
    await _ensureRustBridgeInitialized();
    final count = await ffi.getActiveWorkerCount();
    AppLogger.t('[FFI] ← getActiveWorkerCount: $count');
    return count;
  }

  /// 获取活跃的同步任务列表（轮询高频调用，trace 级别）
  Future<List<SyncTaskModel>> getActiveTasksTyped() async {
    await _ensureRustBridgeInitialized();
    final tasks = await ffi.getActiveTasks();
    AppLogger.t('[FFI] ← getActiveTasks: count=${tasks.length}');
    return tasks
        .map(
          (t) => SyncTaskModel(
            id: t.id,
            trigger: t.trigger,
            totalCount: t.totalCount,
            completedCount: t.completedCount,
            failedCount: t.failedCount,
            status: t.status,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            finishedAt: t.finishedAt,
          ),
        )
        .toList();
  }

  /// 获取最近同步任务列表（轮询高频调用，trace 级别）
  Future<List<SyncTaskModel>> getRecentTasksTyped({int limit = 20}) async {
    await _ensureRustBridgeInitialized();
    AppLogger.t('[FFI] → getRecentTasks: limit=$limit');
    final tasks = await ffi.getRecentTasks(limit: limit);
    AppLogger.t('[FFI] ← getRecentTasks: count=${tasks.length}');
    return tasks
        .map(
          (t) => SyncTaskModel(
            id: t.id,
            trigger: t.trigger,
            totalCount: t.totalCount,
            completedCount: t.completedCount,
            failedCount: t.failedCount,
            status: t.status,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            finishedAt: t.finishedAt,
          ),
        )
        .toList();
  }

  /// 获取任务详情（按需查询，trace 级别）
  Future<List<SyncTaskItemModel>> getTaskDetailTyped(String taskId) async {
    await _ensureRustBridgeInitialized();
    AppLogger.t('[FFI] → getTaskDetail: taskId=$taskId');
    final items = await ffi.getTaskDetail(taskId: taskId);
    AppLogger.t('[FFI] ← getTaskDetail: count=${items.length}');
    return items
        .map(
          (i) => SyncTaskItemModel(
            id: i.id.toInt(),
            taskId: i.taskId,
            relativePath: i.relativePath,
            actionType: i.actionType,
            status: i.status,
            fileSize: i.fileSize.toInt(),
            errorMessage: i.errorMessage,
            createdAt: i.createdAt,
            updatedAt: i.updatedAt,
          ),
        )
        .toList();
  }

  /// 分页查询任务详情（trace 级别）
  Future<List<SyncTaskItemModel>> queryTaskItemsTyped({
    required String taskId,
    int limit = 20,
    int offset = 0,
  }) async {
    await _ensureRustBridgeInitialized();
    AppLogger.t(
      '[FFI] → queryTaskItems: taskId=$taskId, limit=$limit, offset=$offset',
    );
    final items = await ffi.queryTaskItems(
      filter: ffi_types.TaskItemFilterFfi(
        taskId: taskId,
        limit: limit,
        offset: offset,
      ),
    );
    AppLogger.t('[FFI] ← queryTaskItems: count=${items.length}');
    return items
        .map(
          (i) => SyncTaskItemModel(
            id: i.id.toInt(),
            taskId: i.taskId,
            relativePath: i.relativePath,
            actionType: i.actionType,
            status: i.status,
            fileSize: i.fileSize.toInt(),
            errorMessage: i.errorMessage,
            createdAt: i.createdAt,
            updatedAt: i.updatedAt,
          ),
        )
        .toList();
  }

  /// 从 DB 聚合累积统计（轮询高频调用，trace 级别）
  Future<Map<String, int>> getCumStats() async {
    await _ensureRustBridgeInitialized();
    AppLogger.t('[FFI] → getSyncCumStats');
    final stats = await ffi.getSyncCumStats();
    AppLogger.t(
      '[FFI] ← getSyncCumStats: uploaded=${stats.uploaded}, downloaded=${stats.downloaded}, failed=${stats.failed}, conflicts=${stats.conflicts}, deletedLocal=${stats.deletedLocal}, deletedRemote=${stats.deletedRemote}, skipped=${stats.skipped}',
    );
    return {
      'uploaded': stats.uploaded,
      'downloaded': stats.downloaded,
      'renamed': stats.renamed,
      'moved': stats.moved,
      'failed': stats.failed,
      'conflicts': stats.conflicts,
      'deleted_local': stats.deletedLocal,
      'deleted_remote': stats.deletedRemote,
      'skipped': stats.skipped,
    };
  }

  // ========== 以下为低频操作，保持 debug 级别 ==========

  /// 水合文件 (Windows CFAPi)
  Future<void> hydrateFile(String localPath) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → hydrateFile: path=$localPath');
    await ffi.hydrateFile(localPath: localPath);
    AppLogger.d('[FFI] ← hydrateFile: ok');
  }

  /// 检查云端相册目录 (Android)
  Future<Map<String, dynamic>> checkCloudAlbumDirs(String baseUri) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → checkCloudAlbumDirs: uri=$baseUri');
    final result = await ffi.checkCloudAlbumDirs(baseUri: baseUri);
    AppLogger.d(
      '[FFI] ← checkCloudAlbumDirs: dcim=${result.dcimExists}, pictures=${result.picturesExists}, camera=${result.cameraExists}',
    );
    return {
      'dcimExists': result.dcimExists,
      'picturesExists': result.picturesExists,
      'dcimUri': result.dcimUri,
      'picturesUri': result.picturesUri,
      'cameraExists': result.cameraExists,
      'cameraUri': result.cameraUri,
    };
  }

  /// 创建云端相册目录 (Android)
  Future<void> createCloudAlbumDirs(String baseUri) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → createCloudAlbumDirs: uri=$baseUri');
    await ffi.createCloudAlbumDirs(baseUri: baseUri);
    AppLogger.d('[FFI] ← createCloudAlbumDirs: ok');
  }

  /// 销毁同步引擎
  Future<void> dispose() async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → disposeSyncEngine');
    _rustEventSub?.cancel();
    _rustEventSub = null;
    await _eventController.close();
    await ffi.disposeSyncEngine();
    _initialized = false;
    AppLogger.d('[FFI] ← disposeSyncEngine: ok');
  }

  /// 订阅 Rust 事件流，转换后转发到 _eventController
  void _subscribeRustEvents() {
    _rustEventSub?.cancel();
    try {
      final stream = ffi.registerSyncEventSink();
      _rustEventSub = stream.listen(
        (event) {
          final model = syncEventFromFfi(event);
          if (model != null && !_eventController.isClosed) {
            _eventController.add(model);
          }
        },
        onError: (e) => AppLogger.e('[FFI] Rust event stream error: $e'),
        onDone: () => AppLogger.d('[FFI] Rust event stream done'),
      );
      AppLogger.d('[FFI] Rust event stream subscribed');
    } catch (e) {
      AppLogger.e('[FFI] Failed to subscribe Rust event stream: $e');
    }
  }

  /// 热修改日志级别（立即生效，无需重启）
  Future<void> setLogLevel(String level) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → setSyncLogLevel: level=$level');
    await ffi.setSyncLogLevel(level: level);
    AppLogger.d('[FFI] ← setSyncLogLevel: ok');
  }

  /// 重置同步：停止任务 → 清空 DB → 清空本地目录 → 回到初始状态
  Future<void> resetSync({bool deleteLocalFiles = true}) async {
    await _ensureRustBridgeInitialized();
    AppLogger.d('[FFI] → resetSync: deleteLocalFiles=$deleteLocalFiles');
    await ffi.resetSync(deleteLocalFiles: deleteLocalFiles);
    AppLogger.d('[FFI] ← resetSync: ok');
  }
}
