mod initial_sync;
mod continuous_sync;
mod local_events;
mod remote_events;
mod album;
#[cfg(feature = "windows-cfapi")]
mod wcf;
#[cfg(feature = "linux-fuse")]
mod fuse;

// 非 WCF/FUSE feature 下的 stub 方法，供 remote_events.rs 编译通过
#[cfg(not(any(feature = "windows-cfapi", feature = "linux-fuse")))]
impl SyncEngine {
    async fn _create_placeholder_for_remote(
        &self,
        _relative: &str,
        _remote: &RemoteFileEntry,
        _local_root: &std::path::Path,
        _root_id: &str,
    ) {
        // MirrorWcf 模式在非 Windows/Linux-FUSE 平台不可用，此方法不应被调用
    }
}

use crate::api_client::ApiClient;
use crate::conflict_resolver::ConflictResolver;
use crate::errors::Result;
use crate::event_sink::EventSink;
use crate::file_lock::FileLockRegistry;
use crate::models::*;
use crate::sync_db::SyncDb;
use crate::utils::lock_recover;
use crate::worker::WorkerPool;
use dashmap::DashMap;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
#[cfg(feature = "windows-cfapi")]
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

pub struct SyncEngine {
    state: RwLock<SyncState>,
    db: Arc<SyncDb>,
    api: Arc<ApiClient>,
    config: RwLock<SyncConfig>,
    conflict: RwLock<ConflictResolver>,
    sync_root_id: Option<String>,
    shutdown_token: std::sync::Mutex<CancellationToken>,
    /// 软暂停 token：pause 时取消，resume 时刷新；用于区分“用户暂停”和“停止/重置”。
    pause_token: std::sync::Mutex<CancellationToken>,
    /// 同步操作互斥锁：防止 force_sync / run_initial_sync 并发
    sync_lock: tokio::sync::Mutex<()>,
    worker_pool: WorkerPool,
    #[allow(dead_code)]
    file_locks: Arc<FileLockRegistry>,
    #[allow(dead_code)]
    ensured_dirs: Arc<DashMap<String, ()>>,
    event_sink: Arc<EventSink>,
    /// 远程操作导致的本地路径变化，抑制本地 debouncer 自触发事件
    suppress_paths: Arc<DashMap<String, std::time::Instant>>,
    /// WCF 平台适配器（仅 MirrorWcf 模式下初始化）
    #[cfg(feature = "windows-cfapi")]
    platform_adapter: std::sync::Mutex<Option<Arc<crate::platform::wcf::WcfPlatformAdapter>>>,
    /// WCF FETCH_DATA 回调接收端（在适配器初始化时提取）
    #[cfg(feature = "windows-cfapi")]
    wcf_fetch_rx: std::sync::Mutex<Option<mpsc::Receiver<sync_windows::FetchDataRequest>>>,
    /// WCF 水合缓存：uri → 已下载的完整文件数据，避免同一文件重复下载
    #[cfg(feature = "windows-cfapi")]
    wcf_hydration_cache: Arc<DashMap<String, (Vec<u8>, std::time::Instant)>>,
    /// 缓存的本地同步根路径（WCF 清理时同步读取，避免 await）
    #[cfg(feature = "windows-cfapi")]
    cached_local_root: std::sync::Mutex<std::path::PathBuf>,
    /// FUSE 平台适配器（仅 MirrorWcf + linux-fuse 模式下初始化）
    #[cfg(feature = "linux-fuse")]
    fuse_adapter: std::sync::Mutex<Option<Arc<crate::platform::fuse::FusePlatformAdapter>>>,
    /// FUSE 请求接收端（在适配器初始化时提取）
    #[cfg(feature = "linux-fuse")]
    fuse_request_rx: std::sync::Mutex<Option<tokio::sync::mpsc::Receiver<crate::platform::fuse::FuseRequest>>>,
    /// FUSE 水合磁盘缓存索引：uri → 磁盘缓存文件元信息
    #[cfg(feature = "linux-fuse")]
    fuse_hydration_cache: Arc<DashMap<String, crate::platform::fuse::HydrationCacheEntry>>,
    /// FUSE 水合缓存目录
    #[cfg(feature = "linux-fuse")]
    fuse_hydration_cache_dir: std::path::PathBuf,
}

