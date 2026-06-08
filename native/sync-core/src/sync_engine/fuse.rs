//! FUSE (Linux) 相关的 SyncEngine 方法
//! 仅在 linux-fuse feature 启用时编译

use crate::models::*;

use super::SyncEngine;

#[cfg(feature = "linux-fuse")]
impl SyncEngine {
    /// 处理 FUSE 请求（统一分发）
    pub(crate) async fn handle_fuse_request(
        &self,
        request: crate::platform::fuse::FuseRequest,
        local_root: &std::path::Path,
    ) {
        use crate::platform::fuse::FuseRequest;
        match request {
            FuseRequest::Read { inode, remote_uri, offset, length, reply_tx } => {
                self.handle_fuse_read(inode, &remote_uri, offset, length, reply_tx, local_root).await;
            }
            FuseRequest::Upload { inode, parent_ino, name, relative_path, data, tmp_path, mtime_ms, overwrite, reply_tx } => {
                self.handle_fuse_upload(inode, parent_ino, &name, &relative_path, data, tmp_path.as_deref(), mtime_ms, overwrite, reply_tx).await;
            }
            FuseRequest::Mkdir { inode, parent_ino, name, relative_path, reply_tx } => {
                self.handle_fuse_mkdir(inode, parent_ino, &name, &relative_path, reply_tx).await;
            }
            FuseRequest::Unlink { inode, name, is_dir, remote_uri, relative_path, reply_tx } => {
                self.handle_fuse_unlink(inode, &name, is_dir, &remote_uri, &relative_path, reply_tx).await;
            }
            FuseRequest::Rename { inode, old_name, old_relative_path, old_remote_uri, new_parent_ino, new_name, new_relative_path, reply_tx } => {
                self.handle_fuse_rename(inode, &old_name, &old_relative_path, &old_remote_uri, new_parent_ino, &new_name, &new_relative_path, reply_tx).await;
            }
        }
    }

