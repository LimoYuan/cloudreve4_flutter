use crate::models::*;
use std::path::Path;

use super::SyncEngine;

impl SyncEngine {
    /// 处理本地事件批次
    pub(crate) async fn handle_local_events(
        &self,
        all_events: Vec<LocalFileEvent>,
        local_root: &std::path::Path,
        debounce: &mut crate::event_handler::EventDebouncer,
    ) {
        // DownloadOnly: 忽略所有本地事件
        let (sync_mode, wcf_delete_mode) = {
            let config = self.config.read().await;
            (config.sync_mode.clone(), config.wcf_delete_mode.clone())
        };
        if matches!(sync_mode, SyncMode::DownloadOnly) {
            return;
        }

        let root_id = self.sync_root_id.clone().unwrap_or_default();

        // 清理过期的 suppress 记录（超过 30 秒）
        let now = std::time::Instant::now();
        self.suppress_paths
            .retain(|_, ts| now.duration_since(*ts).as_secs() < 30);

        // === 第一步：提取 Renamed/Moved 事件，查 DB 构建操作 ===
        let mut rename_remote: Vec<RenameAction> = Vec::new();
        let mut move_remote: Vec<MoveAction> = Vec::new();
        let mut handled_old_rels: std::collections::HashSet<String> =
            std::collections::HashSet::new();
        let mut handled_new_rels: std::collections::HashSet<String> =
            std::collections::HashSet::new();

        for event in &all_events {
            match event {
                LocalFileEvent::Renamed {
                    old_paths,
                    new_paths,
                } => {
                    for (old_path, new_path) in old_paths.iter().zip(new_paths.iter()) {
                        if let Some((old_rel, new_rel)) = rel_pair(local_root, old_path, new_path) {
                            if self.suppress_paths.contains_key(&old_rel)
                                || self.suppress_paths.contains_key(&new_rel)
                            {
                                tracing::trace!(
                                    "本地重命名被抑制(远程操作导致): {} -> {}",
                                    old_rel,
                                    new_rel
                                );
                                continue;
                            }
                            let new_name = new_path
                                .file_name()
                                .map(|n| n.to_string_lossy().to_string())
                                .unwrap_or_default();

                            // Android 回收站：.trashed- 前缀视为本地删除，不重命名远程
                            if new_name.starts_with(".trashed-") {
                                if let Ok(Some(_)) =
                                    self.db.get_file_mapping(&root_id, &old_rel).await
                                {
                                    tracing::info!(
                                        "检测到本地回收站重命名，视为删除: {} -> {}",
                                        old_rel,
                                        new_rel
                                    );
                                    let _ = self.db.delete_file_mapping(&root_id, &old_rel).await;
                                    handled_old_rels.insert(old_rel);
                                    handled_new_rels.insert(new_rel);
                                }
                                continue;
                            }

                            if let Ok(Some(mapping)) =
                                self.db.get_file_mapping(&root_id, &old_rel).await
                            {
                                tracing::info!("检测到本地重命名: {} -> {}", old_rel, new_rel);
                                rename_remote.push(RenameAction {
                                    old_relative_path: old_rel.clone(),
                                    new_relative_path: new_rel.clone(),
                                    remote_uri: mapping.remote_uri.clone(),
                                    new_name,
                                });
                                handled_old_rels.insert(old_rel);
                                handled_new_rels.insert(new_rel);
                            } else {
                                tracing::info!(
                                    "本地重命名但旧路径无DB映射，按新建处理: {} -> {}",
                                    old_rel,
                                    new_rel
                                );
                            }
                        }
                    }
                }
                LocalFileEvent::Moved {
                    old_paths,
                    new_paths,
                } => {
                    for (old_path, new_path) in old_paths.iter().zip(new_paths.iter()) {
                        if let Some((old_rel, new_rel)) = rel_pair(local_root, old_path, new_path) {
                            if self.suppress_paths.contains_key(&old_rel)
                                || self.suppress_paths.contains_key(&new_rel)
                            {
                                tracing::trace!(
                                    "本地移动被抑制(远程操作导致): {} -> {}",
                                    old_rel,
                                    new_rel
                                );
                                continue;
                            }
                            let new_name = new_path
                                .file_name()
                                .map(|n| n.to_string_lossy().to_string())
                                .unwrap_or_default();

                            // Android 回收站：移动到 .trashed- 前缀文件，视为本地删除
                            if new_name.starts_with(".trashed-") {
                                if let Ok(Some(_)) =
                                    self.db.get_file_mapping(&root_id, &old_rel).await
                                {
                                    tracing::info!(
                                        "检测到本地回收站移动，视为删除: {} -> {}",
                                        old_rel,
                                        new_rel
                                    );
                                    let _ = self.db.delete_file_mapping(&root_id, &old_rel).await;
                                    handled_old_rels.insert(old_rel);
                                    handled_new_rels.insert(new_rel);
                                }
                                continue;
                            }

                            if let Ok(Some(mapping)) =
                                self.db.get_file_mapping(&root_id, &old_rel).await
                            {
                                let remote_root = { self.config.read().await.remote_root.clone() };
                                let new_rel_path = std::path::PathBuf::from(&new_rel);
                                let dst_dir_rel = new_rel_path
                                    .parent()
                                    .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
                                    .unwrap_or_default();
                                let dst_remote_dir_uri = format!(
                                    "{}/{}",
                                    remote_root.trim_end_matches('/'),
                                    dst_dir_rel.trim_start_matches('/')
                                );

                                tracing::info!("检测到本地移动: {} -> {}", old_rel, new_rel);
                                move_remote.push(MoveAction {
                                    old_relative_path: old_rel.clone(),
                                    new_relative_path: new_rel.clone(),
                                    remote_uri: mapping.remote_uri.clone(),
                                    dst_remote_dir_uri,
                                });
                                handled_old_rels.insert(old_rel);
                                handled_new_rels.insert(new_rel);
                            } else {
                                tracing::info!(
                                    "本地移动但旧路径无DB映射，按新建处理: {} -> {}",
                                    old_rel,
                                    new_rel
                                );
                            }
                        }
                    }
                }
                _ => {}
            }
        }

        // === 第二步：按事件类型分类路径，跳过已识别为 rename/move 的路径 ===
        let mut create_paths: std::collections::BTreeMap<String, std::path::PathBuf> =
            std::collections::BTreeMap::new();
        let mut delete_paths: std::collections::BTreeSet<String> =
            std::collections::BTreeSet::new();

        for event in &all_events {
            for path in event.paths() {
                if !debounce.should_process(path) {
                    continue;
                }

                let file_name = path
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_default();
                if crate::fs_scanner::SKIP_NAMES
                    .iter()
                    .any(|s| file_name == *s)
                    || file_name.starts_with(".sync_")
                    || file_name.starts_with(".trashed-")
                    || crate::utils::is_conflict_file(&file_name)
                {
                    continue;
                }

                let relative = path
                    .strip_prefix(local_root)
                    .unwrap_or(path)
                    .to_string_lossy()
                    .to_string();
                let relative = crate::utils::normalize_path(&relative);

                if handled_old_rels.contains(&relative)
                    || handled_new_rels.contains(&relative)
                    || self.suppress_paths.contains_key(&relative)
                {
                    continue;
                }

                match event {
                    LocalFileEvent::Created(_) | LocalFileEvent::Modified(_) => {
                        delete_paths.remove(relative.as_str());
                        create_paths.insert(relative, path.clone());
                    }
                    LocalFileEvent::Deleted(_) => {
                        if crate::utils::is_conflict_file(&relative) {
                            continue;
                        }
                        create_paths.remove(relative.as_str());
                        delete_paths.insert(relative);
                    }
                    LocalFileEvent::Renamed { .. } | LocalFileEvent::Moved { .. } => {}
                }
            }
        }
        debounce.cleanup();

        // === hash 匹配回退：检测 delete+create 为 rename 的情况 ===
        // MirrorWcf: 跳过 hash 匹配回退，因为读取占位符文件会被 CFApi 拦截导致 426 超时
        if !delete_paths.is_empty()
            && !create_paths.is_empty()
            && !matches!(sync_mode, SyncMode::MirrorWcf)
        {
            let mut matched_deletes: std::collections::HashSet<String> =
                std::collections::HashSet::new();
            let mut matched_creates: std::collections::HashSet<String> =
                std::collections::HashSet::new();

            for (new_rel, new_path) in &create_paths {
                if let Ok(metadata) = tokio::fs::metadata(new_path).await {
                    if metadata.is_dir() || metadata.len() == 0 {
                        continue;
                    }
                    let new_hash = crate::utils::quick_hash(new_path, metadata.len())
                        .await
                        .unwrap_or_default();
                    if new_hash.is_empty() {
                        continue;
                    }

                    for del_rel in &delete_paths {
                        if matched_deletes.contains(del_rel.as_str()) {
                            continue;
                        }
                        if let Ok(Some(mapping)) = self.db.get_file_mapping(&root_id, del_rel).await
                        {
                            if mapping.local_hash.as_deref() == Some(&new_hash) {
                                let new_name = new_path
                                    .file_name()
                                    .map(|n| n.to_string_lossy().to_string())
                                    .unwrap_or_default();

                                let old_dir = std::path::PathBuf::from(del_rel)
                                    .parent()
                                    .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
                                    .unwrap_or_default();
                                let new_dir = std::path::PathBuf::from(new_rel.as_str())
                                    .parent()
                                    .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
                                    .unwrap_or_default();

                                if old_dir == new_dir {
                                    tracing::info!(
                                        "hash匹配检测到重命名: {} -> {}",
                                        del_rel,
                                        new_rel
                                    );
                                    rename_remote.push(RenameAction {
                                        old_relative_path: del_rel.clone(),
                                        new_relative_path: new_rel.clone(),
                                        remote_uri: mapping.remote_uri.clone(),
                                        new_name,
                                    });
                                } else {
                                    let remote_root =
                                        { self.config.read().await.remote_root.clone() };
                                    let dst_remote_dir_uri = format!(
                                        "{}/{}",
                                        remote_root.trim_end_matches('/'),
                                        new_dir.trim_start_matches('/')
                                    );
                                    tracing::info!(
                                        "hash匹配检测到移动: {} -> {}",
                                        del_rel,
                                        new_rel
                                    );
                                    move_remote.push(MoveAction {
                                        old_relative_path: del_rel.clone(),
                                        new_relative_path: new_rel.clone(),
                                        remote_uri: mapping.remote_uri.clone(),
                                        dst_remote_dir_uri,
                                    });
                                }
                                matched_deletes.insert(del_rel.clone());
                                matched_creates.insert(new_rel.clone());
                                break;
                            }
                        }
                    }
                }
            }

            create_paths.retain(|rel, _| !matched_creates.contains(rel.as_str()));
            delete_paths.retain(|rel| !matched_deletes.contains(rel.as_str()));
        }

        // === 提交重命名任务 ===
        if !rename_remote.is_empty() {
            let plan = SyncPlan {
                rename_remote,
                ..Default::default()
            };
            let worker_config = self.snapshot_worker_config().await;
            let conflict_resolver = self.conflict.read().await.clone();
            self.worker_pool
                .submit_background(
                    plan,
                    worker_config,
                    WorkerTrigger::Continuous,
                    conflict_resolver,
                )
                .await;
        }

        // === 提交移动任务 ===
        if !move_remote.is_empty() {
            let plan = SyncPlan {
                move_remote,
                ..Default::default()
            };
            let worker_config = self.snapshot_worker_config().await;
            let conflict_resolver = self.conflict.read().await.clone();
            self.worker_pool
                .submit_background(
                    plan,
                    worker_config,
                    WorkerTrigger::Continuous,
                    conflict_resolver,
                )
                .await;
        }

        // === 提交上传任务 (Create/Modify) ===
        if !create_paths.is_empty() {
            let mut uploads = Vec::new();
            let mut dir_paths: Vec<String> = Vec::new();
            let mut skipped_unstable = 0usize;
            let mut skipped_uploading = 0usize;

            for (relative, path) in &create_paths {
                if let Ok(metadata) = tokio::fs::metadata(path).await {
                    if !metadata.is_dir() && metadata.len() == 0 {
                        continue;
                    }

                    if metadata.is_dir() {
                        dir_paths.push(relative.clone());
                        continue;
                    }

                    if self.worker_pool.is_uploading(relative) {
                        skipped_uploading += 1;
                        tracing::debug!("文件正在上传中，跳过: {}", relative);
                        continue;
                    }

                    if !is_file_stable(path).await {
                        skipped_unstable += 1;
                        tracing::debug!("文件尚未稳定（可能正在写入），跳过: {}", relative);
                        continue;
                    }

                    let size = metadata.len();
                    // MirrorWcf: 跳过 quick_hash，因为读取占位符文件会被 CFApi 拦截导致 426 超时
                    let quick_hash = if matches!(sync_mode, SyncMode::MirrorWcf) {
                        String::new()
                    } else {
                        crate::utils::quick_hash(path, size)
                            .await
                            .unwrap_or_default()
                    };

                    let db_mapping = self
                        .db
                        .get_file_mapping(&root_id, relative)
                        .await
                        .ok()
                        .flatten();
                    if let Some(ref mapping) = db_mapping {
                        if !quick_hash.is_empty()
                            && mapping.local_hash.as_deref() == Some(&quick_hash)
                        {
                            continue;
                        }
                        if mapping.is_placeholder {
                            continue;
                        }
                    }

                    let mtime_ms = metadata
                        .modified()
                        .ok()
                        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                        .map(|d| d.as_millis() as i64)
                        .unwrap_or(0);
                    let mime_type = crate::fs_scanner::guess_mime_type(path);

                    uploads.push(SyncAction {
                        relative_path: relative.clone(),
                        local_entry: Some(LocalFileEntry {
                            relative_path: std::path::PathBuf::from(relative),
                            size,
                            mtime_ms,
                            quick_hash,
                            is_dir: false,
                            mime_type,
                        }),
                        remote_entry: None,
                        db_mapping,
                    });
                }
            }

            let scan_dirs = find_top_level_dirs(&dir_paths);

            let all_handled: std::collections::HashSet<&String> = handled_old_rels
                .iter()
                .chain(handled_new_rels.iter())
                .collect();
            let filtered_scan_dirs: Vec<String> = scan_dirs
                .into_iter()
                .filter(|dir| {
                    if all_handled.iter().any(|rel| {
                        rel.starts_with(dir.as_str())
                            && rel.as_bytes().get(dir.len()) == Some(&b'/')
                    }) {
                        return false;
                    }
                    for entry in self.suppress_paths.iter() {
                        let rel = entry.key();
                        if rel.starts_with(dir.as_str())
                            && rel.as_bytes().get(dir.len()) == Some(&b'/')
                        {
                            return false;
                        }
                        if dir.as_str() == rel.as_str() {
                            return false;
                        }
                    }
                    true
                })
                .collect();

            if !filtered_scan_dirs.is_empty() {
                uploads.retain(|action| {
                    !filtered_scan_dirs.iter().any(|dir| {
                        action.relative_path.starts_with(dir)
                            && action.relative_path.as_bytes().get(dir.len()) == Some(&b'/')
                    })
                });
            }

            if !uploads.is_empty() || !filtered_scan_dirs.is_empty() {
                tracing::info!(
                    "本地事件收集完成: 上传={}, 目录扫描={:?}, 跳过(未稳定)={}, 跳过(重复上传)={}",
                    uploads.len(),
                    filtered_scan_dirs,
                    skipped_unstable,
                    skipped_uploading,
                );
                let plan = SyncPlan {
                    uploads,
                    scan_dirs: filtered_scan_dirs,
                    ..Default::default()
                };
                let worker_config = self.snapshot_worker_config().await;
                let conflict_resolver = self.conflict.read().await.clone();
                self.worker_pool
                    .submit_background(
                        plan,
                        worker_config,
                        WorkerTrigger::Continuous,
                        conflict_resolver,
                    )
                    .await;
            }
        }

        // === 提交删除远程任务 (本地删除 → 删除远程) ===
        // Full 模式：始终同步删除远程
        // MirrorWcf 模式：仅在 wcf_delete_mode == SyncRemote 时删除远程，否则仅删除本地（保留远程以便重新水合）
        let wcf_should_delete_remote = matches!(sync_mode, SyncMode::MirrorWcf)
            && matches!(wcf_delete_mode, WcfDeleteMode::SyncRemote);
        if !delete_paths.is_empty()
            && (matches!(sync_mode, SyncMode::Full) || wcf_should_delete_remote)
        {
            let mut delete_remote: Vec<SyncAction> = Vec::new();
            for relative in &delete_paths {
                tracing::info!("检测到本地文件删除: {}", relative);
                if let Ok(Some(mapping)) = self.db.get_file_mapping(&root_id, relative).await {
                    delete_remote.push(SyncAction {
                        relative_path: relative.clone(),
                        local_entry: None,
                        remote_entry: Some(RemoteFileEntry {
                            uri: mapping.remote_uri.clone(),
                            name: String::new(),
                            size: 0,
                            mtime_ms: 0,
                            hash: None,
                            is_dir: false,
                            file_id: mapping.remote_file_id.clone(),
                            path: String::new(),
                            created_at_ms: 0,
                        }),
                        db_mapping: Some(mapping),
                    });
                    let _ = self.db.delete_file_mapping(&root_id, relative).await;
                }
            }

            if !delete_remote.is_empty() {
                tracing::info!("本地删除事件收集完成: 删远程={}", delete_remote.len());
                let plan = SyncPlan {
                    delete_remote,
                    ..Default::default()
                };
                let worker_config = self.snapshot_worker_config().await;
                let conflict_resolver = self.conflict.read().await.clone();
                self.worker_pool
                    .submit_background(
                        plan,
                        worker_config,
                        WorkerTrigger::Continuous,
                        conflict_resolver,
                    )
                    .await;
            }
        }

        // UploadOnly 模式下本地删除仅清理 DB mapping，不删除远程
        if !delete_paths.is_empty() && matches!(sync_mode, SyncMode::UploadOnly) {
            for relative in &delete_paths {
                let _ = self.db.delete_file_mapping(&root_id, relative).await;
                tracing::debug!("仅上传模式: 本地删除仅清理映射，不删除远程: {}", relative);
            }
        }

        // MirrorWcf DeleteLocalOnly 模式下：本地删除仅清理 DB 映射，保留远程可重新水合
        let wcf_delete_local_only = matches!(sync_mode, SyncMode::MirrorWcf)
            && !matches!(wcf_delete_mode, WcfDeleteMode::SyncRemote);
        if !delete_paths.is_empty() && wcf_delete_local_only {
            for relative in &delete_paths {
                if let Ok(Some(_)) = self.db.get_file_mapping(&root_id, relative).await {
                    let _ = self.db.delete_file_mapping(&root_id, relative).await;
                    tracing::info!("MirrorWcf(仅删除本地): 清理映射，保留远程: {}", relative);
                }
            }
        }
    }
}

