use crate::api_client::ApiClient;
use crate::conflict_resolver::ConflictResolver;
use crate::errors::{Result, SyncError};
use crate::file_lock::FileLockRegistry;
use crate::models::*;
use crate::sync_db::SyncDb;
use crate::utils::lock_recover;
use super::worker_impl::Worker;
#[cfg(feature = "windows-cfapi")]
use super::worker_impl::PlaceholderCreator;
use dashmap::DashMap;
use dashmap::DashSet;
use std::sync::Arc;
use tokio::sync::Semaphore;
use tokio_util::sync::CancellationToken;

/// WorkerPool — 全局 Worker 并发控制
pub struct WorkerPool {
    worker_semaphore: Arc<Semaphore>,
    active_workers: Arc<DashMap<String, tokio::task::JoinHandle<()>>>,
    /// 当前正在上传的相对路径集合，用于去重
    active_upload_paths: Arc<DashSet<String>>,
    /// 活跃 worker 总数（包括 submit 阻塞型 + submit_background 后台型）
    active_count: Arc<std::sync::atomic::AtomicU32>,
    db: Arc<SyncDb>,
    api: Arc<ApiClient>,
    file_locks: Arc<FileLockRegistry>,
    ensured_dirs: Arc<DashMap<String, ()>>,
    event_sink: Arc<crate::event_sink::EventSink>,
    /// 抑制路径：上传失败清理远端碎片时，防止 SSE 删除事件误删本地文件
    suppress_paths: Arc<DashMap<String, std::time::Instant>>,
    shutdown_token: std::sync::Mutex<CancellationToken>,
    pause_token: std::sync::Mutex<CancellationToken>,
    #[cfg(feature = "windows-cfapi")]
    platform_adapter: std::sync::Mutex<Option<Arc<dyn PlaceholderCreator>>>,
}

