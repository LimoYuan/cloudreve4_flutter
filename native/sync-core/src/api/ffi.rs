use flutter_rust_bridge::frb;
use std::sync::Arc;

use crate::api::ffi_types::*;
use crate::sync_engine::SyncEngine;

#[cfg(target_os = "android")]
mod android_log {
    use std::fmt::Write;
    use tracing::{Event, Level, Subscriber};
    use tracing_subscriber::layer::{Context, Layer};
    use tracing_subscriber::registry::LookupSpan;

    /// Tracing Layer：将事件转发到 `log` crate → android_logger → Logcat
    pub struct AndroidLogLayer;

    impl<S> Layer<S> for AndroidLogLayer
    where
        S: Subscriber + for<'a> LookupSpan<'a>,
    {
        fn on_event(&self, event: &Event<'_>, _ctx: Context<'_, S>) {
            let log_level = match *event.metadata().level() {
                Level::ERROR => log::Level::Error,
                Level::WARN => log::Level::Warn,
                Level::INFO => log::Level::Info,
                Level::DEBUG => log::Level::Debug,
                Level::TRACE => log::Level::Trace,
            };

            let mut visitor = EventVisitor::default();
            event.record(&mut visitor);

            let target = event.metadata().target();
            if visitor.message.is_empty() {
                log::log!(log_level, "[{}] {}", target, visitor.fields.trim_end());
            } else if visitor.fields.is_empty() {
                log::log!(log_level, "[{}] {}", target, visitor.message);
            } else {
                log::log!(log_level, "[{}] {} {}", target, visitor.message, visitor.fields.trim_end());
            }
        }
    }

    #[derive(Default)]
    struct EventVisitor {
        message: String,
        fields: String,
    }

    impl tracing::field::Visit for EventVisitor {
        fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
            if field.name() == "message" {
                // message 字段由 tracing::field::display() 包装，其 Debug 实际走 Display，无多余引号
                write!(self.message, "{:?}", value).unwrap();
            } else {
                write!(self.fields, "{}={:?} ", field.name(), value).unwrap();
            }
        }
    }

    pub fn init_android_logger() {
        android_logger::init_once(
            android_logger::Config::default()
                .with_max_level(log::LevelFilter::Trace)
                .with_tag("RustSyncCore"),
        );
    }
}

/// 全局引擎实例
static ENGINE: once_cell::sync::OnceCell<Arc<SyncEngine>> = once_cell::sync::OnceCell::new();

/// 全局日志级别重载句柄（支持运行时热修改）
static LOG_RELOAD_HANDLE: once_cell::sync::OnceCell<
    tracing_subscriber::reload::Handle<tracing_subscriber::EnvFilter, tracing_subscriber::Registry>,
> = once_cell::sync::OnceCell::new();

// 内部类型 -> FFI 类型的转换函数

fn error_to_ffi(e: crate::errors::SyncError) -> SyncErrorFfi {
    match e {
        crate::errors::SyncError::Network(msg) => SyncErrorFfi::NetworkError { message: msg },
        crate::errors::SyncError::DiskFull { needed, available } => {
            SyncErrorFfi::DiskFull { needed, available }
        }
        crate::errors::SyncError::Auth(msg) => SyncErrorFfi::AuthError { message: msg },
        crate::errors::SyncError::Conflict { count } => SyncErrorFfi::ConflictError { count },
        crate::errors::SyncError::NotInitialized => SyncErrorFfi::NotInitialized,
        _ => SyncErrorFfi::InternalError {
            message: e.to_string(),
        },
    }
}