impl SyncEngine {
    pub async fn new(config: SyncConfig) -> Result<Self> {
        let db_path = config.data_dir.join("sync_core").join("datas").join(".sync_db.sqlite3");
        let db_path_clone = db_path.clone();
        let db = Arc::new(tokio::task::spawn_blocking(move || SyncDb::open(&db_path_clone)).await??);

        let api = Arc::new(ApiClient::new(&config.base_url, &config.access_token, &config.refresh_token, &config.client_id));

        let conflict = ConflictResolver::new(config.conflict_strategy.clone());

        let sync_root_id = match db.upsert_sync_root(&config).await {
            Ok(id) => Some(id),
            Err(e) => {
                tracing::warn!("写入 sync_root 失败: {}", e);
                None
            }
        };

        let shutdown_token = CancellationToken::new();
        let pause_token = CancellationToken::new();
        let file_locks = Arc::new(FileLockRegistry::new());
        let ensured_dirs = Arc::new(DashMap::new());
        let event_sink = Arc::new(EventSink::new());
        let suppress_paths = Arc::new(DashMap::new());

        #[cfg(feature = "linux-fuse")]
        let fuse_hydration_cache_dir = config.data_dir.join("sync_core").join("hydration_cache");
        #[cfg(feature = "linux-fuse")]
        {
            // 确保缓存目录存在（不清空，启动后由 rebuild_hydration_cache_index 重建索引）
            if let Err(e) = std::fs::create_dir_all(&fuse_hydration_cache_dir) {
                tracing::warn!("创建 FUSE 水合缓存目录失败: {}: {}", fuse_hydration_cache_dir.display(), e);
            }
        }

        let max_workers = config.max_workers;
        let client_id = config.client_id.clone();
        let worker_pool = WorkerPool::new(
            db.clone(),
            api.clone(),
            file_locks.clone(),
            ensured_dirs.clone(),
            event_sink.clone(),
            shutdown_token.clone(),
            pause_token.clone(),
            max_workers,
            &client_id,
        );

        Ok(Self {
            state: RwLock::new(SyncState::Idle),
            db,
            api,
            config: RwLock::new(config),
            conflict: RwLock::new(conflict),
            sync_root_id,
            shutdown_token: std::sync::Mutex::new(shutdown_token),
            pause_token: std::sync::Mutex::new(pause_token),
            sync_lock: tokio::sync::Mutex::new(()),
            worker_pool,
            file_locks,
            ensured_dirs,
            event_sink,
            suppress_paths,
            #[cfg(feature = "windows-cfapi")]
            platform_adapter: std::sync::Mutex::new(None),
            #[cfg(feature = "windows-cfapi")]
            wcf_fetch_rx: std::sync::Mutex::new(None),
            #[cfg(feature = "windows-cfapi")]
            wcf_hydration_cache: Arc::new(DashMap::new()),
            #[cfg(feature = "windows-cfapi")]
            cached_local_root: std::sync::Mutex::new(std::path::PathBuf::new()),
            #[cfg(feature = "linux-fuse")]
            fuse_adapter: std::sync::Mutex::new(None),
            #[cfg(feature = "linux-fuse")]
            fuse_request_rx: std::sync::Mutex::new(None),
            #[cfg(feature = "linux-fuse")]
            fuse_hydration_cache: Arc::new(DashMap::new()),
            #[cfg(feature = "linux-fuse")]
            fuse_hydration_cache_dir,
        })
    }

    async fn snapshot_worker_config(&self) -> WorkerConfig {
        let config = self.config.read().await;
        WorkerConfig {
            local_root: config.local_root.clone(),
            remote_root: config.remote_root.clone(),
            max_concurrent_transfers: config.max_concurrent_transfers,
            bandwidth_limit: config.bandwidth_limit,
            conflict_strategy: config.conflict_strategy.clone(),
            wcf_delete_mode: config.wcf_delete_mode.clone(),
            sync_root_id: self.sync_root_id.clone().unwrap_or_default(),
            sync_mode: config.sync_mode.clone(),
        }
    }

