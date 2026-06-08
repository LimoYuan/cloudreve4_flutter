import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/sync_config_model.dart';
import '../../../data/models/sync_event_model.dart';
import '../../../data/models/sync_task_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';

enum SyncState {
  idle,
  initializing,
  initialSync,
  continuous,
  paused,
  error,
  stopped,
}

class SyncProvider extends ChangeNotifier {

  SyncState _state = SyncState.idle;
  String? _errorMessage;
  SyncSummaryModel? _lastSummary;
  int _syncedFiles = 0;
  int _totalFiles = 0;
  int _conflictCount = 0;
  int _uploadingCount = 0;
  int _downloadingCount = 0;
  String? _currentFile;
  StreamSubscription<SyncEventModel>? _eventSub;
  Timer? _pollTimer;
  int _pollIntervalSeconds = 1; // 动态调节：活跃1s，空闲3s

  // 任务列表
  List<SyncTaskModel> _activeTasks = [];
  List<SyncTaskModel> _recentTasks = [];
  int _activeWorkerCount = 0;
  // 任务详情缓存: taskId -> items
  final Map<String, List<SyncTaskItemModel>> _taskDetailCache = {};
  // 任务详情是否有更多: taskId -> hasMore
  final Map<String, bool> _taskDetailHasMore = {};
  // 需要实时刷新详情的任务ID（UI 展开中的任务）
  final Set<String> _watchedTaskIds = {};
  bool _recentTasksLoaded = false;

  // 持久化的同步配置
  SyncConfigModel? _persistedConfig;

  // 累积统计（跨所有 Worker 实时汇总，不仅仅是 lastSummary）
  int _cumUploaded = 0;
  int _cumDownloaded = 0;
  int _cumRenamed = 0;
  int _cumMoved = 0;
  int _cumFailed = 0;
  int _cumConflicts = 0;
  int _cumDeletedLocal = 0;
  int _cumDeletedRemote = 0;
  int _cumSkipped = 0;

  SyncState get state => _state;
  String? get errorMessage => _errorMessage;
  SyncSummaryModel? get lastSummary => _lastSummary;
  int get syncedFiles => _syncedFiles;
  int get totalFiles => _totalFiles;
  int get conflictCount => _conflictCount;
  int get uploadingCount => _uploadingCount;
  int get downloadingCount => _downloadingCount;
  String? get currentFile => _currentFile;
  SyncConfigModel? get persistedConfig => _persistedConfig;
  List<SyncTaskModel> get activeTasks => _activeTasks;
  List<SyncTaskModel> get recentTasks => _recentTasks;
  int get activeWorkerCount => _activeWorkerCount;

  /// 累积上传数（所有 Worker 汇总）
  int get cumUploaded => _cumUploaded;
  /// 累积下载数（所有 Worker 汇总）
  int get cumDownloaded => _cumDownloaded;
  /// 累积重命名数
  int get cumRenamed => _cumRenamed;
  /// 累积移动数
  int get cumMoved => _cumMoved;
  /// 累积失败数
  int get cumFailed => _cumFailed;
  /// 累积冲突数
  int get cumConflicts => _cumConflicts;
  /// 累积删本地数
  int get cumDeletedLocal => _cumDeletedLocal;
  /// 累积删远程数
  int get cumDeletedRemote => _cumDeletedRemote;
  /// 累积跳过数
  int get cumSkipped => _cumSkipped;
  /// 累积总计操作数
  int get cumTotal => _cumUploaded + _cumDownloaded + _cumRenamed + _cumMoved + _cumFailed + _cumConflicts + _cumDeletedLocal + _cumDeletedRemote + _cumSkipped;

  /// 从活跃任务聚合的已完成数
  int get activeCompletedCount {
    int sum = 0;
    for (final t in _activeTasks) {
      sum += t.completedCount;
    }
    return sum;
  }

  /// 从活跃任务聚合的总数
  int get activeTotalCount {
    int sum = 0;
    for (final t in _activeTasks) {
      sum += t.totalCount;
    }
    return sum;
  }

  /// 从活跃任务聚合的进度（0.0~1.0）
  double get activeProgress {
    final total = activeTotalCount;
    if (total == 0) return 0.0;
    return activeCompletedCount / total;
  }

  bool get isActive =>
      _state == SyncState.initializing ||
      _state == SyncState.initialSync ||
      _state == SyncState.continuous;