impl WorkerPool {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        db: Arc<SyncDb>,
        api: Arc<ApiClient>,
        file_locks: Arc<FileLockRegistry>,
        ensured_dirs: Arc<DashMap<String, ()>>,
        event_sink: Arc<crate::event_sink::EventSink>,
        shutdown_token: CancellationToken,
        pause_token: CancellationToken,
        max_workers_override: usize,
        client_id: &str,
    ) -> Self {
        let cpu_count = num_cpus();
        let max_workers = if max_workers_override > 0 {
            max_workers_override.min(cpu_count * 2).max(1)
        } else {
            cpu_count.clamp(1, 32)
        };
        tracing::info!(
            "WorkerPool 初始化: 最大并发 Worker 数={} (cpu={}, override={})",
            max_workers,
            cpu_count,
            max_workers_override
        );
        tracing::info!("Client ID: {}", client_id);

        Self {
            worker_semaphore: Arc::new(Semaphore::new(max_workers)),
            active_workers: Arc::new(DashMap::new()),
            active_upload_paths: Arc::new(DashSet::new()),
            active_count: Arc::new(std::sync::atomic::AtomicU32::new(0)),
            db,
            api,
            file_locks,
            ensured_dirs,
            event_sink,
            suppress_paths: Arc::new(DashMap::new()),
            shutdown_token: std::sync::Mutex::new(shutdown_token),
            pause_token: std::sync::Mutex::new(pause_token),
            #[cfg(feature = "windows-cfapi")]
            platform_adapter: std::sync::Mutex::new(None),
        }
    }

    /// 提交 Worker（阻塞等待结果）
    pub async fn submit(
        &self,
        plan: SyncPlan,
        config: WorkerConfig,
        trigger: WorkerTrigger,
        conflict_resolver: ConflictResolver,
    ) -> Result<SyncSummary> {
        if !plan.has_work() {
            tracing::debug!("SyncPlan 无操作，跳过 Worker 创建");
            return Ok(SyncSummary::default());
        }

        let task_id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().to_rfc3339();

        let total_count = plan.uploads.len() as u32
            + plan.downloads.len() as u32
            + plan.delete_local.len() as u32
            + plan.delete_remote.len() as u32
            + plan.rename_remote.len() as u32
            + plan.move_remote.len() as u32
            + plan.rename_local.len() as u32
            + plan.move_local.len() as u32
            + plan.conflicts.len() as u32;

        let task = SyncTask {
            id: task_id.clone(),
            trigger: trigger.clone(),
            total_count,
            completed_count: 0,
            failed_count: 0,
            status: WorkerStatus::Pending,
            created_at: now.clone(),
            updated_at: now,
            finished_at: None,
        };
        self.db.create_sync_task(&task).await?;

        let now_for_items = chrono::Utc::now().to_rfc3339();
        self.create_task_items(&task_id, &plan, &now_for_items, &config.sync_mode)
            .await?;

        let _permit = self
            .worker_semaphore
            .acquire()
            .await
            .map_err(|e| SyncError::Internal(format!("获取 Worker 信号量失败: {}", e)))?;

        let worker = Worker::new(
            task_id.clone(),
            trigger,
            config,
            plan,
            self.db.clone(),
            self.api.clone(),
            self.file_locks.clone(),
            self.ensured_dirs.clone(),
            conflict_resolver,
            self.event_sink.clone(),
            self.suppress_paths.clone(),
            lock_recover(&self.shutdown_token).clone(),
            lock_recover(&self.pause_token).clone(),
            #[cfg(feature = "windows-cfapi")]
            lock_recover(&self.platform_adapter).clone(),
        );

        let _ = self
            .event_sink
            .emit(crate::api::ffi_types::SyncEventFfi::WorkerStarted {
                task_id: task_id.clone(),
                trigger: task.trigger.as_str().to_string(),
                upload_count: task.total_count,
                download_count: 0,
            })
            .await;

        self.active_count
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let result = worker.run().await;
        self.active_count
            .fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
        result
    }

    /// 提交 Worker（后台运行）
    pub async fn submit_background(
        &self,
        plan: SyncPlan,
        config: WorkerConfig,
        trigger: WorkerTrigger,
        conflict_resolver: ConflictResolver,
    ) -> Option<String> {
        if !plan.has_work() {
            return None;
        }

        let task_id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().to_rfc3339();

        let total_count = plan.uploads.len() as u32
            + plan.downloads.len() as u32
            + plan.delete_local.len() as u32
            + plan.delete_remote.len() as u32
            + plan.rename_remote.len() as u32
            + plan.move_remote.len() as u32
            + plan.rename_local.len() as u32
            + plan.move_local.len() as u32
            + plan.conflicts.len() as u32;

        let task = SyncTask {
            id: task_id.clone(),
            trigger: trigger.clone(),
            total_count,
            completed_count: 0,
            failed_count: 0,
            status: WorkerStatus::Pending,
            created_at: now.clone(),
            updated_at: now,
            finished_at: None,
        };
        if let Err(e) = self.db.create_sync_task(&task).await {
            tracing::error!("创建同步任务记录失败: {}", e);
        }

        let now_for_items = chrono::Utc::now().to_rfc3339();
        if let Err(e) = self
            .create_task_items(&task_id, &plan, &now_for_items, &config.sync_mode)
            .await
        {
            tracing::warn!("创建任务项记录失败: {}", e);
        }

        let tid = task_id.clone();
        let trigger_str = trigger.as_str().to_string();
        let upload_count = plan.uploads.len() as u32;
        let download_count = plan.downloads.len() as u32;

        let _ = self
            .event_sink
            .emit(crate::api::ffi_types::SyncEventFfi::WorkerStarted {
                task_id: tid.clone(),
                trigger: trigger_str,
                upload_count,
                download_count,
            })
            .await;

        self.register_upload_paths(&plan);
        let upload_paths_for_cleanup: Vec<String> = plan
            .uploads
            .iter()
            .map(|a| a.relative_path.clone())
            .collect();

        let sem = self.worker_semaphore.clone();
        let db = self.db.clone();
        let api = self.api.clone();
        let file_locks = self.file_locks.clone();
        let ensured_dirs = self.ensured_dirs.clone();
        let event_sink = self.event_sink.clone();
        let suppress_paths = self.suppress_paths.clone();
        let shutdown_token = lock_recover(&self.shutdown_token).clone();
        let pause_token = lock_recover(&self.pause_token).clone();
        let active_workers = self.active_workers.clone();
        let active_upload_paths = self.active_upload_paths.clone();
        let active_count = self.active_count.clone();
        #[cfg(feature = "windows-cfapi")]
        let platform_adapter = lock_recover(&self.platform_adapter).clone();

        self.active_count
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed);

        let handle = tokio::spawn(async move {
            let _permit = match sem.acquire().await {
                Ok(p) => p,
                Err(e) => {
                    tracing::warn!(
                        "[{}] Worker 信号量已关闭，跳过执行: {}",
                        task_id, e
                    );
                    let _ = event_sink
                        .emit(crate::api::ffi_types::SyncEventFfi::WorkerFailed {
                            task_id: task_id.clone(),
                            message: format!("Worker 信号量已关闭（同步引擎可能正在停止）: {}", e),
                        })
                        .await;
                    active_workers.remove(&task_id);
                    for path in &upload_paths_for_cleanup {
                        active_upload_paths.remove(path);
                    }
                    active_count.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
                    return;
                }
            };
            let worker = Worker::new(
                task_id.clone(),
                trigger,
                config,
                plan,
                db,
                api,
                file_locks,
                ensured_dirs,
                conflict_resolver,
                event_sink,
                suppress_paths,
                shutdown_token,
                pause_token,
                #[cfg(feature = "windows-cfapi")]
                platform_adapter,
            );
            if let Err(e) = worker.run().await {
                tracing::error!("[{}] Worker后台执行失败: {}", task_id, e);
            }
            active_workers.remove(&task_id);
            for path in &upload_paths_for_cleanup {
                active_upload_paths.remove(path);
            }
            active_count.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
        });

        self.active_workers.insert(tid.clone(), handle);
        Some(tid)
    }

    #[cfg(feature = "windows-cfapi")]
    pub fn set_platform_adapter(&self, adapter: Arc<dyn PlaceholderCreator>) {
        *lock_recover(&self.platform_adapter) = Some(adapter);
    }

    /// 当前活跃 Worker 数（含阻塞型和后台型）
    pub fn active_worker_count(&self) -> usize {
        self.active_count.load(std::sync::atomic::Ordering::Relaxed) as usize
    }

    /// 检查指定相对路径是否正在上传中
    pub fn is_uploading(&self, relative_path: &str) -> bool {
        self.active_upload_paths.contains(relative_path)
    }

    /// 注册上传路径到去重集合
    fn register_upload_paths(&self, plan: &SyncPlan) {
        for action in &plan.uploads {
            self.active_upload_paths
                .insert(action.relative_path.clone());
        }
    }

    /// 更新 shutdown token（引擎重启时调用）
    pub fn update_shutdown_token(&self, token: CancellationToken) {
        *lock_recover(&self.shutdown_token) = token;
    }

    /// 更新 pause token（软暂停恢复时调用）
    pub fn update_pause_token(&self, token: CancellationToken) {
        *lock_recover(&self.pause_token) = token;
    }

    /// 终止所有活跃 Worker 并等待退出
    pub async fn abort_all_workers(&self) {
        let ids: Vec<String> = self
            .active_workers
            .iter()
            .map(|e| e.key().clone())
            .collect();
        for id in ids {
            if let Some((_, handle)) = self.active_workers.remove(&id) {
                handle.abort();
                let _ = handle.await;
            }
        }
        self.active_upload_paths.clear();
        self.active_count
            .store(0, std::sync::atomic::Ordering::Relaxed);
    }

    /// 创建 task_item 记录（批量插入，单次持锁）
    async fn create_task_items(
        &self,
        task_id: &str,
        plan: &SyncPlan,
        now: &str,
        sync_mode: &SyncMode,
    ) -> Result<()> {
        let mut items: Vec<SyncTaskItem> = Vec::new();

        for action in &plan.uploads {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: action.relative_path.clone(),
                action_type: TaskActionType::Upload,
                status: TaskItemStatus::Pending,
                file_size: action.local_entry.as_ref().map(|l| l.size).unwrap_or(0),
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for action in &plan.downloads {
            let action_type = if matches!(sync_mode, SyncMode::MirrorWcf) {
                TaskActionType::CreatePlaceholder
            } else {
                TaskActionType::Download
            };
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: action.relative_path.clone(),
                action_type,
                status: TaskItemStatus::Pending,
                file_size: action.remote_entry.as_ref().map(|r| r.size).unwrap_or(0),
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for action in &plan.delete_local {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: action.relative_path.clone(),
                action_type: TaskActionType::DeleteLocal,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for action in &plan.delete_remote {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: action.relative_path.clone(),
                action_type: TaskActionType::DeleteRemote,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for rename in &plan.rename_remote {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: format!(
                    "{} -> {}",
                    rename.old_relative_path, rename.new_relative_path
                ),
                action_type: TaskActionType::Rename,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for mov in &plan.move_remote {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: format!("{} -> {}", mov.old_relative_path, mov.new_relative_path),
                action_type: TaskActionType::Move,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for conflict in &plan.conflicts {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: conflict.relative_path.clone(),
                action_type: TaskActionType::ConflictResolve,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for action in &plan.rename_local {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: format!(
                    "{} -> {}",
                    action.old_relative_path, action.new_relative_path
                ),
                action_type: TaskActionType::Rename,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }
        for action in &plan.move_local {
            items.push(SyncTaskItem {
                id: 0,
                task_id: task_id.to_string(),
                relative_path: format!(
                    "{} -> {}",
                    action.old_relative_path, action.new_relative_path
                ),
                action_type: TaskActionType::Move,
                status: TaskItemStatus::Pending,
                file_size: 0,
                error_message: None,
                created_at: now.to_string(),
                updated_at: now.to_string(),
            });
        }

        self.db.create_sync_task_items_batch(&items).await
    }
}

fn num_cpus() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
}