fn config_from_ffi(ffi: SyncConfigFfi) -> crate::models::SyncConfig {
    use crate::models::{ConflictStrategy, SyncMode, WcfDeleteMode};
    use std::path::PathBuf;

    let sync_mode = match ffi.sync_mode.as_str() {
        "upload_only" => SyncMode::UploadOnly,
        "download_only" => SyncMode::DownloadOnly,
        "album_upload" => SyncMode::AlbumUpload,
        "album_download" => SyncMode::AlbumDownload,
        "mirror_wcf" => SyncMode::MirrorWcf,
        _ => SyncMode::Full,
    };

    let conflict_strategy = match ffi.conflict_strategy.as_str() {
        "keep_local" => ConflictStrategy::KeepLocal,
        "keep_remote" => ConflictStrategy::KeepRemote,
        "newest_wins" => ConflictStrategy::NewestWins,
        "largest_wins" => ConflictStrategy::LargestWins,
        "manual" => ConflictStrategy::Manual,
        _ => ConflictStrategy::KeepBoth,
    };

    let wcf_delete_mode = match ffi.wcf_delete_mode.as_str() {
        "wcf_delete_sync_remote" => WcfDeleteMode::SyncRemote,
        _ => WcfDeleteMode::LocalOnly,
    };

    let bandwidth_limit = if ffi.bandwidth_limit_kbps > 0 {
        Some(ffi.bandwidth_limit_kbps * 1024)
    } else {
        None
    };

    crate::models::SyncConfig {
        base_url: ffi.base_url,
        access_token: ffi.access_token,
        refresh_token: ffi.refresh_token,
        local_root: PathBuf::from(&ffi.local_root),
        remote_root: ffi.remote_root,
        sync_mode,
        conflict_strategy,
        wcf_delete_mode,
        max_concurrent_transfers: ffi.max_concurrent_transfers as usize,
        bandwidth_limit,
        excluded_paths: ffi.excluded_paths,
        max_workers: ffi.max_workers as usize,
        data_dir: PathBuf::from(&ffi.data_dir),
        client_id: ffi.client_id,
        max_hydration_cache_size_gb: if ffi.max_hydration_cache_size_gb == 0 {
            2
        } else {
            ffi.max_hydration_cache_size_gb
        },
    }
}

fn config_to_ffi(c: &crate::models::SyncConfig) -> SyncConfigFfi {
    use crate::models::{ConflictStrategy, SyncMode, WcfDeleteMode};

    let sync_mode = match c.sync_mode {
        SyncMode::Full => "full",
        SyncMode::UploadOnly => "upload_only",
        SyncMode::DownloadOnly => "download_only",
        SyncMode::AlbumUpload => "album_upload",
        SyncMode::AlbumDownload => "album_download",
        SyncMode::MirrorWcf => "mirror_wcf",
    };

    let conflict_strategy = match c.conflict_strategy {
        ConflictStrategy::KeepLocal => "keep_local",
        ConflictStrategy::KeepRemote => "keep_remote",
        ConflictStrategy::KeepBoth => "keep_both",
        ConflictStrategy::NewestWins => "newest_wins",
        ConflictStrategy::LargestWins => "largest_wins",
        ConflictStrategy::Manual => "manual",
    };

    let wcf_delete_mode = match c.wcf_delete_mode {
        WcfDeleteMode::LocalOnly => "wcf_delete_local_only",
        WcfDeleteMode::SyncRemote => "wcf_delete_sync_remote",
    };

    SyncConfigFfi {
        base_url: c.base_url.clone(),
        access_token: c.access_token.clone(),
        refresh_token: c.refresh_token.clone(),
        local_root: c.local_root.to_string_lossy().to_string(),
        remote_root: c.remote_root.clone(),
        sync_mode: sync_mode.to_string(),
        conflict_strategy: conflict_strategy.to_string(),
        wcf_delete_mode: wcf_delete_mode.to_string(),
        max_concurrent_transfers: c.max_concurrent_transfers as u32,
        bandwidth_limit_kbps: c.bandwidth_limit.map(|b| b / 1024).unwrap_or(0),
        excluded_paths: c.excluded_paths.clone(),
        max_workers: c.max_workers as u32,
        data_dir: c.data_dir.to_string_lossy().to_string(),
        client_id: c.client_id.clone(),
        log_level: String::new(),
        max_hydration_cache_size_gb: c.max_hydration_cache_size_gb,
    }
}