  bool get isPaused => _state == SyncState.paused;

  bool get hasError => _state == SyncState.error;

  /// Rust 同步引擎是否已初始化（点过"开始同步"后为 true）
  bool _engineInitialized = false;
  bool get engineInitialized => _engineInitialized;

  double get progress =>
      _totalFiles > 0 ? _syncedFiles / _totalFiles : 0.0;

  /// 从持久化存储恢复同步配置和状态
  Future<void> restoreFromStorage() async {
    final configMap = await StorageService.instance.getSyncConfig();
    if (configMap != null) {
      try {
        _persistedConfig = SyncConfigModel(
          baseUrl: configMap['baseUrl'] as String? ?? '',
          accessToken: configMap['accessToken'] as String? ?? '',
          refreshToken: configMap['refreshToken'] as String? ?? '',
          localRoot: configMap['localRoot'] as String? ?? '',
          remoteRoot: configMap['remoteRoot'] as String? ?? 'cloudreve://my',
          // 旧版 'album' 迁移为 'album_upload'
          syncMode: (configMap['syncMode'] as String? ?? 'full') == 'album' ? 'album_upload' : (configMap['syncMode'] as String? ?? 'full'),
          conflictStrategy: configMap['conflictStrategy'] as String? ?? 'keep_both',
          wcfDeleteMode: configMap['wcfDeleteMode'] as String? ?? 'wcf_delete_local_only',
          maxConcurrentTransfers: configMap['maxConcurrentTransfers'] as int? ?? 3,
          bandwidthLimitKbps: configMap['bandwidthLimitKbps'] as int? ?? 0,
          maxWorkers: configMap['maxWorkers'] as int? ?? 0,
          dataDir: configMap['dataDir'] as String? ?? '',
          clientId: configMap['clientId'] as String? ?? '',
          logLevel: configMap['logLevel'] as String? ?? 'info',
          maxHydrationCacheSizeGb:
              configMap['maxHydrationCacheSizeGb'] as int? ?? 2,
        );
        AppLogger.i('恢复同步配置: 模式=${_persistedConfig!.syncMode}, 冲突=${_persistedConfig!.conflictStrategy}, 并发=${_persistedConfig!.maxConcurrentTransfers}, 带宽=${_persistedConfig!.bandwidthLimitKbps}kbps, maxWorkers=${_persistedConfig!.maxWorkers}');
      } catch (e) {
        AppLogger.e('恢复同步配置失败: $e');
      }
    }

    final savedState = await StorageService.instance.getSyncState();
    if (savedState != null && savedState != 'idle' && savedState != 'stopped') {
      AppLogger.i('恢复同步状态: $savedState');
    }

    // 恢复累积统计
    final cumStats = await StorageService.instance.getSyncCumStats();
    if (cumStats != null) {
      _cumUploaded = cumStats['uploaded'] ?? 0;
      _cumDownloaded = cumStats['downloaded'] ?? 0;
      _cumRenamed = cumStats['renamed'] ?? 0;
      _cumMoved = cumStats['moved'] ?? 0;
      _cumFailed = cumStats['failed'] ?? 0;
      _cumConflicts = cumStats['conflicts'] ?? 0;
      _cumDeletedLocal = cumStats['deleted_local'] ?? 0;
      _cumDeletedRemote = cumStats['deleted_remote'] ?? 0;
      _cumSkipped = cumStats['skipped'] ?? 0;
      AppLogger.i('恢复累积统计: 上传=$_cumUploaded, 下载=$_cumDownloaded, 失败=$_cumFailed, 冲突=$_cumConflicts, 删本地=$_cumDeletedLocal, 删远程=$_cumDeletedRemote, 跳过=$_cumSkipped');
    }
  }

  /// 保存同步配置到持久化存储
  Future<void> _persistConfig(SyncConfigModel config) async {
    _persistedConfig = config;
    await StorageService.instance.setSyncConfig({
      'baseUrl': config.baseUrl,
      'accessToken': config.accessToken,
      'refreshToken': config.refreshToken,
      'localRoot': config.localRoot,
      'remoteRoot': config.remoteRoot,
      'syncMode': config.syncMode,
      'conflictStrategy': config.conflictStrategy,
      'wcfDeleteMode': config.wcfDeleteMode,
      'maxConcurrentTransfers': config.maxConcurrentTransfers,
      'bandwidthLimitKbps': config.bandwidthLimitKbps,
      'maxWorkers': config.maxWorkers,
      'dataDir': config.dataDir,
      'clientId': config.clientId,
      'logLevel': config.logLevel,
      'maxHydrationCacheSizeGb': config.maxHydrationCacheSizeGb,
    });
  }