    /// 确保 shutdown token 未被取消（stop/pause 后重新启动时使用）
    pub fn ensure_token_fresh(&self) {
        let token = lock_recover(&self.shutdown_token).clone();
        if token.is_cancelled() {
            let new_token = tokio_util::sync::CancellationToken::new();
            self.worker_pool.update_shutdown_token(new_token.clone());
            *lock_recover(&self.shutdown_token) = new_token;
        }
    }

    /// 确保 pause token 未被取消（resume/force_sync 后重新启动 Worker 时使用）
    pub fn ensure_pause_token_fresh(&self) {
        let token = lock_recover(&self.pause_token).clone();
        if token.is_cancelled() {
            let new_token = tokio_util::sync::CancellationToken::new();
            self.worker_pool.update_pause_token(new_token.clone());
            *lock_recover(&self.pause_token) = new_token;
        }
    }

    pub async fn stop(&self) -> Result<()> {
        lock_recover(&self.shutdown_token).cancel();
        *self.state.write().await = SyncState::Stopped;
        Ok(())
    }

    /// 软暂停：取消当前 watcher/worker，但不清空 DB、不删除本地文件、不重置映射。
    /// resume 时会刷新 token 并重新跑一次差异扫描，从已有映射和 .sync_tmp 继续。
    pub async fn pause(&self) -> Result<()> {
        lock_recover(&self.pause_token).cancel();
        lock_recover(&self.shutdown_token).cancel();
        *self.state.write().await = SyncState::Paused;
        tracing::info!("同步已软暂停：当前 worker 将尽快退出，检查点数据保留");
        Ok(())
    }

    pub async fn resume(&self) -> Result<()> {
        self.ensure_token_fresh();
        self.ensure_pause_token_fresh();
        *self.state.write().await = SyncState::Continuous;
        tracing::info!("同步从软暂停恢复：已刷新 token，等待重新扫描差异");
        Ok(())
    }

    pub fn is_shutdown_cancelled(&self) -> bool {
        lock_recover(&self.shutdown_token).is_cancelled()
    }

    pub fn is_soft_paused(&self) -> bool {
        lock_recover(&self.pause_token).is_cancelled()
    }

    pub async fn set_error_state(&self, message: String) {
        *self.state.write().await = SyncState::Error { message };
    }

    pub async fn force_sync(&self) -> Result<SyncSummary> {
        // 取消当前所有操作（持续同步 + 正在运行的初始同步）
        lock_recover(&self.shutdown_token).cancel();

        // 创建新 token，供接下来的 run_initial_sync 使用
        let new_token = tokio_util::sync::CancellationToken::new();
        *lock_recover(&self.shutdown_token) = new_token.clone();
        self.worker_pool.update_shutdown_token(new_token);
        self.ensure_pause_token_fresh();

        // run_initial_sync 会等待 sync_lock（旧同步的 worker 检测到取消后快速退出，释放锁）
        self.run_initial_sync().await
    }

    /// 重置同步：停止任务 → 清空 DB → 清空本地目录 → 回到初始状态
    pub async fn reset_sync(&self, delete_local_files: bool) -> Result<()> {
        tracing::info!("开始重置同步... delete_local_files={}", delete_local_files);

        // 1. 停止同步
        self.stop().await?;

        // 2. 清理 WCF（重置时需要彻底清理）
        #[cfg(feature = "windows-cfapi")]
        {
            self.cleanup_wcf();
        }

        // 2b. 清理 FUSE
        #[cfg(feature = "linux-fuse")]
        {
            self.cleanup_fuse();
        }

        // 2c. 清空 FUSE 水合缓存（重置时彻底清理）
        #[cfg(feature = "linux-fuse")]
        {
            self.cleanup_stale_hydration_cache().await;
        }

        // 3. 终止所有活跃 Worker

        // 2. 终止所有活跃 Worker
        self.worker_pool.abort_all_workers().await;

        // 3. 清空 DB 业务数据
        self.db.reset_sync_data().await?;
        tracing::info!("同步数据库已清空");

        // 4. 清空本地同步目录（保留目录本身，只删内容）
        if delete_local_files {
            let local_root = self.config.read().await.local_root.clone();
            if local_root.exists() {
                let entries = std::fs::read_dir(&local_root)
                    .map_err(|_| crate::errors::SyncError::DiskFull { needed: 0, available: 0 })?;
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() {
                        let _ = std::fs::remove_dir_all(&path);
                    } else {
                        let _ = std::fs::remove_file(&path);
                    }
                }
                tracing::info!("本地同步目录已清空: {}", local_root.display());
            }
        } else {
            tracing::info!("跳过清空本地同步目录");
        }