fn status_to_ffi(s: crate::models::SyncStatusSnapshot) -> SyncStatusFfi {
    let error_msg = if let crate::models::SyncState::Error { ref message } = s.state {
        Some(message.clone())
    } else {
        s.error_message
    };

    let state = match s.state {
        crate::models::SyncState::Idle => "idle".to_string(),
        crate::models::SyncState::Initializing => "initializing".to_string(),
        crate::models::SyncState::InitialSync { .. } => "initialSync".to_string(),
        crate::models::SyncState::Continuous => "continuous".to_string(),
        crate::models::SyncState::Paused => "paused".to_string(),
        crate::models::SyncState::Error { .. } => "error".to_string(),
        crate::models::SyncState::Stopped => "stopped".to_string(),
    };

    SyncStatusFfi {
        state,
        synced_files: s.synced_files,
        total_files: s.total_files,
        uploading_count: s.uploading_count,
        downloading_count: s.downloading_count,
        conflict_count: s.conflict_count,
        error_count: s.error_count,
        last_sync_time: s.last_sync_time,
        error_message: error_msg,
    }
}

fn summary_to_ffi(s: crate::models::SyncSummary) -> SyncSummaryFfi {
    SyncSummaryFfi {
        uploaded: s.uploaded,
        downloaded: s.downloaded,
        renamed: s.renamed,
        moved: s.moved,
        conflicts: s.conflicts,
        failed: s.failed,
        skipped: s.skipped,
        deleted_local: s.deleted_local,
        deleted_remote: s.deleted_remote,
        duration_ms: s.duration_ms,
    }
}

fn album_result_to_ffi(r: crate::models::CloudAlbumCheckResult) -> CloudAlbumCheckResultFfi {
    CloudAlbumCheckResultFfi {
        dcim_exists: r.dcim_exists,
        pictures_exists: r.pictures_exists,
        dcim_uri: r.dcim_uri,
        pictures_uri: r.pictures_uri,
        camera_exists: r.camera_exists,
        camera_uri: r.camera_uri,
    }
}

/// 获取引擎引用，未初始化则返回错误
fn get_engine() -> Result<&'static SyncEngine, SyncErrorFfi> {
    ENGINE.get().map(|arc| arc.as_ref()).ok_or(SyncErrorFfi::NotInitialized)
}

/// 内部：应用日志级别到 reload handle
fn apply_log_level(level: &str) {
    if level.is_empty() {
        return;
    }
    if let Some(handle) = LOG_RELOAD_HANDLE.get() {
        let directive = format!("sync_core={}", level);
        match handle.modify(|filter| {
            *filter = tracing_subscriber::EnvFilter::new(&directive);
        }) {
            Ok(()) => eprintln!("[sync-core] 日志级别已切换为: {}", level),
            Err(e) => eprintln!("[sync-core] 修改日志级别失败: {}", e),
        }
    }
}

// ========== 生命周期 ==========

