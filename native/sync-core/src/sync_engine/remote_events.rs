use crate::models::*;
#[cfg(feature = "linux-fuse")]
use crate::utils::lock_recover;

use super::SyncEngine;

impl SyncEngine {
    /// 处理远程事件
    pub(crate) async fn handle_remote_event(
        &self,
        event: RemoteFileEvent,
        local_root: &std::path::Path,
        remote_root: &str,
    ) {
        // UploadOnly: 忽略所有远程事件
        // AlbumDownload: 忽略删除事件（不删本地照片）
        let sync_mode = {
            let config = self.config.read().await;
            config.sync_mode.clone()
        };
        if matches!(sync_mode, SyncMode::UploadOnly) {
            return;
        }

        let is_mirror_wcf = matches!(sync_mode, SyncMode::MirrorWcf);
        let root_id = self.sync_root_id.clone().unwrap_or_default();

        match &event {
            RemoteFileEvent::Created(remote) | RemoteFileEvent::Modified(remote) => {
                let relative = crate::diff::remote_relative_path(
                    remote_root,
                    &remote.path,
                    &remote.name,
                    remote.is_dir,
                );
                tracing::info!("[远程事件] {}/{:?}: {}", event_type_name(&event), remote.file_id, relative);

                let remote_entry = if remote.size == 0 && !remote.is_dir {
                    match self.api.get_file_info(&remote.uri).await {
                        Ok(info) => {
                            tracing::debug!("[远程事件] 获取文件详情成功: {} ({}bytes)", relative, info.size);
                            info
                        }
                        Err(e) => {
                            tracing::warn!("[远程事件] 获取文件详情失败: {}: {}", relative, e);
                            remote.clone()
                        }
                    }
                } else {
                    remote.clone()
                };

                let now = std::time::Instant::now();
                self.suppress_paths.insert(relative.clone(), now);
                if let Some(parent) = std::path::PathBuf::from(&relative).parent() {
                    let parent_rel = crate::utils::normalize_path(&parent.to_string_lossy());
                    if !parent_rel.is_empty() {
                        self.suppress_paths.insert(parent_rel, now);
                    }
                }

                if is_mirror_wcf {
                    self._create_placeholder_for_remote(
                        &relative, &remote_entry, local_root, &root_id,
                    ).await;
                    self._record_wcf_stats(&relative, TaskActionType::CreatePlaceholder, remote_entry.size, None).await;
                } else {
                    let plan = SyncPlan {
                        downloads: vec![SyncAction {
                            relative_path: relative,
                            local_entry: None,
                            remote_entry: Some(remote_entry),
                            db_mapping: None,
                        }],
                        ..Default::default()
                    };
                    let worker_config = self.snapshot_worker_config().await;
                    let conflict_resolver = self.conflict.read().await.clone();
                    self.worker_pool.submit_background(
                        plan, worker_config, WorkerTrigger::Continuous, conflict_resolver,
                    ).await;
                }
            }
            RemoteFileEvent::Deleted { uri, name } => {
                // 清理过期抑制条目
                let now = std::time::Instant::now();
                self.suppress_paths.retain(|_, ts| now.duration_since(*ts).as_secs() < 30);

                let relative = crate::diff::remote_relative_path(
                    remote_root,
                    uri,
                    name,
                    false,
                );
                tracing::info!("[远程事件] 删除: {}", relative);

                // AlbumDownload: 远程删除不删除本地文件，仅清理 DB 映射
                if matches!(sync_mode, SyncMode::AlbumDownload) {
                    tracing::info!("[远程事件] AlbumDownload 模式，跳过本地删除: {}", relative);
                    let _ = self.db.delete_file_mapping(&root_id, &relative).await;
                    return;
                }

                // MirrorFUSE: 始终清理 inode + DB（不检查 suppress）
                // 远程删除必须反映到本地，suppress 只用于 create/modify 回弹
                // 即使是 FUSE unlink 的 SSE 回弹，重复 remove_inode/delete 也是 no-op 无害
                #[cfg(feature = "linux-fuse")]
                if is_mirror_wcf {
                    self.suppress_paths.remove(&relative); // consume 如果存在
                    {
                        let adapter = lock_recover(&self.fuse_adapter);
                        if let Some(ref fuse) = *adapter {
                            fuse.remove_inode(&relative);
                        }
                    }
                    let _ = self.db.delete_file_mapping(&root_id, &relative).await;
                    self._record_wcf_stats(&relative, TaskActionType::DeleteLocal, 0, None).await;
                    return;
                }

                // 被抑制的路径：上传失败清理远端碎片等场景，不应删除本地文件
                if self.suppress_paths.contains_key(&relative) {
                    tracing::info!("[远程事件] 删除已抑制，跳过本地删除: {}", relative);
                    self.suppress_paths.remove(&relative);
                    return;
                }

                let local_path = local_root.join(&relative);
                let existed = local_path.exists();
                if existed {
                    if local_path.is_dir() {
                        let _ = tokio::fs::remove_dir_all(&local_path).await;
                    } else {
                        let _ = tokio::fs::remove_file(&local_path).await;
                    }
                    tracing::info!("[远程事件] 已删除本地文件: {}", relative);
                }
                let _ = self.db.delete_file_mapping(&root_id, &relative).await;
                self.suppress_paths.insert(relative.clone(), std::time::Instant::now());

                // MirrorWcf: 远程删除 → 删本地，记录统计
                if is_mirror_wcf && existed {
                    self._record_wcf_stats(&relative, TaskActionType::DeleteLocal, 0, None).await;
                }
            }
            RemoteFileEvent::Renamed { old_uri, new_entry } => {
                let old_relative = crate::diff::remote_relative_path(
                    remote_root,
                    old_uri,
                    &new_entry.name,
                    false,
                );
                let new_relative = crate::diff::remote_relative_path(
                    remote_root,
                    &new_entry.path,
                    &new_entry.name,
                    new_entry.is_dir,
                );
                tracing::info!("[远程事件] 重命名: {} -> {}", old_relative, new_relative);

                let now = std::time::Instant::now();
                self.suppress_paths.insert(old_relative.clone(), now);
                self.suppress_paths.insert(new_relative.clone(), now);

                // MirrorFUSE: 直接更新 InodeStore + DB，不走 Worker（避免触发 FUSE rename 二次操作）
                #[cfg(feature = "linux-fuse")]
                if is_mirror_wcf {
                    {
                        let adapter = lock_recover(&self.fuse_adapter);
                        if let Some(ref fuse) = *adapter {
                            fuse.handle_remote_rename(&old_relative, &new_relative, &new_entry.uri);
                        }
                    }
                    // 同时更新 local_path 和 remote_uri（与 Worker 的 update_file_mapping_path 一致）
                    let _ = self.db.update_file_mapping_path(&root_id, &old_relative, &new_relative, &new_entry.uri).await;
                    self._record_wcf_stats(
                        &format!("{} -> {}", old_relative, new_relative),
                        TaskActionType::Rename, 0, None,
                    ).await;
                    return;
                }

                let old_local_path = local_root.join(&old_relative);

                if old_local_path.exists() {
                    let plan = SyncPlan {
                        rename_local: vec![LocalRenameAction {
                            old_relative_path: old_relative,
                            new_relative_path: new_relative,
                            new_remote_uri: new_entry.uri.clone(),
                        }],
                        ..Default::default()
                    };
                    let worker_config = self.snapshot_worker_config().await;
                    let conflict_resolver = self.conflict.read().await.clone();
                    self.worker_pool.submit_background(
                        plan, worker_config, WorkerTrigger::Continuous, conflict_resolver,
                    ).await;
                } else if is_mirror_wcf {
                    let remote_entry = self.get_remote_entry_or_fallback(new_entry).await;
                    self._create_placeholder_for_remote(
                        &new_relative, &remote_entry, local_root, &root_id,
                    ).await;
                    self._record_wcf_stats(
                        &format!("{} -> {}", old_relative, new_relative),
                        TaskActionType::Rename, 0, None,
                    ).await;
                } else {
                    let remote_entry = self.get_remote_entry_or_fallback(new_entry).await;
                    let plan = SyncPlan {
                        downloads: vec![SyncAction {
                            relative_path: new_relative,
                            local_entry: None,
                            remote_entry: Some(remote_entry),
                            db_mapping: None,
                        }],
                        ..Default::default()
                    };
                    let worker_config = self.snapshot_worker_config().await;
                    let conflict_resolver = self.conflict.read().await.clone();
                    self.worker_pool.submit_background(
                        plan, worker_config, WorkerTrigger::Continuous, conflict_resolver,
                    ).await;
                }
            }
            RemoteFileEvent::Moved { old_uri, new_entry } => {
                let old_relative = crate::diff::remote_relative_path(
                    remote_root,
                    old_uri,
                    &new_entry.name,
                    false,
                );
                let new_relative = crate::diff::remote_relative_path(
                    remote_root,
                    &new_entry.path,
                    &new_entry.name,
                    new_entry.is_dir,
                );
                tracing::info!("[远程事件] 移动: {} -> {}", old_relative, new_relative);

                let now = std::time::Instant::now();
                self.suppress_paths.insert(old_relative.clone(), now);
                self.suppress_paths.insert(new_relative.clone(), now);

                // MirrorFUSE: 直接更新 InodeStore + DB，不走 Worker
                #[cfg(feature = "linux-fuse")]
                if is_mirror_wcf {
                    {
                        let adapter = lock_recover(&self.fuse_adapter);
                        if let Some(ref fuse) = *adapter {
                            fuse.handle_remote_rename(&old_relative, &new_relative, &new_entry.uri);
                        }
                    }
                    // 同时更新 local_path 和 remote_uri
                    let _ = self.db.update_file_mapping_path(&root_id, &old_relative, &new_relative, &new_entry.uri).await;
                    self._record_wcf_stats(
                        &format!("{} -> {}", old_relative, new_relative),
                        TaskActionType::Move, 0, None,
                    ).await;
                    return;
                }

                let old_local_path = local_root.join(&old_relative);

                if old_local_path.exists() {
                    let plan = SyncPlan {
                        move_local: vec![LocalRenameAction {
                            old_relative_path: old_relative,
                            new_relative_path: new_relative,
                            new_remote_uri: new_entry.uri.clone(),
                        }],
                        ..Default::default()
                    };
                    let worker_config = self.snapshot_worker_config().await;
                    let conflict_resolver = self.conflict.read().await.clone();
                    self.worker_pool.submit_background(
                        plan, worker_config, WorkerTrigger::Continuous, conflict_resolver,
                    ).await;
                } else if is_mirror_wcf {
                    let remote_entry = self.get_remote_entry_or_fallback(new_entry).await;
                    self._create_placeholder_for_remote(
                        &new_relative, &remote_entry, local_root, &root_id,
                    ).await;
                    self._record_wcf_stats(
                        &format!("{} -> {}", old_relative, new_relative),
                        TaskActionType::Move, 0, None,
                    ).await;
                } else {
                    let remote_entry = self.get_remote_entry_or_fallback(new_entry).await;
                    let plan = SyncPlan {
                        downloads: vec![SyncAction {
                            relative_path: new_relative,
                            local_entry: None,
                            remote_entry: Some(remote_entry),
                            db_mapping: None,
                        }],
                        ..Default::default()
                    };
                    let worker_config = self.snapshot_worker_config().await;
                    let conflict_resolver = self.conflict.read().await.clone();
                    self.worker_pool.submit_background(
                        plan, worker_config, WorkerTrigger::Continuous, conflict_resolver,
                    ).await;
                }
            }
        }
    }

    /// 获取远程文件详情，失败则使用 SSE 数据回退
    pub(crate) async fn get_remote_entry_or_fallback(&self, entry: &RemoteFileEntry) -> RemoteFileEntry {
        if entry.size == 0 && !entry.is_dir {
            match self.api.get_file_info(&entry.uri).await {
                Ok(info) => info,
                Err(_) => entry.clone(),
            }
        } else {
            entry.clone()
        }
    }
}

fn event_type_name(event: &RemoteFileEvent) -> &'static str {
    match event {
        RemoteFileEvent::Created(_) => "create",
        RemoteFileEvent::Modified(_) => "modify",
        RemoteFileEvent::Deleted { .. } => "delete",
        RemoteFileEvent::Renamed { .. } => "rename",
        RemoteFileEvent::Moved { .. } => "move",
    }
}