        // 5. 清空内存缓存
        self.ensured_dirs.clear();
        self.suppress_paths.clear();

        // 6. 重置状态
        *self.state.write().await = SyncState::Idle;

        tracing::info!("同步重置完成，已回到初始状态");
        Ok(())
    }

    pub async fn status(&self) -> SyncStatusSnapshot {
        let state = self.state.try_read().map(|g| g.clone()).unwrap_or(SyncState::Idle);

        let (synced_files, total_files) = match &state {
            SyncState::InitialSync { progress } => {
                let done = progress.uploaded + progress.downloaded;
                (done, progress.total_to_sync)
            }
            SyncState::Continuous | SyncState::Paused => {
                // 持续同步/暂停：从活跃任务聚合进度
                let mut synced: u64 = 0;
                let mut total: u64 = 0;
                if let Ok(tasks) = self.db.get_active_sync_tasks().await {
                    for t in &tasks {
                        synced += t.completed_count as u64;
                        total += t.total_count as u64;
                    }
                }
                (synced, total)
            }
            _ => (0, 0),
        };

        SyncStatusSnapshot {
            state,
            synced_files,
            total_files,
            uploading_count: 0,
            downloading_count: 0,
            conflict_count: 0,
            error_count: 0,
            last_sync_time: None,
            error_message: None,
        }
    }

    pub fn active_worker_count(&self) -> u32 {
        self.worker_pool.active_worker_count() as u32
    }

    pub async fn config(&self) -> SyncConfig {
        self.config.read().await.clone()
    }

    pub async fn update_config(&self, new_config: SyncConfig) -> Result<()> {
        let (old_access_token, old_hydration_cache_gb) = {
            let config = self.config.read().await;
            (config.access_token.clone(), config.max_hydration_cache_size_gb)
        };

        *self.conflict.write().await = ConflictResolver::new(new_config.conflict_strategy.clone());

        if new_config.access_token != old_access_token {
            self.api.update_token(new_config.access_token.clone()).await;
        }

        let new_bandwidth = new_config.bandwidth_limit;
        let new_conflict = format!("{:?}", new_config.conflict_strategy);
        let new_wcf_delete = format!("{:?}", new_config.wcf_delete_mode);
        let new_mode = format!("{:?}", new_config.sync_mode);
        let new_max_concurrent = new_config.max_concurrent_transfers;
        let new_hydration_cache_gb = new_config.max_hydration_cache_size_gb;
        *self.config.write().await = new_config;

        if new_bandwidth.is_some() {
            tracing::info!("仅对下载限速生效, 由于Cloudreve实现原因, 上传限速无法生效");
        }
        tracing::info!(
            "同步配置已更新: 模式={}, 冲突策略={}, WCF删除={}, 并发={}, 带宽限制={:?}, 水合缓存上限={}GB",
            new_mode, new_conflict, new_wcf_delete, new_max_concurrent, new_bandwidth, new_hydration_cache_gb
        );

        #[cfg(feature = "linux-fuse")]
        if new_hydration_cache_gb != old_hydration_cache_gb {
            tracing::info!(
                "水合缓存上限变化: {}GB -> {}GB, 立即触发淘汰",
                old_hydration_cache_gb, new_hydration_cache_gb
            );
            self.evict_oversized_hydration_cache().await;
        }
        #[cfg(not(feature = "linux-fuse"))]
        let _ = old_hydration_cache_gb;

        Ok(())
    }

    pub async fn update_access_token(&self, token: String) {
        self.api.update_token(token).await;
    }

    pub async fn register_event_sink(&self, sink: crate::frb_generated::StreamSink<crate::api::ffi_types::SyncEventFfi>) {
        self.event_sink.register(sink).await;
    }

    pub async fn get_active_tasks(&self) -> Result<Vec<SyncTask>> {
        self.db.get_active_sync_tasks().await
    }

    pub async fn get_recent_tasks(&self, limit: u32) -> Result<Vec<SyncTask>> {
        self.db.get_recent_sync_tasks(limit).await
    }

    pub async fn get_task_detail(&self, task_id: &str) -> Result<Vec<SyncTaskItem>> {
        self.db.get_sync_task_items(task_id).await
    }

    pub async fn query_task_items(&self, filter: &TaskItemFilter) -> Result<Vec<SyncTaskItem>> {
        self.db.query_task_items(filter).await
    }

    pub async fn get_cum_stats(&self) -> Result<SyncCumStats> {
        self.db.get_cum_stats().await
    }

    pub async fn hydrate_file(&self, local_path: &str) -> Result<()> {
        #[cfg(feature = "windows-cfapi")]
        {
            let path = std::path::PathBuf::from(local_path);
            if let Some(adapter) = lock_recover(&self.platform_adapter).as_ref() {
                adapter.hydrate_file(&path)?;
            }
        }
        let _ = local_path;
        Ok(())
    }

    pub async fn shutdown(self) -> Result<()> {
        self.stop().await
    }

    async fn load_all_mappings(&self) -> Result<HashMap<String, FileMapping>> {
        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => return Ok(HashMap::new()),
        };

        let pool = self.db.read_pool();
        let result = tokio::task::spawn_blocking(move || -> Result<HashMap<String, FileMapping>> {
            let conn = pool.get()?;
            let mut stmt = conn.prepare(
                "SELECT id, sync_root_id, local_path, remote_uri, remote_file_id,
                        local_hash, remote_hash, local_mtime, remote_mtime,
                        local_size, remote_size, sync_status, is_placeholder
                 FROM file_mapping WHERE sync_root_id = ?1"
            )?;

            let mappings: HashMap<String, FileMapping> = stmt.query_map(
                rusqlite::params![root_id],
                |row| {
                    let local_path: String = row.get(2)?;
                    Ok((
                        crate::utils::normalize_path(&local_path),
                        FileMapping {
                            id: row.get(0)?,
                            sync_root_id: row.get(1)?,
                            local_path: std::path::PathBuf::from(local_path),
                            remote_uri: row.get(3)?,
                            remote_file_id: row.get(4)?,
                            local_hash: row.get(5)?,
                            remote_hash: row.get(6)?,
                            local_mtime: row.get(7)?,
                            remote_mtime: row.get(8)?,
                            local_size: row.get(9)?,
                            remote_size: row.get(10)?,
                            sync_status: crate::diff::parse_sync_status_from_str(&row.get::<_, String>(11)?),
                            is_placeholder: row.get::<_, i32>(12)? != 0,
                        },
                    ))
                },
            )?.filter_map(|r| r.ok()).collect();

            Ok(mappings)
        }).await??;

        Ok(result)
    }

    /// 记录绕过 WorkerPool 的操作统计（WCF / FUSE 共用）
    pub(crate) async fn _record_wcf_stats(
        &self,
        relative_path: &str,
        action_type: TaskActionType,
        file_size: u64,
        error_message: Option<String>,
    ) {
        let now = chrono::Utc::now().to_rfc3339();
        let status = if error_message.is_none() {
            TaskItemStatus::Completed
        } else {
            TaskItemStatus::Failed
        };
        let task_id = format!("wcf_{}", uuid::Uuid::new_v4());
        if let Err(e) = self.db.record_standalone_task_item(
            &WorkerTrigger::WcfEvent,
            &SyncTaskItem {
                id: 0,
                task_id,
                relative_path: relative_path.to_string(),
                action_type,
                status,
                file_size,
                error_message,
                created_at: now.clone(),
                updated_at: now,
            },
        ).await {
            tracing::warn!("WCF 统计记录失败: {}", e);
        }
    }
}