/// 初始化同步引擎
#[frb]
pub async fn init_sync_engine(config: SyncConfigFfi) -> Result<(), SyncErrorFfi> {
    eprintln!("[FFI] init_sync_engine ← mode={}, conflict={}, wcf_delete={}, concurrent={}, bandwidth={}kbps, log_level={}",
        config.sync_mode, config.conflict_strategy, config.wcf_delete_mode, config.max_concurrent_transfers,
        config.bandwidth_limit_kbps, config.log_level);

    // 确保本地同步目录存在
    let local_root = std::path::PathBuf::from(&config.local_root);
    if !local_root.exists() {
        std::fs::create_dir_all(&local_root).map_err(|e| SyncErrorFfi::InternalError {
            message: format!("无法创建同步目录: {}", e),
        })?;
    }

    // 确保程序数据目录存在
    let data_dir = std::path::PathBuf::from(&config.data_dir);
    let db_dir = data_dir.join("sync_core").join("datas");
    let log_dir = data_dir.join("sync_core").join("logs");
    if !db_dir.exists() {
        std::fs::create_dir_all(&db_dir).map_err(|e| SyncErrorFfi::InternalError {
            message: format!("无法创建数据库目录: {}", e),
        })?;
    }
    if !log_dir.exists() {
        std::fs::create_dir_all(&log_dir).map_err(|e| SyncErrorFfi::InternalError {
            message: format!("无法创建日志目录: {}", e),
        })?;
    }

    // 初始化 tracing 日志：输出到程序数据目录的 logs 和 stderr
    let log_path = log_dir.join("sync_log.txt");
    eprintln!("[sync-core] 日志文件: {}", log_path.display());

    let log_file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .ok();

    if log_file.is_none() {
        eprintln!("[sync-core] 警告: 无法创建日志文件 {}", log_path.display());
    }

    // Android: 初始化 Logcat 日志后端（tracing → log → android_logger → Logcat）
    #[cfg(target_os = "android")]
    android_log::init_android_logger();

    // 尝试初始化 subscriber（仅首次有效，后续调用忽略）
    {
        use tracing_subscriber::layer::SubscriberExt;
        use tracing_subscriber::util::SubscriberInitExt;

        let filter = tracing_subscriber::EnvFilter::from_default_env()
            .add_directive("sync_core=debug".parse().unwrap());

        let (reload_filter, reload_handle) =
            tracing_subscriber::reload::Layer::<_, tracing_subscriber::Registry>::new(filter);
        LOG_RELOAD_HANDLE.set(reload_handle).ok();

        let registry = tracing_subscriber::registry().with(reload_filter);

        // Android: 添加 Logcat 桥接层
        #[cfg(target_os = "android")]
        let registry = registry.with(android_log::AndroidLogLayer);

        if let Some(file) = log_file {
            let _ = registry
                .with(tracing_subscriber::fmt::layer()
                    .with_writer(std::sync::Mutex::new(file))
                    .with_ansi(false))
                .with(tracing_subscriber::fmt::layer()
                    .with_writer(std::io::stderr))
                .try_init();
        } else {
            let _ = registry
                .with(tracing_subscriber::fmt::layer()
                    .with_writer(std::io::stderr))
                .try_init();
        }
    }

    // 提取配置信息用于日志（在 move 之前）
    let log_sync_mode = config.sync_mode.clone();
    let log_conflict_strategy = config.conflict_strategy.clone();
    let log_max_concurrent = config.max_concurrent_transfers;
    let log_bandwidth = config.bandwidth_limit_kbps;
    let log_level = config.log_level.clone();

    let engine = SyncEngine::new(config_from_ffi(config)).await
        .map_err(error_to_ffi)?;

    // 跨重启重建 FUSE 水合缓存索引（仅 linux-fuse 编译启用）
    #[cfg(feature = "linux-fuse")]
    engine.rebuild_hydration_cache_index().await;

    ENGINE.set(Arc::new(engine))
        .map_err(|_| SyncErrorFfi::InternalError {
            message: "引擎已初始化".to_string(),
        })?;

    tracing::info!("同步引擎初始化完成, 日志文件: {}", log_path.display());
    tracing::info!(
        "配置: 模式={}, 冲突策略={}, 并发={}, 带宽限制={}kbps",
        log_sync_mode, log_conflict_strategy, log_max_concurrent, log_bandwidth,
    );
    if log_bandwidth > 0 {
        tracing::info!("仅对下载限速生效, 由于Cloudreve实现原因, 上传限速无法生效");
    }

    // 应用配置中的日志级别（热修改覆盖默认 debug）
    apply_log_level(&log_level);

    // 注册 SIGINT/SIGTERM 信号处理，确保 FUSE/WCF 等资源被优雅清理
    #[cfg(unix)]
    {
        tokio::spawn(async {
            let mut sigterm = match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
                Ok(s) => s,
                Err(e) => {
                    tracing::warn!("无法注册 SIGTERM 处理: {}", e);
                    return;
                }
            };
            tokio::select! {
                _ = tokio::signal::ctrl_c() => {
                    tracing::info!("收到 SIGINT，开始清理...");
                }
                _ = sigterm.recv() => {
                    tracing::info!("收到 SIGTERM，开始清理...");
                }
            }
            sync_shutdown().ok();
            std::process::exit(0);
        });
    }
    #[cfg(not(unix))]
    {
        tokio::spawn(async {
            if tokio::signal::ctrl_c().await.is_ok() {
                tracing::info!("收到 Ctrl+C，开始清理...");
                sync_shutdown().ok();
                std::process::exit(0);
            }
        });
    }

    Ok(())
}