  /// 持久化累积统计
  Future<void> _persistCumStats() async {
    await StorageService.instance.setSyncCumStats({
      'uploaded': _cumUploaded,
      'downloaded': _cumDownloaded,
      'renamed': _cumRenamed,
      'moved': _cumMoved,
      'failed': _cumFailed,
      'conflicts': _cumConflicts,
      'deleted_local': _cumDeletedLocal,
      'deleted_remote': _cumDeletedRemote,
      'skipped': _cumSkipped,
    });
  }

  /// 从 Rust DB 加载累积统计（权威数据源）
  /// 取 DB 和内存中的较大值，避免覆盖事件已递增的增量
  Future<void> _loadCumStatsFromDb() async {
    try {
      final stats = await SyncService.instance.getCumStats();
      _cumUploaded = _max(_cumUploaded, stats['uploaded'] ?? 0);
      _cumDownloaded = _max(_cumDownloaded, stats['downloaded'] ?? 0);
      _cumRenamed = _max(_cumRenamed, stats['renamed'] ?? 0);
      _cumMoved = _max(_cumMoved, stats['moved'] ?? 0);
      _cumFailed = _max(_cumFailed, stats['failed'] ?? 0);
      _cumConflicts = _max(_cumConflicts, stats['conflicts'] ?? 0);
      _cumDeletedLocal = _max(_cumDeletedLocal, stats['deleted_local'] ?? 0);
      _cumDeletedRemote = _max(_cumDeletedRemote, stats['deleted_remote'] ?? 0);
      _cumSkipped = _max(_cumSkipped, stats['skipped'] ?? 0);
      await _persistCumStats();
      AppLogger.i('从 DB 校准累积统计: 上传=$_cumUploaded, 下载=$_cumDownloaded, 失败=$_cumFailed, 冲突=$_cumConflicts, 删本地=$_cumDeletedLocal, 删远程=$_cumDeletedRemote, 跳过=$_cumSkipped');
      notifyListeners();
    } catch (e) {
      AppLogger.e('从 DB 加载累积统计失败: $e');
    }
  }

  static int _max(int a, int b) => a > b ? a : b;

  /// 持久化同步状态
  Future<void> _persistState(SyncState state) async {
    final stateStr = switch (state) {
      SyncState.idle => 'idle',
      SyncState.initializing => 'initializing',
      SyncState.initialSync => 'initialSync',
      SyncState.continuous => 'continuous',
      SyncState.paused => 'paused',
      SyncState.error => 'error',
      SyncState.stopped => 'stopped',
    };
    await StorageService.instance.setSyncState(stateStr);
  }

  /// 初始化并启动同步
  Future<void> startSync(SyncConfigModel config) async {
    _state = SyncState.initializing;
    _errorMessage = null;
    _syncedFiles = 0;
    _totalFiles = 0;
    _currentFile = null;
    // 不再清零 cum — 从 DB 加载权威数据
    notifyListeners();

    // 确保 clientId 已注入（Dart 生成、持久化、全层共享）
    final clientId = await StorageService.instance.getOrCreateClientId();
    final configWithClientId = config.copyWith(clientId: clientId);

    // 持久化配置和状态
    await _persistConfig(configWithClientId);
    await _persistState(SyncState.initializing);

    try {
      await SyncService.instance.init(configWithClientId);
      _engineInitialized = true;

      // 从 DB 加载累积统计（权威数据源，替代 SharedPreferences）
      await _loadCumStatsFromDb();

      _subscribeEvents();

      _state = SyncState.initialSync;
      await _persistState(SyncState.initialSync);
      notifyListeners();

      // 启动状态轮询
      _startPolling();

      // 启动初始同步（后台运行）
      SyncService.instance.startInitialSync().then((summary) async {
        _lastSummary = summary;
        // 不再覆盖 cum — TaskItemUpdated 事件已实时递增
        // 初始同步完成后从 DB 重新校准（避免事件遗漏）
        await _loadCumStatsFromDb();
        _state = SyncState.continuous;
        await _persistState(SyncState.continuous);
        AppLogger.i('初始同步完成');
        notifyListeners();

        // 自动启动持续同步
        SyncService.instance.startContinuousSync();
      }).catchError((e) async {
        _state = SyncState.error;
        _errorMessage = e.toString();
        await _persistState(SyncState.error);
        AppLogger.e('初始同步失败: $e');
        notifyListeners();
      });
    } catch (e) {
      _state = SyncState.error;
      _errorMessage = e.toString();
      await _persistState(SyncState.error);
      AppLogger.e('同步启动失败: $e');
      notifyListeners();
    }
  }