/// 从两个绝对路径生成相对于 local_root 的相对路径对
fn rel_pair(
    local_root: &std::path::Path,
    old_path: &std::path::Path,
    new_path: &std::path::Path,
) -> Option<(String, String)> {
    let old_rel = old_path
        .strip_prefix(local_root)
        .ok()?
        .to_string_lossy()
        .to_string();
    let new_rel = new_path
        .strip_prefix(local_root)
        .ok()?
        .to_string_lossy()
        .to_string();
    Some((
        crate::utils::normalize_path(&old_rel),
        crate::utils::normalize_path(&new_rel),
    ))
}

fn find_top_level_dirs(dirs: &[String]) -> Vec<String> {
    if dirs.is_empty() {
        return Vec::new();
    }

    let mut sorted: Vec<&String> = dirs.iter().collect();
    sorted.sort();

    let mut top_level = Vec::new();
    for dir in &sorted {
        let dominated = top_level.iter().any(|parent: &String| {
            dir.starts_with(parent.as_str()) && dir.as_bytes().get(parent.len()) == Some(&b'/')
        });
        if !dominated {
            top_level.retain(|existing: &String| {
                !existing.starts_with(dir.as_str())
                    || existing.as_bytes().get(dir.len()) != Some(&b'/')
            });
            top_level.push((*dir).clone());
        }
    }

    top_level
}

/// 检测文件是否稳定（不在被写入中）
async fn is_file_stable(path: &Path) -> bool {
    let size1 = match tokio::fs::metadata(path).await {
        Ok(m) if !m.is_dir() => m.len(),
        _ => return false,
    };

    let path_display = path.display().to_string();
    let can_open = tokio::task::spawn_blocking(move || match std::fs::File::open(&path_display) {
        Ok(_) => true,
        Err(e) => {
            tracing::trace!("文件稳定性检测打开失败: {}", e);
            false
        }
    })
    .await
    .unwrap_or(false);

    if !can_open {
        return false;
    }

    tokio::time::sleep(std::time::Duration::from_millis(200)).await;

    let size2 = match tokio::fs::metadata(path).await {
        Ok(m) if !m.is_dir() => m.len(),
        _ => return false,
    };

    size1 == size2 && size1 > 0
}