/// 销毁同步引擎
#[frb]
pub async fn dispose_sync_engine() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] dispose_sync_engine ←");
    let engine = get_engine()?;
    engine.stop().await.map_err(error_to_ffi)?;

    #[cfg(feature = "windows-cfapi")]
    {
        engine.cleanup_wcf();
    }

    #[cfg(feature = "linux-fuse")]
    {
        engine.cleanup_fuse();
    }

    tracing::info!("同步引擎已停止");
    Ok(())
}

/// 进程退出前同步清理（WCF/FUSE 模式下必须调用，确保占位符释放和挂载点卸载）
/// 此函数是同步的，不依赖 tokio runtime，可安全在 exit(0) 前调用
#[frb]
pub fn sync_shutdown() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] sync_shutdown ←");
    #[cfg(feature = "windows-cfapi")]
    {
        let engine = match ENGINE.get() {
            Some(e) => e,
            None => return Ok(()),
        };
        engine.cleanup_wcf();
    }
    #[cfg(feature = "linux-fuse")]
    {
        let engine = match ENGINE.get() {
            Some(e) => e,
            None => return Ok(()),
        };
        engine.cleanup_fuse();
    }
    tracing::info!("同步引擎已同步清理");
    Ok(())
}

// ========== 同步控制 ==========

/// 执行初始全量同步
#[frb]
pub async fn start_initial_sync() -> Result<SyncSummaryFfi, SyncErrorFfi> {
    tracing::debug!("[FFI] start_initial_sync ←");
    let engine = get_engine()?;
    engine.ensure_token_fresh();
    engine.ensure_pause_token_fresh();
    engine.run_initial_sync().await
        .map(|s| {
            tracing::debug!("[FFI] start_initial_sync → uploaded={}, downloaded={}, conflicts={}, failed={}",
                s.uploaded, s.downloaded, s.conflicts, s.failed);
            summary_to_ffi(s)
        })
        .map_err(error_to_ffi)
}

/// 启动持续同步（后台运行，立即返回）
#[frb]
pub async fn start_continuous_sync() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] start_continuous_sync ←");
    let engine = get_engine()?;
    engine.ensure_token_fresh();
    engine.ensure_pause_token_fresh();
    let engine = engine.clone();
    tokio::spawn(async move {
        if let Err(e) = engine.run_continuous().await {
            tracing::error!("持续同步异常退出: {}", e);
        }
    });
    tracing::debug!("[FFI] start_continuous_sync → spawned");
    Ok(())
}

/// 停止同步
#[frb]
pub async fn stop_sync() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] stop_sync ←");
    let engine = get_engine()?;
    engine.stop().await.map_err(error_to_ffi)
}

/// 暂停同步
#[frb]
pub async fn pause_sync() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] pause_sync ←");
    let engine = get_engine()?;
    engine.pause().await.map_err(error_to_ffi)
}