  /// 自动恢复同步（启动时调用，如果之前处于同步状态则恢复）
  Future<void> autoResumeIfNeeded({
    String? currentAccessToken,
    String? currentRefreshToken,
  }) async {
    if (_persistedConfig == null) {
      await restoreFromStorage();
    }
    if (_persistedConfig == null) return;

    final savedState = await StorageService.instance.getSyncState();
    if (savedState == null || savedState == 'idle' || savedState == 'stopped' || savedState == 'error') {
      return;
    }

    AppLogger.i('自动恢复同步，上次状态: $savedState');

    var config = _persistedConfig!;
    if (currentAccessToken != null && currentRefreshToken != null) {
      config = config.copyWith(
        accessToken: currentAccessToken,
        refreshToken: currentRefreshToken,
      );
    }

    await startSync(config);
  }

  /// 更新配置（持久化 + 推送到 Rust 引擎）
  Future<void> updateConfig(SyncConfigModel config) async {
    await _persistConfig(config);

    // 引擎已初始化时（无论是否运行中），推送配置到 Rust
    try {
      await SyncService.instance.updateConfig(config);
      AppLogger.i('同步配置已更新到引擎: 模式=${config.syncMode}');
    } catch (e) {
      AppLogger.e('更新配置到引擎失败: $e');
    }
  }

  /// 热修改日志级别（立即生效，无需重启引擎）
  Future<void> setLogLevel(String level) async {
    // 持久化
    if (_persistedConfig != null) {
      final updated = _persistedConfig!.copyWith(logLevel: level);
      await _persistConfig(updated);
    }

    // 引擎已初始化时立即通知 Rust（不限制仅活跃状态）
    try {
      await SyncService.instance.setLogLevel(level);
      AppLogger.i('日志级别已切换为: $level');
    } catch (e) {
      AppLogger.e('切换日志级别失败: $e');
    }
  }

  /// 轮询 Rust 引擎状态（动态间隔：活跃1s，空闲3s）
  void _startPolling() {
    _pollTimer?.cancel();
    _pollIntervalSeconds = isActive || isPaused ? 1 : 3;
    _pollTimer = Timer.periodic(
      Duration(seconds: _pollIntervalSeconds),
      (_) => _pollStatus(),
    );
  }