    /// MirrorFUSE: 处理 FUSE read 水合请求（按需下载）
    pub(crate) async fn handle_fuse_read(
        &self,
        inode: u64,
        remote_uri: &str,
        offset: i64,
        length: i64,
        reply_tx: tokio::sync::oneshot::Sender<Result<Vec<u8>, String>>,
        _local_root: &std::path::Path,
    ) {
        tracing::trace!("FUSE 水合请求: ino={}, uri={}, offset={}, length={}", inode, remote_uri, offset, length);

        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = reply_tx.send(Err("sync_root_id 为空".to_string()));
                return;
            }
        };

        let remote_uri_owned = remote_uri.to_string();

        let now = std::time::Instant::now();
        self.hydration_cache.retain(|_, (_, ts)| now.duration_since(*ts).as_secs() < 300);

        let data = if let Some(cached) = self.hydration_cache.get(&remote_uri_owned) {
            tracing::trace!("FUSE 水合缓存命中: {}", remote_uri_owned);
            cached.0.clone()
        } else {
            tracing::info!("FUSE 水合下载: {}", remote_uri_owned);
            let config = self.snapshot_worker_config().await;

            let download_result = async {
                let urls = self.api.get_download_url(&[&remote_uri_owned]).await;
                let urls = match urls {
                    Ok(u) => u,
                    Err(crate::errors::SyncError::Auth(_)) => {
                        tracing::info!("FUSE 水合: token 过期，尝试刷新后重试");
                        self.api.refresh_access_token().await?;
                        self.api.get_download_url(&[&remote_uri_owned]).await?
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
                    tracing::info!("FUSE 水合下载完成: {} ({}bytes)", remote_uri_owned, data.len());
                    self.hydration_cache.insert(remote_uri_owned.clone(), (data.clone(), std::time::Instant::now()));
                    self._record_wcf_stats(&remote_uri_owned, TaskActionType::Hydration, data.len() as u64, None).await;
                    data
                }
                Err(e) => {
                    tracing::error!("FUSE 水合下载失败: {}: {}", remote_uri_owned, e);
                    let _ = reply_tx.send(Err(format!("下载失败: {}", e)));
                    return;
                }
            }
        };

        if let Ok(Some(mapping)) = self.db.find_mapping_by_remote_uri(&root_id, &remote_uri_owned).await {
            let _ = self.db.upsert_file_mapping(&FileMapping {
                id: mapping.id,
                sync_root_id: mapping.sync_root_id,
                local_path: mapping.local_path.clone(),
                remote_uri: mapping.remote_uri.clone(),
                remote_file_id: mapping.remote_file_id.clone(),
                local_hash: None,
                remote_hash: mapping.remote_hash.clone(),
                local_mtime: mapping.local_mtime,
                remote_mtime: mapping.remote_mtime,
                local_size: None,
                remote_size: Some(data.len() as u64),
                sync_status: SyncFileStatus::Synced,
                is_placeholder: false,
            }).await;
        }

        let _ = reply_tx.send(Ok(data));
    }

    /// FUSE 上传：将写入的文件上传到云端
    #[allow(clippy::too_many_arguments)]
    async fn handle_fuse_upload(
        &self,
        inode: u64,
        _parent_ino: u64,
        name: &str,
        relative_path: &str,
        data: Vec<u8>,
        tmp_path: Option<&str>,
        _mtime_ms: i64,
        overwrite: bool,
        reply_tx: tokio::sync::oneshot::Sender<Result<crate::platform::fuse::UploadResult, String>>,
    ) {
        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = reply_tx.send(Err("sync_root_id 为空".to_string()));
                return;
            }
        };

        let config = self.snapshot_worker_config().await;
        let remote_root = &config.remote_root;
        let file_uri = format!("{}/{}", remote_root, relative_path);

        tracing::info!("FUSE 上传: {} ({}bytes, overwrite={})", relative_path, data.len(), overwrite);

        // 确保远程父目录存在
        if let Some(parent) = std::path::PathBuf::from(relative_path).parent() {
            let parent_str = parent.to_string_lossy().to_string();
            if !parent_str.is_empty() {
                if let Err(e) = crate::uploader::ensure_remote_dirs("fuse", remote_root, &parent_str, &self.api, &self.ensured_dirs).await {
                    tracing::warn!("FUSE 上传: 确保远程父目录失败 {}: {}", parent_str, e);
                }
            }
        }

        // 读取文件数据
        let file_data = if !data.is_empty() {
            data
        } else if let Some(tmp) = tmp_path {
            match tokio::fs::read(tmp).await {
                Ok(d) => d,
                Err(e) => {
                    let _ = reply_tx.send(Err(format!("读取临时文件失败: {}", e)));
                    return;
                }
            }
        } else {
            Vec::new()
        };

        let file_size = file_data.len() as u64;

        // 创建上传会话
        let session = match crate::uploader::retry_upload_session(
            "fuse", &file_uri, file_size, 3, overwrite, None, None, None, &self.api,
        ).await {
            Ok(s) => s,
            Err(e) => {
                let _ = reply_tx.send(Err(format!("创建上传会话失败: {}", e)));
                return;
            }
        };

        let chunk_size = session.chunk_size as usize;

        // 逐块上传
        let mut offset = 0usize;
        let mut index: u32 = 0;
        while offset < file_data.len() {
            let end = (offset + chunk_size).min(file_data.len());
            let chunk = &file_data[offset..end];
            let mut chunk_retries = 0u32;
            loop {
                match self.api.upload_chunk(&session, index, chunk, file_size, "fuse").await {
                    Ok(_) => break,
                    Err(e) if chunk_retries < 3 => {
                        chunk_retries += 1;
                        tracing::warn!("FUSE 上传重试 ({}/{}): {}", chunk_retries, 3, e);
                        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                    }
                    Err(e) => {
                        let _ = reply_tx.send(Err(format!("上传分片失败: {}", e)));
                        return;
                    }
                }
            }
            offset = end;
            index += 1;
        }

        // 远程存储策略回调
        if session.is_remote_storage() {
            if let Err(e) = self.api.callback_upload_complete(&session, "fuse").await {
                tracing::warn!("FUSE 上传完成回调失败: {}", e);
            }
        }

        // 获取远程文件信息
        let (remote_file_id, remote_hash) = match self.api.get_file_info(&file_uri).await {
            Ok(info) => (info.file_id.clone(), info.hash.clone()),
            Err(e) => {
                tracing::warn!("FUSE 上传后获取文件信息失败: {}", e);
                (None, None)
            }
        };

        // 更新 DB mapping
        let _ = self.db.upsert_file_mapping(&FileMapping {
            id: 0,
            sync_root_id: root_id,
            local_path: std::path::PathBuf::from(relative_path),
            remote_uri: file_uri.clone(),
            remote_file_id,
            local_hash: None,
            remote_hash: remote_hash.clone(),
            local_mtime: Some(_mtime_ms),
            remote_mtime: Some(_mtime_ms),
            local_size: Some(file_size),
            remote_size: Some(file_size),
            sync_status: SyncFileStatus::Synced,
            is_placeholder: false,
        }).await;

        // 抑制 SSE 回弹
        self.suppress_paths.insert(relative_path.to_string(), std::time::Instant::now());

        // 记录统计
        self._record_wcf_stats(relative_path, TaskActionType::Upload, file_size, None).await;

        tracing::info!("FUSE 上传完成: {} → {} ({}bytes)", name, file_uri, file_size);

        let _ = reply_tx.send(Ok(crate::platform::fuse::UploadResult {
            remote_uri: file_uri,
            remote_hash,
            size: file_size,
        }));

        let _ = inode; // used for logging
    }

    /// FUSE 创建远程目录
    async fn handle_fuse_mkdir(
        &self,
        _inode: u64,
        _parent_ino: u64,
        name: &str,
        relative_path: &str,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    ) {
        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = reply_tx.send(Err("sync_root_id 为空".to_string()));
                return;
            }
        };

        let config = self.snapshot_worker_config().await;
        let parent_rel = std::path::PathBuf::from(relative_path)
            .parent()
            .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
            .unwrap_or_default();
        let parent_uri = if parent_rel.is_empty() {
            config.remote_root.clone()
        } else {
            format!("{}/{}", config.remote_root, parent_rel)
        };

        tracing::info!("FUSE 创建目录: {} (parent_uri={})", name, parent_uri);

        match self.api.create_directory(&parent_uri, name).await {
            Ok(remote_entry) => {
                let remote_uri = remote_entry.uri.clone();

                // 更新 InodeStore 中的 remote_uri（在 await 之前释放锁）
                {
                    let adapter = match self.fuse_adapter.lock() {
                        Ok(guard) => guard,
                        Err(e) => {
                            let _ = reply_tx.send(Err(format!("锁失败: {}", e)));
                            return;
                        }
                    };
                    if let Some(ref fuse) = *adapter {
                        fuse.inode_store().update_remote_uri(_inode, &remote_uri);
                    }
                }

                // 更新 DB mapping
                let _ = self.db.upsert_file_mapping(&FileMapping {
                    id: 0,
                    sync_root_id: root_id,
                    local_path: std::path::PathBuf::from(relative_path),
                    remote_uri: remote_uri.clone(),
                    remote_file_id: remote_entry.file_id.clone(),
                    local_hash: None,
                    remote_hash: remote_entry.hash.clone(),
                    local_mtime: None,
                    remote_mtime: Some(remote_entry.mtime_ms),
                    local_size: None,
                    remote_size: Some(0),
                    sync_status: SyncFileStatus::Synced,
                    is_placeholder: false,
                }).await;

                // 抑制 SSE 回弹
                self.suppress_paths.insert(relative_path.to_string(), std::time::Instant::now());

                // 记录统计
                self._record_wcf_stats(relative_path, TaskActionType::MkdirRemote, 0, None).await;

                tracing::info!("FUSE 目录创建成功: {} → {}", name, remote_uri);
                let _ = reply_tx.send(Ok(()));
            }
            Err(e) => {
                tracing::error!("FUSE 创建目录失败: {}: {}", name, e);
                let _ = reply_tx.send(Err(format!("创建目录失败: {}", e)));
            }
        }
    }

    /// FUSE 删除远程文件/目录
    async fn handle_fuse_unlink(
        &self,
        _inode: u64,
        name: &str,
        _is_dir: bool,
        remote_uri: &str,
        relative_path: &str,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    ) {
        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = reply_tx.send(Err("sync_root_id 为空".to_string()));
                return;
            }
        };

        tracing::info!("FUSE 删除: {} ({})", name, remote_uri);

        match self.api.delete_files(&[remote_uri]).await {
            Ok(()) => {
                // 释放水合缓存
                self.hydration_cache.remove(remote_uri);

                // 删除 DB mapping
                let _ = self.db.delete_mapping_by_remote_uri(&root_id, remote_uri).await;

                // 抑制 SSE 回弹
                self.suppress_paths.insert(relative_path.to_string(), std::time::Instant::now());

                // 记录统计
                self._record_wcf_stats(relative_path, TaskActionType::DeleteRemote, 0, None).await;

                tracing::info!("FUSE 删除成功: {}", name);
                let _ = reply_tx.send(Ok(()));
            }
            Err(e) => {
                tracing::error!("FUSE 删除失败: {}: {}", name, e);
                let _ = reply_tx.send(Err(format!("删除失败: {}", e)));
            }
        }
    }

    /// FUSE 重命名/移动
    #[allow(clippy::too_many_arguments)]
    async fn handle_fuse_rename(
        &self,
        _inode: u64,
        old_name: &str,
        old_relative_path: &str,
        old_remote_uri: &str,
        new_parent_ino: u64,
        new_name: &str,
        new_relative_path: &str,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    ) {
        let root_id = match &self.sync_root_id {
            Some(id) => id.clone(),
            None => {
                let _ = reply_tx.send(Err("sync_root_id 为空".to_string()));
                return;
            }
        };

        let config = self.snapshot_worker_config().await;
        let _ = (new_parent_ino, new_name);

        // 判断是同目录重命名还是跨目录移动
        let old_parent_rel = std::path::PathBuf::from(old_relative_path)
            .parent()
            .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
            .unwrap_or_default();
        let new_parent_rel = std::path::PathBuf::from(new_relative_path)
            .parent()
            .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
            .unwrap_or_default();

        let result = if old_parent_rel == new_parent_rel {
            // 同目录重命名
            tracing::info!("FUSE 重命名: {} → {}", old_name, new_name);
            self.api.rename_file(old_remote_uri, new_name).await
        } else {
            // 跨目录移动
            let dst_uri = if new_parent_rel.is_empty() {
                config.remote_root.clone()
            } else {
                format!("{}/{}", config.remote_root, new_parent_rel)
            };
            tracing::info!("FUSE 移动: {} → {}", old_remote_uri, dst_uri);
            self.api.move_files(&[old_remote_uri], &dst_uri, false).await
        };

        match result {
            Ok(()) => {
                let new_remote_uri = format!("{}/{}", config.remote_root, new_relative_path);

                // 更新 InodeStore 中的 remote_uri（在 await 之前释放锁）
                {
                    let adapter = match self.fuse_adapter.lock() {
                        Ok(guard) => guard,
                        Err(e) => {
                            let _ = reply_tx.send(Err(format!("锁失败: {}", e)));
                            return;
                        }
                    };
                    if let Some(ref fuse) = *adapter {
                        fuse.inode_store().update_remote_uri(_inode, &new_remote_uri);
                    }
                }

                // 清理旧 URI 的水合缓存
                self.hydration_cache.remove(old_remote_uri);

                // 更新 DB mapping
                let _ = self.db.update_mapping_remote_uri(&root_id, old_remote_uri, &new_remote_uri).await;

                // 抑制 SSE 回弹
                self.suppress_paths.insert(old_relative_path.to_string(), std::time::Instant::now());
                self.suppress_paths.insert(new_relative_path.to_string(), std::time::Instant::now());

                // 记录统计
                let action = if old_parent_rel == new_parent_rel {
                    TaskActionType::Rename
                } else {
                    TaskActionType::Move
                };
                self._record_wcf_stats(
                    &format!("{} -> {}", old_relative_path, new_relative_path),
                    action, 0, None,
                ).await;

                tracing::info!("FUSE 重命名/移动成功: {} → {}", old_relative_path, new_relative_path);
                let _ = reply_tx.send(Ok(()));
            }
            Err(e) => {
                tracing::error!("FUSE 重命名/移动失败: {}: {}", old_name, e);
                let _ = reply_tx.send(Err(format!("重命名/移动失败: {}", e)));
            }
        }
    }

    /// MirrorFUSE: 为远程文件注册 FUSE inode（持续同步时远程新建/修改文件调用）
    pub(crate) async fn _create_placeholder_for_remote(
        &self,
        relative: &str,
        remote: &RemoteFileEntry,
        _local_root: &std::path::Path,
        _root_id: &str,
    ) {
        let adapter = match self.fuse_adapter.lock() {
            Ok(guard) => guard,
            Err(e) => {
                tracing::error!("FUSE adapter lock 失败: {}", e);
                return;
            }
        };
        if let Some(ref fuse) = *adapter {
            let parent_rel = std::path::PathBuf::from(relative)
                .parent()
                .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
                .unwrap_or_default();

            let name = std::path::PathBuf::from(relative)
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_default();

            fuse.create_placeholder_for_remote(
                &parent_rel,
                &name,
                relative,
                remote.is_dir,
                remote.size,
                &remote.uri,
                remote.hash.as_deref(),
                remote.mtime_ms,
            );
        }
    }

    /// FUSE 清理（卸载挂载点）
    pub(crate) fn cleanup_fuse(&self) {
        let adapter_opt = match self.fuse_adapter.lock() {
            Ok(mut guard) => guard.take(),
            Err(e) => {
                tracing::error!("FUSE adapter lock 失败: {}", e);
                return;
            }
        };
        if let Some(adapter) = adapter_opt {
            if let Err(e) = adapter.unmount() {
                tracing::warn!("FUSE 卸载失败: {}", e);
            }
            tracing::info!("FUSE 适配器已清理");
        }
    }
}