/// 恢复同步
#[frb]
pub async fn resume_sync() -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] resume_sync ←");
    let engine = ENGINE.get().cloned().ok_or(SyncErrorFfi::NotInitialized)?;
    engine.resume().await.map_err(error_to_ffi)?;

    // resume 不是简单改状态：软暂停会取消当前 watcher/worker。
    // 这里后台重新跑一次差异扫描，再启动持续同步；DB 映射和 .sync_tmp 会作为检查点继续。
    let engine_for_resume = engine.clone();
    tokio::spawn(async move {
        engine_for_resume.ensure_token_fresh();
        engine_for_resume.ensure_pause_token_fresh();

        match engine_for_resume.run_initial_sync().await {
            Ok(summary) => {
                tracing::info!(
                    "软暂停恢复扫描完成: uploaded={}, downloaded={}, failed={}",
                    summary.uploaded,
                    summary.downloaded,
                    summary.failed,
                );
                let engine_for_continuous = engine_for_resume.clone();
                tokio::spawn(async move {
                    if let Err(e) = engine_for_continuous.run_continuous().await {
                        tracing::error!("恢复后的持续同步异常退出: {}", e);
                    }
                });
            }
            Err(e) => {
                let message = e.to_string();
                if engine_for_resume.is_shutdown_cancelled() || engine_for_resume.is_soft_paused() {
                    tracing::warn!("软暂停恢复扫描被暂停/停止中断: {}", message);
                } else {
                    tracing::error!("软暂停恢复扫描失败: {}", message);
                    engine_for_resume.set_error_state(message).await;
                }
            }
        }
    });

    tracing::debug!("[FFI] resume_sync → checkpoint rescan spawned");
    Ok(())
}

/// 强制同步（重新扫描全量差异）
#[frb]
pub async fn force_sync() -> Result<SyncSummaryFfi, SyncErrorFfi> {
    tracing::debug!("[FFI] force_sync ←");
    let engine = get_engine()?;
    engine.force_sync().await
        .map(|s| {
            tracing::debug!("[FFI] force_sync → uploaded={}, downloaded={}, conflicts={}, failed={}",
                s.uploaded, s.downloaded, s.conflicts, s.failed);
            summary_to_ffi(s)
        })
        .map_err(error_to_ffi)
}

/// 重置同步：停止任务 → 清空 DB → (可选)清空本地目录 → 回到初始状态
#[frb]
pub async fn reset_sync(delete_local_files: bool) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] reset_sync ← delete_local_files={}", delete_local_files);
    let engine = get_engine()?;
    engine.reset_sync(delete_local_files).await.map_err(error_to_ffi)
}

// ========== 状态查询 ==========

/// 获取同步状态快照
#[frb]
pub async fn get_sync_status() -> Result<SyncStatusFfi, SyncErrorFfi> {
    let engine = get_engine()?;
    let s = engine.status().await;
    tracing::trace!("[FFI] get_sync_status → state={:?}, synced={}, total={}", s.state, s.synced_files, s.total_files);
    Ok(status_to_ffi(s))
}

/// 获取活跃 Worker 数量
#[frb]
pub async fn get_active_worker_count() -> Result<u32, SyncErrorFfi> {
    let engine = get_engine()?;
    let count = engine.active_worker_count();
    tracing::trace!("[FFI] get_active_worker_count → {}", count);
    Ok(count)
}

/// 获取同步配置
#[frb]
pub async fn get_sync_config() -> Result<SyncConfigFfi, SyncErrorFfi> {
    let engine = get_engine()?;
    let c = engine.config().await;
    tracing::trace!("[FFI] get_sync_config → mode={:?}, conflict={:?}", c.sync_mode, c.conflict_strategy);
    Ok(config_to_ffi(&c))
}

/// 更新同步配置
#[frb]
pub async fn update_sync_config(config: SyncConfigFfi) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] update_sync_config ← mode={}, conflict={}, wcf_delete={}, concurrent={}, bandwidth={}kbps",
        config.sync_mode, config.conflict_strategy, config.wcf_delete_mode, config.max_concurrent_transfers, config.bandwidth_limit_kbps);
    let engine = get_engine()?;
    engine.update_config(config_from_ffi(config)).await.map_err(error_to_ffi)
}

// ========== Token 管理 ==========

/// Dart 推送新 Token 给 Rust
#[frb]
pub async fn update_tokens(access_token: String) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] update_tokens ← token_len={}", access_token.len());
    let engine = get_engine()?;
    engine.update_access_token(access_token).await;
    Ok(())
}

