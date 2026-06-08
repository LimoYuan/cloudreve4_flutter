use crate::errors::{Result, SyncError};
use crate::fs_scanner::FsScanner;
use crate::models::*;
use crate::utils::lock_recover;
use std::time::Instant;

use super::SyncEngine;

impl SyncEngine {
    /// 初始全量同步（受 sync_lock 保护，同一时间只允许一个同步操作）
    pub async fn run_initial_sync(&self) -> Result<SyncSummary> {
        // 获取互斥锁：如果旧同步还在运行，等待其退出（旧同步的 token 已被取消，worker 会快速退出）
        let _guard = self.sync_lock.lock().await;

        // 检查是否已被取消
        if lock_recover(&self.shutdown_token).is_cancelled() {
            tracing::info!("初始同步已取消，跳过");
            return Err(SyncError::Internal("同步已被取消".into()));
        }

        let start = Instant::now();

        *self.state.write().await = SyncState::Initializing;

        let (local_root, remote_root, sync_mode) = {
            let config = self.config.read().await;
            (config.local_root.clone(), config.remote_root.clone(), config.sync_mode.clone())
        };
        tracing::info!("开始初始同步, 模式={:?}", sync_mode);

        let scanner = FsScanner::new();
        tracing::info!("开始扫描本地文件系统: {}", local_root.display());
        // MirrorWcf 模式跳过 hash 计算（占位符 size=0 被 diff 跳过，水合文件 hash 在需要时再算）
        let compute_hash = !matches!(sync_mode, SyncMode::MirrorWcf);
        let local_files = scanner.scan(&local_root, 50, false, compute_hash).await?;
        tracing::info!("本地扫描完成: {} 个条目", local_files.len());

        if lock_recover(&self.shutdown_token).is_cancelled() {
            return Err(SyncError::Internal("同步已被取消".into()));
        }

        tracing::info!("开始扫描远程文件树: {}", remote_root);
        let remote_files = self.api.list_all_files(&remote_root).await?;
        tracing::info!("远程扫描完成: {} 个条目", remote_files.len());

        if lock_recover(&self.shutdown_token).is_cancelled() {
            return Err(SyncError::Internal("同步已被取消".into()));
        }

        let db_mappings = self.load_all_mappings().await?;
        let plan = crate::diff::compute_diff(&local_files, &remote_files, &db_mappings, &remote_root, &sync_mode);
        tracing::info!(
            "差异计算完成: 上传={}, 下载={}, 删本地={}, 删远程={}, 冲突={}",
            plan.uploads.len(),
            plan.downloads.len(),
            plan.delete_local.len(),
            plan.delete_remote.len(),
            plan.conflicts.len(),
        );

        if lock_recover(&self.shutdown_token).is_cancelled() {
            return Err(SyncError::Internal("同步已被取消".into()));
        }

        *self.state.write().await = SyncState::InitialSync {
            progress: InitialSyncProgress {
                scanned_local: local_files.len() as u64,
                scanned_remote: remote_files.len() as u64,
                total_to_sync: plan.total_actions(),
                ..Default::default()
            },
        };

        let worker_config = self.snapshot_worker_config().await;
        let conflict_resolver = self.conflict.read().await.clone();

        // MirrorWcf 模式：初始化 WCF 平台适配器（仅首次，重复初始化会触发 CFApi 重新水合）
        #[cfg(feature = "windows-cfapi")]
        if matches!(sync_mode, SyncMode::MirrorWcf) {
            let already_initialized = lock_recover(&self.platform_adapter).is_some();
            if !already_initialized {
                let config = self.config.read().await;
                let adapter = crate::platform::wcf::WcfPlatformAdapter::new(
                    self.db.clone(),
                    self.api.clone(),
                    config.clone(),
                ).map_err(|e| crate::errors::SyncError::Internal(e.to_string()))?;
                let fetch_rx = adapter.take_fetch_receiver();
                *lock_recover(&self.wcf_fetch_rx) = fetch_rx;
                let adapter_arc = std::sync::Arc::new(adapter);
                *lock_recover(&self.platform_adapter) = Some(adapter_arc.clone());
                self.worker_pool.set_platform_adapter(adapter_arc);
                *lock_recover(&self.cached_local_root) = config.local_root.clone();
                tracing::info!("MirrorWcf: WCF 平台适配器已初始化");
            } else {
                tracing::info!("MirrorWcf: WCF 平台适配器已存在，跳过重复初始化");
            }
        }

        // MirrorFUSE 模式：初始化 FUSE 平台适配器（直接挂载到 local_root）
        #[cfg(feature = "linux-fuse")]
        if matches!(sync_mode, SyncMode::MirrorWcf) {
            let already_initialized = lock_recover(&self.fuse_adapter).is_some();
            if !already_initialized {
                let config = self.config.read().await;
                let mount_path = config.local_root.clone();
                let adapter = crate::platform::fuse::FusePlatformAdapter::new(
                    &mount_path,
                    self.db.clone(),
                    self.api.clone(),
                    config.clone(),
                ).map_err(|e| crate::errors::SyncError::Internal(e.to_string()))?;

                // 注册所有远程文件到 FUSE inode 表
                for remote in &remote_files {
                    let relative = crate::diff::remote_relative_path(
                        &remote_root, &remote.path, &remote.name, remote.is_dir
                    );
                    let parent_rel = std::path::PathBuf::from(&relative)
                        .parent()
                        .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
                        .unwrap_or_default();
                    let name = std::path::PathBuf::from(&relative)
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_default();
                    adapter.create_placeholder_for_remote(
                        &parent_rel,
                        &name,
                        &relative,
                        remote.is_dir,
                        remote.size,
                        &remote.uri,
                        remote.hash.as_deref(),
                        remote.mtime_ms,
                    );
                }

                let request_rx = adapter.take_request_receiver();
                *lock_recover(&self.fuse_request_rx) = request_rx;
                *lock_recover(&self.fuse_adapter) = Some(std::sync::Arc::new(adapter));
                tracing::info!("MirrorFUSE: FUSE 平台适配器已初始化, 挂载点={}, inode 数={}", mount_path.display(), remote_files.len());
            } else {
                tracing::info!("MirrorFUSE: FUSE 平台适配器已存在，跳过重复初始化");
            }
        }

        let result = self.worker_pool.submit(
            plan, worker_config, WorkerTrigger::InitialSync, conflict_resolver,
        ).await;

        match result {
            Ok(summary) => {
                *self.state.write().await = SyncState::Continuous;
                tracing::info!("初始同步完成, 耗时 {}ms", start.elapsed().as_millis());
                Ok(SyncSummary {
                    duration_ms: start.elapsed().as_millis() as u64,
                    ..summary
                })
            }
            Err(e) => {
                // 被取消时不需要设 Error 状态
                if lock_recover(&self.shutdown_token).is_cancelled() {
                    tracing::info!("初始同步已取消");
                    Err(SyncError::Internal("同步已被取消".into()))
                } else {
                    Err(e)
                }
            }
        }
        // _guard 在此处 drop，释放 sync_lock
    }
}
