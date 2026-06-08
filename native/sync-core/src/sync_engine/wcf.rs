//! WCF (Windows Cloud Filter API) 相关的 SyncEngine 方法
//! 仅在 windows-cfapi feature 启用时编译

use crate::models::*;
use crate::utils::lock_recover;

use super::SyncEngine;

#[cfg(feature = "windows-cfapi")]
impl SyncEngine {
    /// MirrorWcf: 处理 CFApi FETCH_DATA 回调（按需水合）
    pub(crate) async fn handle_wcf_fetch(
        &self,
        request: sync_windows::FetchDataRequest,
        _local_root: &std::path::Path,
    ) {
        let identity: serde_json::Value = match serde_json::from_slice(&request.file_identity) {
            Ok(v) => v,
            Err(e) => {
                tracing::error!("WCF 水合: FileIdentity 反序列化失败: {}", e);
                let _ = crate::platform::wcf::WcfPlatformAdapter::reject_fetch_data(
                    request.connection_key, request.transfer_key,
                );
                return;
            }
        };

        let remote_uri = identity["uri"].as_str().unwrap_or("").to_string();
        let remote_size = identity["size"].as_u64().unwrap_or(0);
        let remote_hash = identity["hash"].as_str().unwrap_or("").to_string();

        if remote_uri.is_empty() {
            tracing::error!("WCF 水合: FileIdentity 中 uri 为空");
            let _ = crate::platform::wcf::WcfPlatformAdapter::reject_fetch_data(
                request.connection_key, request.transfer_key,
            );
            return;
        }

        tracing::debug!("WCF 水合请求: uri={}, size={}, offset={}, length={}",
            remote_uri, remote_size, request.required_offset, request.required_length);

        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = crate::platform::wcf::WcfPlatformAdapter::reject_fetch_data(
                    request.connection_key, request.transfer_key,
                );
                return;
            }
        };

        // 清理过期缓存（超过 5 分钟）
        let now = std::time::Instant::now();
        self.wcf_hydration_cache.retain(|_, (_, ts)| now.duration_since(*ts).as_secs() < 300);

        // 尝试从缓存获取已下载的数据；cache miss 时下载并标记 is_new_download
        let (data, is_new_download) = if let Some(cached) = self.wcf_hydration_cache.get(&remote_uri) {
            tracing::debug!("WCF 水合缓存命中: {}", remote_uri);
            (cached.0.clone(), false)
        } else {
            tracing::info!("WCF 水合下载: {} ({}bytes)", remote_uri, remote_size);
            let config = self.snapshot_worker_config().await;

            let download_result = async {
                let urls = self.api.get_download_url(&[&remote_uri]).await;
                let urls = match urls {
                    Ok(u) => u,
                    Err(crate::errors::SyncError::Auth(_)) => {
                        tracing::info!("WCF 水合: token 过期，尝试刷新后重试");
                        self.api.refresh_access_token().await?;
                        self.api.get_download_url(&[&remote_uri]).await?
                    }
                    Err(e) => return Err(e),
                };
                let download_url = urls.into_iter().next()
                    .ok_or_else(|| crate::errors::SyncError::Network("获取下载 URL 返回空列表".into()))?;

                let data = crate::downloader::download_to_buffer(
                    &self.api,
                    &download_url,
                    config.bandwidth_limit,
                ).await?;

                Ok::<Vec<u8>, crate::errors::SyncError>(data)
            }.await;

            match download_result {
                Ok(data) => {
                    self.wcf_hydration_cache.insert(remote_uri.clone(), (data.clone(), std::time::Instant::now()));
                    (data, true)
                }
                Err(e) => {
                    tracing::error!("WCF 水合下载失败: {}: {}", remote_uri, e);
                    // 下载失败时记录一次统计
                    let now_str = chrono::Utc::now().to_rfc3339();
                    let task_id = format!("hydration_{}", uuid::Uuid::new_v4());
                    if let Err(db_err) = self.db.record_standalone_task_item(
                        &crate::models::WorkerTrigger::Hydration,
                        &crate::models::SyncTaskItem {
                            id: 0,
                            task_id,
                            relative_path: remote_uri.clone(),
                            action_type: crate::models::TaskActionType::Hydration,
                            status: crate::models::TaskItemStatus::Failed,
                            file_size: remote_size,
                            error_message: Some(e.to_string()),
                            created_at: now_str.clone(),
                            updated_at: now_str,
                        },
                    ).await {
                        tracing::warn!("WCF 水合失败统计记录失败: {}", db_err);
                    }
                    let _ = crate::platform::wcf::WcfPlatformAdapter::reject_fetch_data(
                        request.connection_key, request.transfer_key,
                    );
                    return;
                }
            }
        };

        // 计算实际需要传输的范围
        let offset = request.required_offset.max(0) as usize;
        let end = if request.required_length < 0 {
            data.len()
        } else {
            (offset + request.required_length as usize).min(data.len())
        };

        let transfer_data = if offset < data.len() && offset < end {
            &data[offset..end]
        } else {
            &data[..]
        };

        match crate::platform::wcf::WcfPlatformAdapter::fulfill_fetch_data(
            request.connection_key,
            request.transfer_key,
            transfer_data,
            offset as i64,
        ) {
            Ok(_) => {
                tracing::debug!("WCF 水合数据推送: {} offset={} len={}", remote_uri, offset, transfer_data.len());

                // 仅在首次下载（cache miss）时更新映射和记录统计，避免同一文件多次 range 请求重复计数
                if is_new_download {
                    if let Ok(Some(mapping)) = self.db.find_mapping_by_remote_uri(&root_id, &remote_uri).await {
                        self.suppress_paths.insert(mapping.local_path.to_string_lossy().into_owned(), std::time::Instant::now());
                        let _ = self.db.upsert_file_mapping(&FileMapping {
                            id: mapping.id,
                            sync_root_id: mapping.sync_root_id,
                            local_path: mapping.local_path.clone(),
                            remote_uri: mapping.remote_uri.clone(),
                            remote_file_id: mapping.remote_file_id.clone(),
                            local_hash: None,
                            remote_hash: if remote_hash.is_empty() { mapping.remote_hash.clone() } else { Some(remote_hash.clone()) },
                            local_mtime: mapping.local_mtime,
                            remote_mtime: mapping.remote_mtime,
                            local_size: mapping.local_size,
                            remote_size: Some(remote_size),
                            sync_status: SyncFileStatus::Synced,
                            is_placeholder: false,
                        }).await;

                        // 记录水合操作到统计
                        let now_str = chrono::Utc::now().to_rfc3339();
                        let local_path_str = mapping.local_path.to_string_lossy().to_string();
                        let task_id = format!("hydration_{}", uuid::Uuid::new_v4());
                        if let Err(e) = self.db.record_standalone_task_item(
                            &crate::models::WorkerTrigger::Hydration,
                            &crate::models::SyncTaskItem {
                                id: 0,
                                task_id,
                                relative_path: local_path_str,
                                action_type: crate::models::TaskActionType::Hydration,
                                status: crate::models::TaskItemStatus::Completed,
                                file_size: remote_size,
                                error_message: None,
                                created_at: now_str.clone(),
                                updated_at: now_str,
                            },
                        ).await {
                            tracing::warn!("WCF 水合统计记录失败: {}", e);
                        }
                    }
                }
            }
            Err(e) => {
                tracing::error!("WCF CfExecute 传输数据失败: {}: {}", remote_uri, e);
            }
        }
    }

    /// MirrorWcf: 为远程文件创建占位符（持续同步时远程新建/修改文件调用）
    pub(crate) async fn _create_placeholder_for_remote(
        &self,
        relative: &str,
        remote: &RemoteFileEntry,
        local_root: &std::path::Path,
        root_id: &str,
    ) {
        let local_path = local_root.join(relative);

        if let Some(parent) = local_path.parent() {
            let _ = tokio::fs::create_dir_all(parent).await;
        }

        if remote.is_dir {
            let _ = tokio::fs::create_dir_all(&local_path).await;
        } else {
            #[cfg(feature = "windows-cfapi")]
            {
                if let Some(adapter) = lock_recover(&self.platform_adapter).as_ref() {
                    match adapter.create_placeholder_for_remote(
                        local_path.parent().unwrap_or(local_root),
                        local_path.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default().as_str(),
                        remote.size,
                        &remote.uri,
                        remote.hash.as_deref(),
                        remote.mtime_ms,
                    ) {
                        Ok(_) => tracing::info!("[WCF] 创建占位符: {}", relative),
                        Err(e) => tracing::warn!("[WCF] 创建占位符失败 {}: {}", relative, e),
                    }
                }
            }

            let _ = self.db.upsert_file_mapping(&FileMapping {
                id: 0,
                sync_root_id: root_id.to_string(),
                local_path: std::path::PathBuf::from(relative),
                remote_uri: remote.uri.clone(),
                remote_file_id: remote.file_id.clone(),
                local_hash: None,
                remote_hash: remote.hash.clone(),
                local_mtime: None,
                remote_mtime: Some(remote.mtime_ms),
                local_size: None,
                remote_size: Some(remote.size),
                sync_status: SyncFileStatus::Placeholder,
                is_placeholder: true,
            }).await;
        }
    }

    /// WCF 清理（同步，可安全在 exit 前调用）
    pub(crate) fn cleanup_wcf(&self) {
        let adapter_opt = lock_recover(&self.platform_adapter).take();
        if let Some(adapter) = adapter_opt {
            if let Err(e) = adapter.disconnect() {
                tracing::warn!("WCF 断开连接失败: {}", e);
            }

            let local_root = lock_recover(&self.cached_local_root).clone();
            if !local_root.as_os_str().is_empty() {
                unsafe {
                    use std::os::windows::ffi::OsStrExt;
                    let path_w: Vec<u16> = std::ffi::OsStr::new(&local_root)
                        .encode_wide()
                        .chain(std::iter::once(0))
                        .collect();
                    let _ = windows::Win32::Storage::CloudFilters::CfUnregisterSyncRoot(
                        windows::core::PCWSTR(path_w.as_ptr()),
                    );
                }
                tracing::info!("WCF sync root 已注销: {}", local_root.display());
            }

            let root_id = self.sync_root_id.clone().unwrap_or_default();
            if let Ok(mappings) = self.list_placeholders_sync(&root_id) {
                for mapping in &mappings {
                    let local_path = local_root.join(&mapping.local_path);
                    if local_path.exists() {
                        let _ = std::fs::remove_file(&local_path);
                    }
                }
                if !mappings.is_empty() {
                    tracing::info!("已清理 {} 个占位符文件", mappings.len());
                }
            }
        }
    }

    /// 同步查询占位符映射（避免 await，可在 exit 前安全调用）
    fn list_placeholders_sync(&self, sync_root_id: &str) -> anyhow::Result<Vec<FileMapping>> {
        let pool = self.db.read_pool();
        let conn = pool.get().map_err(|e| anyhow::anyhow!("{}", e))?;
        let mut stmt = conn.prepare(
            "SELECT id, sync_root_id, local_path, remote_uri, remote_file_id,
                    local_hash, remote_hash, local_mtime, remote_mtime,
                    local_size, remote_size, sync_status, is_placeholder
             FROM file_mapping WHERE sync_root_id = ?1 AND is_placeholder = 1",
        ).map_err(|e| anyhow::anyhow!("{}", e))?;

        let mappings = stmt.query_map(rusqlite::params![sync_root_id], |row| {
            Ok(FileMapping {
                id: row.get(0)?,
                sync_root_id: row.get(1)?,
                local_path: std::path::PathBuf::from(row.get::<_, String>(2)?),
                remote_uri: row.get(3)?,
                remote_file_id: row.get(4)?,
                local_hash: row.get(5)?,
                remote_hash: row.get(6)?,
                local_mtime: row.get(7)?,
                remote_mtime: row.get(8)?,
                local_size: row.get(9)?,
                remote_size: row.get(10)?,
                sync_status: crate::sync_db::parse_sync_status(&row.get::<_, String>(11)?),
                is_placeholder: row.get::<_, i32>(12)? != 0,
            })
        }).map_err(|e| anyhow::anyhow!("{}", e))?
        .filter_map(|m| m.ok()).collect();

        Ok(mappings)
    }
}