// ========== Windows 专用 ==========

/// 水合文件（Windows 按需下载）
#[frb]
pub async fn hydrate_file(local_path: String) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] hydrate_file ← path={}", local_path);
    let engine = get_engine()?;
    engine.hydrate_file(&local_path).await.map_err(error_to_ffi)
}

// ========== Android 专用 ==========

/// 同步相册到云端
#[frb]
pub async fn sync_album_to_cloud(
    album_paths: Vec<String>,
    remote_dcim_uri: String,
) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] sync_album_to_cloud ← paths={}, uri={}", album_paths.len(), remote_dcim_uri);
    let engine = get_engine()?;
    engine.sync_album(album_paths, &remote_dcim_uri).await.map_err(error_to_ffi)
}

/// 检查云端是否存在 DCIM/Pictures 目录
#[frb]
pub async fn check_cloud_album_dirs(base_uri: String) -> Result<CloudAlbumCheckResultFfi, SyncErrorFfi> {
    tracing::debug!("[FFI] check_cloud_album_dirs ← uri={}", base_uri);
    let engine = get_engine()?;
    engine.check_album_dirs(&base_uri).await
        .map(|r| {
            tracing::debug!("[FFI] check_cloud_album_dirs → dcim={}, pictures={}", r.dcim_exists, r.pictures_exists);
            album_result_to_ffi(r)
        })
        .map_err(error_to_ffi)
}

/// 在云端创建 DCIM/Pictures 目录
#[frb]
pub async fn create_cloud_album_dirs(base_uri: String) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] create_cloud_album_dirs ← uri={}", base_uri);
    let engine = get_engine()?;
    engine.create_album_dirs(&base_uri).await.map_err(error_to_ffi)
}

// ========== 事件推送 ==========

/// 注册 Rust→Dart 事件推送通道
#[frb]
pub fn register_sync_event_sink(sink: crate::frb_generated::StreamSink<SyncEventFfi>) -> Result<(), SyncErrorFfi> {
    tracing::debug!("[FFI] register_sync_event_sink ←");
    let engine = get_engine()?;
    // flutter_rust_bridge 可能在非 Tokio 线程调用此同步函数，
    // 使用 spawn_blocking + block_on 确保 runtime 上下文可用
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| SyncErrorFfi::InternalError { message: format!("创建 Tokio runtime 失败: {}", e) })?;
    rt.block_on(engine.register_event_sink(sink));
    Ok(())
}

// ========== 日志级别 ==========

/// 运行时热修改日志级别（立即生效，无需重启）
#[frb]
pub fn set_sync_log_level(level: String) -> Result<(), SyncErrorFfi> {
    eprintln!("[FFI] set_sync_log_level ← level={}", level);
    let valid_levels = ["error", "warn", "info", "debug", "trace"];
    let level_lower = level.to_lowercase();
    if !valid_levels.contains(&level_lower.as_str()) {
        return Err(SyncErrorFfi::InternalError {
            message: format!("无效的日志级别: {}, 可选: {:?}", level, valid_levels),
        });
    }

    if LOG_RELOAD_HANDLE.get().is_none() {
        return Err(SyncErrorFfi::NotInitialized);
    }

    apply_log_level(&level_lower);
    Ok(())
}

// ========== 任务查询 ==========

/// 获取活跃的同步任务列表
#[frb]
pub async fn get_active_tasks() -> Result<Vec<SyncTaskFfi>, SyncErrorFfi> {
    let engine = get_engine()?;
    let tasks = engine.get_active_tasks().await.map_err(error_to_ffi)?;
    tracing::trace!("[FFI] get_active_tasks → count={}", tasks.len());
    Ok(tasks.into_iter().map(task_to_ffi).collect())
}

