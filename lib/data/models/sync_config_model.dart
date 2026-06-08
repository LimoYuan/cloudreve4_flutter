import '../../src/rust/api/ffi_types.dart' as ffi;

class SyncConfigModel {
  final String baseUrl;
  final String accessToken;
  final String refreshToken;
  final String localRoot;
  final String remoteRoot;
  final String syncMode;
  final String conflictStrategy;
  final String wcfDeleteMode;
  final int maxConcurrentTransfers;
  final int bandwidthLimitKbps;
  final List<String> excludedPaths;
  final int maxWorkers;
  final String dataDir;
  final String clientId;
  final String logLevel;
  /// FUSE 水合缓存上限（GB），默认 2，仅 Linux MirrorWcf 模式生效
  final int maxHydrationCacheSizeGb;

  const SyncConfigModel({
    required this.baseUrl,
    required this.accessToken,
    required this.refreshToken,
    required this.localRoot,
    required this.dataDir,
    required this.clientId,
    this.remoteRoot = 'cloudreve://my',
    this.syncMode = 'full',
    this.conflictStrategy = 'keep_both',
    this.wcfDeleteMode = 'wcf_delete_local_only',
    this.maxConcurrentTransfers = 3,
    this.bandwidthLimitKbps = 0,
    this.excludedPaths = const [],
    this.maxWorkers = 0,
    this.logLevel = 'info',
    this.maxHydrationCacheSizeGb = 2,
  });

  SyncConfigModel copyWith({
    String? baseUrl,
    String? accessToken,
    String? refreshToken,
    String? localRoot,
    String? remoteRoot,
    String? syncMode,
    String? conflictStrategy,
    String? wcfDeleteMode,
    int? maxConcurrentTransfers,
    int? bandwidthLimitKbps,
    List<String>? excludedPaths,
    int? maxWorkers,
    String? dataDir,
    String? clientId,
    String? logLevel,
    int? maxHydrationCacheSizeGb,
  }) {
    return SyncConfigModel(
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      localRoot: localRoot ?? this.localRoot,
      remoteRoot: remoteRoot ?? this.remoteRoot,
      syncMode: syncMode ?? this.syncMode,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      wcfDeleteMode: wcfDeleteMode ?? this.wcfDeleteMode,
      maxConcurrentTransfers:
          maxConcurrentTransfers ?? this.maxConcurrentTransfers,
      bandwidthLimitKbps: bandwidthLimitKbps ?? this.bandwidthLimitKbps,
      excludedPaths: excludedPaths ?? this.excludedPaths,
      maxWorkers: maxWorkers ?? this.maxWorkers,
      dataDir: dataDir ?? this.dataDir,
      clientId: clientId ?? this.clientId,
      logLevel: logLevel ?? this.logLevel,
      maxHydrationCacheSizeGb:
          maxHydrationCacheSizeGb ?? this.maxHydrationCacheSizeGb,
    );
  }

  ffi.SyncConfigFfi toFfi() {
    return ffi.SyncConfigFfi(
      baseUrl: baseUrl,
      accessToken: accessToken,
      refreshToken: refreshToken,
      localRoot: localRoot,
      remoteRoot: remoteRoot,
      syncMode: syncMode,
      conflictStrategy: conflictStrategy,
      wcfDeleteMode: wcfDeleteMode,
      maxConcurrentTransfers: maxConcurrentTransfers,
      bandwidthLimitKbps: BigInt.from(bandwidthLimitKbps),
      excludedPaths: excludedPaths,
      maxWorkers: maxWorkers,
      dataDir: dataDir,
      clientId: clientId,
      logLevel: logLevel,
      maxHydrationCacheSizeGb: maxHydrationCacheSizeGb,
    );
  }

  static SyncConfigModel fromFfi(ffi.SyncConfigFfi ffi) {
    return SyncConfigModel(
      baseUrl: ffi.baseUrl,
      accessToken: ffi.accessToken,
      refreshToken: ffi.refreshToken,
      localRoot: ffi.localRoot,
      remoteRoot: ffi.remoteRoot,
      syncMode: ffi.syncMode,
      conflictStrategy: ffi.conflictStrategy,
      wcfDeleteMode: ffi.wcfDeleteMode,
      maxConcurrentTransfers: ffi.maxConcurrentTransfers,
      bandwidthLimitKbps: ffi.bandwidthLimitKbps.toInt(),
      excludedPaths: ffi.excludedPaths,
      maxWorkers: ffi.maxWorkers,
      dataDir: ffi.dataDir,
      clientId: ffi.clientId,
      logLevel: ffi.logLevel,
      maxHydrationCacheSizeGb: ffi.maxHydrationCacheSizeGb,
    );
  }
}