  void _adjustPollInterval() {
    final target = isActive || isPaused ? 1 : 3;
    if (target != _pollIntervalSeconds) {
      _pollIntervalSeconds = target;
      _startPolling();
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  int _pollErrorCount = 0;
  int _pollCount = 0;

  Future<void> _pollStatus() async {
    try {
      final status = await SyncService.instance.getStatus();
      _syncedFiles = status.syncedFiles;
      _totalFiles = status.totalFiles;
      _uploadingCount = status.uploadingCount;
      _downloadingCount = status.downloadingCount;
      _conflictCount = status.conflictCount;
      _pollErrorCount = 0;

      final rustState = _parseState(status.state);
      if (rustState != _state && rustState != SyncState.idle) {
        _state = rustState;
        await _persistState(rustState);
      }
      if (status.errorMessage != null && status.errorMessage!.isNotEmpty) {
        _errorMessage = status.errorMessage;
      }

      // 轮询活跃任务 + 刷新已完成任务
      try {
        final newActiveWorkerCount = await SyncService.instance.getActiveWorkerCount();
        final newActiveTasks = await SyncService.instance.getActiveTasksTyped();

        bool changed = newActiveWorkerCount != _activeWorkerCount;
        _activeWorkerCount = newActiveWorkerCount;

        // 活跃任务列表有变化时才更新
        if (!_taskListEqual(newActiveTasks, _activeTasks)) {
          _activeTasks = newActiveTasks;
          changed = true;
          // 清除不再活跃的任务的详情缓存
          _taskDetailCache.removeWhere(
            (key, _) => !newActiveTasks.any((t) => t.id == key),
          );
        }

        // 每次 polling 都刷新已完成任务
        await _refreshRecentTasks();

        // 刷新展开中的任务详情（实时更新 item 状态）
        await _refreshWatchedTaskDetails();

        if (changed) {
          notifyListeners();
        } else {
          notifyListeners();
        }
      } catch (_) {}

      // 每 5 次轮询从 DB 校准累积统计（兜底，防止事件丢失导致 UI 不同步）
      _pollCount++;
      if (_pollCount % 5 == 0 && _engineInitialized) {
        try {
          final stats = await SyncService.instance.getCumStats();
          final dbUploaded = stats['uploaded'] ?? 0;
          final dbDownloaded = stats['downloaded'] ?? 0;
          final dbRenamed = stats['renamed'] ?? 0;
          final dbMoved = stats['moved'] ?? 0;
          final dbFailed = stats['failed'] ?? 0;
          final dbConflicts = stats['conflicts'] ?? 0;
          final dbDeletedLocal = stats['deleted_local'] ?? 0;
          final dbDeletedRemote = stats['deleted_remote'] ?? 0;
          final dbSkipped = stats['skipped'] ?? 0;
          if (dbUploaded != _cumUploaded || dbDownloaded != _cumDownloaded ||
              dbRenamed != _cumRenamed || dbMoved != _cumMoved ||
              dbFailed != _cumFailed || dbConflicts != _cumConflicts ||
              dbDeletedLocal != _cumDeletedLocal || dbDeletedRemote != _cumDeletedRemote ||
              dbSkipped != _cumSkipped) {
            _cumUploaded = dbUploaded;
            _cumDownloaded = dbDownloaded;
            _cumRenamed = dbRenamed;
            _cumMoved = dbMoved;
            _cumFailed = dbFailed;
            _cumConflicts = dbConflicts;
            _cumDeletedLocal = dbDeletedLocal;
            _cumDeletedRemote = dbDeletedRemote;
            _cumSkipped = dbSkipped;
            await _persistCumStats();
          }
        } catch (_) {}
      }

      notifyListeners();
      _adjustPollInterval();
    } catch (_) {
      // 引擎未初始化等连续错误，停止轮询避免刷屏
      _pollErrorCount++;
      if (_pollErrorCount >= 3) {
        _stopPolling();
      }
    }
  }

  /// 首次加载已完成任务（如果轮询未运行则启动慢速轮询）
  Future<void> loadRecentTasks() async {
    if (_recentTasksLoaded) return;
    await _refreshRecentTasks();
    if (_pollTimer == null) {
      _startPolling();
    }
  }

  Future<void> _refreshRecentTasks() async {
    try {
      final tasks = await SyncService.instance.getRecentTasksTyped(limit: 50);
      if (!_taskListEqual(tasks, _recentTasks)) {
        _recentTasks = tasks;
      }
      _recentTasksLoaded = true;
    } catch (_) {}
  }

  bool _taskListEqual(List<SyncTaskModel> a, List<SyncTaskModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].completedCount != b[i].completedCount ||
          a[i].failedCount != b[i].failedCount ||
          a[i].status != b[i].status) {
        return false;
      }
    }
    return true;
  }

  /// 刷新展开中的任务详情（轮询时调用，只刷新 watched 的任务）
  Future<void> _refreshWatchedTaskDetails() async {
    if (_watchedTaskIds.isEmpty) return;
    for (final taskId in _watchedTaskIds.toList()) {
      try {
        // 重新加载前 20 条（和当前缓存量一致）
        final cachedCount = _taskDetailCache[taskId]?.length ?? 20;
        final newItems = await SyncService.instance.queryTaskItemsTyped(
          taskId: taskId,
          limit: cachedCount.clamp(20, 100),
          offset: 0,
        );
        final oldItems = _taskDetailCache[taskId];
        if (oldItems != null && !_itemListEqual(oldItems, newItems)) {
          _taskDetailCache[taskId] = newItems;
          notifyListeners();
        } else if (oldItems == null) {
          _taskDetailCache[taskId] = newItems;
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  bool _itemListEqual(List<SyncTaskItemModel> a, List<SyncTaskItemModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].status != b[i].status) {
        return false;
      }
    }
    return true;
  }

  void _subscribeEvents() {
    _eventSub = SyncService.instance.events.listen((event) async {
      switch (event) {
        case SyncStateChanged(:final newState):
          _state = _parseState(newState);
          await _persistState(_state);
        case SyncProgress(:final synced, :final total, :final currentFile):
          _syncedFiles = synced;
          _totalFiles = total;
          _currentFile = currentFile;
        case SyncFileUploaded():
          _syncedFiles++;
        case SyncFileDownloaded():
          _syncedFiles++;
        case SyncConflictDetected():
          _conflictCount++;
        case SyncError(:final message, :final recoverable):
          if (!recoverable) {
            _state = SyncState.error;
            _errorMessage = message;
            await _persistState(SyncState.error);
          }
        case SyncTokenExpired():
          _handleTokenExpired();
        case SyncInitialSyncComplete(:final summary):
          _lastSummary = summary;
          _state = SyncState.continuous;
          await _persistState(SyncState.continuous);
          // 不再在此启动 continuous sync — .then() 回调已启动，避免重复
        case SyncDiskSpaceWarning():
          AppLogger.w('磁盘空间不足');
        case SyncWorkerCompleted():
          break;
        case SyncWorkerFailed():
          break;
        case SyncTaskItemUpdated(:final taskId, :final action, :final status):
          AppLogger.d('[SyncProvider] TaskItemUpdated: taskId=$taskId, action=$action, status=$status');
          // 实时更新活跃任务的 completedCount/failedCount
          final idx = _activeTasks.indexWhere((t) => t.id == taskId);
          if (idx >= 0) {
            final old = _activeTasks[idx];
            if (status == 'completed') {
              _activeTasks[idx] = SyncTaskModel(
                id: old.id, trigger: old.trigger, totalCount: old.totalCount,
                completedCount: old.completedCount + 1, failedCount: old.failedCount,
                status: old.status, createdAt: old.createdAt, updatedAt: old.updatedAt,
                finishedAt: old.finishedAt,
              );
            } else if (status == 'failed') {
              _activeTasks[idx] = SyncTaskModel(
                id: old.id, trigger: old.trigger, totalCount: old.totalCount,
                completedCount: old.completedCount, failedCount: old.failedCount + 1,
                status: old.status, createdAt: old.createdAt, updatedAt: old.updatedAt,
                finishedAt: old.finishedAt,
              );
            }
          }
          // 实时递增累积计数器
          if (status == 'completed') {
            switch (action) {
              case 'upload':
                _cumUploaded++;
                AppLogger.d('[SyncProvider] cumUploaded=$_cumUploaded');
              case 'download':
                _cumDownloaded++;
              case 'rename':
                _cumRenamed++;
              case 'move':
                _cumMoved++;
              case 'conflict_resolve':
                _cumConflicts++;
              case 'delete_local':
                _cumDeletedLocal++;
              case 'delete_remote':
                _cumDeletedRemote++;
              case 'create_placeholder':
                break;
              default:
                AppLogger.w('[SyncProvider] TaskItemUpdated: 未知 action=$action');
            }
          } else if (status == 'skipped') {
            _cumSkipped++;
          } else if (status == 'failed') {
            _cumFailed++;
          }
      }
      notifyListeners();
      _persistCumStats();
    });
  }

  SyncState _parseState(String state) {
    return switch (state) {
      'idle' => SyncState.idle,
      'initializing' => SyncState.initializing,
      'initialSync' => SyncState.initialSync,
      'continuous' => SyncState.continuous,
      'paused' => SyncState.paused,
      'error' => SyncState.error,
      'stopped' => SyncState.stopped,
      _ => SyncState.idle,
    };
  }

  void _handleTokenExpired() {
    AppLogger.w('Token 过期，需要刷新');
  }

  /// 获取任务详情（分页加载，带缓存）
  Future<List<SyncTaskItemModel>> getTaskDetail(String taskId) async {
    if (_taskDetailCache.containsKey(taskId)) {
      return _taskDetailCache[taskId]!;
    }
    final items = await SyncService.instance.queryTaskItemsTyped(
      taskId: taskId,
      limit: 20,
      offset: 0,
    );
    _taskDetailCache[taskId] = items;
    _taskDetailHasMore[taskId] = items.length >= 20;
    notifyListeners();
    return items;
  }

  /// 加载更多任务详情
  Future<List<SyncTaskItemModel>> loadMoreTaskDetail(String taskId) async {
    final current = _taskDetailCache[taskId] ?? [];
    final offset = current.length;
    final newItems = await SyncService.instance.queryTaskItemsTyped(
      taskId: taskId,
      limit: 20,
      offset: offset,
    );
    final merged = [...current, ...newItems];
    _taskDetailCache[taskId] = merged;
    _taskDetailHasMore[taskId] = newItems.length >= 20;
    notifyListeners();
    return merged;
  }

  /// 指定任务是否还有更多详情可加载
  bool hasMoreTaskDetail(String taskId) {
    return _taskDetailHasMore[taskId] ?? true;
  }

  /// 标记任务详情需要实时刷新（UI 展开时调用）
  void watchTaskDetail(String taskId) {
    _watchedTaskIds.add(taskId);
  }

  /// 取消实时刷新（UI 收起时调用）
  void unwatchTaskDetail(String taskId) {
    _watchedTaskIds.remove(taskId);
  }

  /// 读取缓存的任务详情（同步，无则返回 null）
  List<SyncTaskItemModel>? getCachedTaskDetail(String taskId) {
    return _taskDetailCache[taskId];
  }

  /// 清除任务详情缓存，下次获取时重新请求
  void invalidateTaskDetail(String taskId) {
    _taskDetailCache.remove(taskId);
    _taskDetailHasMore.remove(taskId);
  }

  /// 清除所有任务详情缓存
  void invalidateAllTaskDetails() {
    _taskDetailCache.clear();
    _taskDetailHasMore.clear();
    _recentTasksLoaded = false;
  }

  /// 暂停同步
  Future<void> pause() async {
    await SyncService.instance.pause();
    _state = SyncState.paused;
    await _persistState(SyncState.paused);
    notifyListeners();
  }

  /// 恢复同步
  Future<void> resume() async {
    await SyncService.instance.resume();
    _state = SyncState.continuous;
    await _persistState(SyncState.continuous);
    notifyListeners();
  }

  /// 停止同步
  Future<void> stop() async {
    await SyncService.instance.stop();
    _state = SyncState.stopped;
    await _persistState(SyncState.stopped);
    notifyListeners();
    _adjustPollInterval();
  }

  /// 重置同步：停止任务 → 清空 DB → (可选)清空本地目录 → 回到初始状态
  Future<void> resetSync({bool deleteLocalFiles = true}) async {
    // 引擎未初始化时仅清空本地状态
    try {
      await SyncService.instance.resetSync(deleteLocalFiles: deleteLocalFiles);
    } catch (_) {}
    _state = SyncState.idle;
    _errorMessage = null;
    _syncedFiles = 0;
    _totalFiles = 0;
    _conflictCount = 0;
    _uploadingCount = 0;
    _downloadingCount = 0;
    _currentFile = null;
    _lastSummary = null;
    _cumUploaded = 0;
    _cumDownloaded = 0;
    _cumRenamed = 0;
    _cumMoved = 0;
    _cumFailed = 0;
    _cumConflicts = 0;
    _cumDeletedLocal = 0;
    _cumDeletedRemote = 0;
    _cumSkipped = 0;
    _persistCumStats();
    _activeTasks = [];
    _recentTasks = [];
    _activeWorkerCount = 0;
    _taskDetailCache.clear();
    _recentTasksLoaded = false;
    _engineInitialized = false;
    await _persistState(SyncState.idle);
    notifyListeners();
  }

  /// 强制重新同步
  Future<void> forceSync() async {
    _state = SyncState.initialSync;
    _syncedFiles = 0;
    _totalFiles = 0;
    await _persistState(SyncState.initialSync);
    notifyListeners();

    try {
      final summary = await SyncService.instance.forceSync();
      _lastSummary = summary;
      _state = SyncState.continuous;
      await _persistState(SyncState.continuous);
      // 重新启动持续同步
      SyncService.instance.startContinuousSync();
    } catch (e) {
      _state = SyncState.error;
      _errorMessage = e.toString();
      await _persistState(SyncState.error);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    _eventSub?.cancel();
    super.dispose();
  }
}