/// 获取最近同步任务列表
#[frb]
pub async fn get_recent_tasks(limit: u32) -> Result<Vec<SyncTaskFfi>, SyncErrorFfi> {
    tracing::trace!("[FFI] get_recent_tasks ← limit={}", limit);
    let engine = get_engine()?;
    let tasks = engine.get_recent_tasks(limit).await.map_err(error_to_ffi)?;
    tracing::trace!("[FFI] get_recent_tasks → count={}", tasks.len());
    Ok(tasks.into_iter().map(task_to_ffi).collect())
}

/// 获取任务详情（任务项列表）
#[frb]
pub async fn get_task_detail(task_id: String) -> Result<Vec<SyncTaskItemFfi>, SyncErrorFfi> {
    tracing::trace!("[FFI] get_task_detail ← task_id={}", task_id);
    let engine = get_engine()?;
    let items = engine.get_task_detail(&task_id).await.map_err(error_to_ffi)?;
    tracing::trace!("[FFI] get_task_detail → count={}", items.len());
    Ok(items.into_iter().map(task_item_to_ffi).collect())
}

/// 多维度查询任务项
#[frb]
pub async fn query_task_items(filter: TaskItemFilterFfi) -> Result<Vec<SyncTaskItemFfi>, SyncErrorFfi> {
    tracing::trace!("[FFI] query_task_items ← task_id={:?}, action={:?}, status={:?}, limit={}",
        filter.task_id, filter.action_type, filter.status, filter.limit);
    let engine = get_engine()?;
    let model_filter = crate::models::TaskItemFilter {
        task_id: filter.task_id,
        relative_path_contains: filter.relative_path_contains,
        action_type: filter.action_type,
        status: filter.status,
        limit: filter.limit.max(1).min(1000),
        offset: filter.offset,
    };
    let items = engine.query_task_items(&model_filter).await.map_err(error_to_ffi)?;
    tracing::trace!("[FFI] query_task_items → count={}", items.len());
    Ok(items.into_iter().map(task_item_to_ffi).collect())
}

/// 获取累积统计（从 DB 聚合，跨所有同步任务）
#[frb]
pub async fn get_sync_cum_stats() -> Result<SyncCumStatsFfi, SyncErrorFfi> {
    tracing::trace!("[FFI] get_sync_cum_stats ←");
    let engine = get_engine()?;
    let stats = engine.get_cum_stats().await.map_err(error_to_ffi)?;
    tracing::trace!("[FFI] get_sync_cum_stats → uploaded={}, downloaded={}, renamed={}, moved={}, failed={}, conflicts={}, deleted_local={}, deleted_remote={}, skipped={}",
        stats.uploaded, stats.downloaded, stats.renamed, stats.moved, stats.failed, stats.conflicts, stats.deleted_local, stats.deleted_remote, stats.skipped);
    Ok(SyncCumStatsFfi {
        uploaded: stats.uploaded,
        downloaded: stats.downloaded,
        renamed: stats.renamed,
        moved: stats.moved,
        failed: stats.failed,
        conflicts: stats.conflicts,
        deleted_local: stats.deleted_local,
        deleted_remote: stats.deleted_remote,
        skipped: stats.skipped,
    })
}

fn task_to_ffi(t: crate::models::SyncTask) -> SyncTaskFfi {
    SyncTaskFfi {
        id: t.id,
        trigger: t.trigger.as_str().to_string(),
        total_count: t.total_count,
        completed_count: t.completed_count,
        failed_count: t.failed_count,
        status: t.status.as_str().to_string(),
        created_at: t.created_at,
        updated_at: t.updated_at,
        finished_at: t.finished_at,
    }
}

fn task_item_to_ffi(i: crate::models::SyncTaskItem) -> SyncTaskItemFfi {
    SyncTaskItemFfi {
        id: i.id,
        task_id: i.task_id,
        relative_path: i.relative_path,
        action_type: i.action_type.as_str().to_string(),
        status: i.status.as_str().to_string(),
        file_size: i.file_size,
        error_message: i.error_message,
        created_at: i.created_at,
        updated_at: i.updated_at,
    }
}
