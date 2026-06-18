use crate::api_client::ApiClient;
use crate::errors::{Result, SyncError};
use crate::file_lock::FileLockRegistry;
use crate::models::*;
use crate::sync_db::SyncDb;
use dashmap::DashMap;
use std::path::Path;
use tokio::sync::Semaphore;
use tokio_util::sync::CancellationToken;

/// 上传单个文件（含重试），受并发信号量控制
/// 逐块读取文件，避免全量加载到内存
#[allow(clippy::too_many_arguments)]
pub async fn upload_file(
    task_id: &str,
    action: &SyncAction,
    config: &WorkerConfig,
    api: &ApiClient,
    db: &SyncDb,
    file_locks: &FileLockRegistry,
    ensured_dirs: &DashMap<String, ()>,
    semaphore: &Semaphore,
    root_id: &str,
    shutdown_token: &CancellationToken,
    pause_token: &CancellationToken,
) -> Result<()> {
    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
        return Err(SyncError::Cancelled);
    }

    let local = action.local_entry.as_ref().ok_or_else(|| {
        SyncError::Internal("上传操作缺少本地文件信息".into())
    })?;

    let _lock = file_locks.acquire(&action.relative_path).await;

    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
        return Err(SyncError::Cancelled);
    }

    if local.is_dir {
        let remote_uri = format!("{}/{}", config.remote_root, action.relative_path);
        ensure_remote_dirs(task_id, config.remote_root.as_str(), &action.relative_path, api, ensured_dirs).await?;
        db.upsert_file_mapping(&FileMapping {
            id: 0,
            sync_root_id: root_id.to_string(),
            local_path: local.relative_path.clone(),
            remote_uri,
            remote_file_id: None,
            local_hash: Some(local.quick_hash.clone()),
            remote_hash: None,
            local_mtime: Some(local.mtime_ms),
            remote_mtime: None,
            local_size: Some(local.size),
            remote_size: None,
            sync_status: SyncFileStatus::Synced,
            is_placeholder: false,
        }).await?;
        return Ok(());
    }

    let local_path = config.local_root.join(&local.relative_path);
    let file_uri = format!("{}/{}", config.remote_root, action.relative_path);

    let _permit = semaphore.acquire().await
        .map_err(|e| SyncError::Internal(format!("获取传输信号量失败: {}", e)))?;

    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
        return Err(SyncError::Cancelled);
    }

    // 信号量获取后标记为 Running（实际开始传输）
    let _ = db
        .update_task_item_status_by_path(
            task_id,
            &action.relative_path,
            "upload",
            &TaskItemStatus::Running,
            None,
        )
        .await;

    let max_retries = 3u32;

    // 确保远程父目录链存在
    if let Some(parent) = Path::new(&action.relative_path).parent() {
        let parent_str = parent.to_string_lossy().to_string();
        if !parent_str.is_empty() {
            if let Err(e) = ensure_remote_dirs(task_id, &config.remote_root, &parent_str, api, ensured_dirs).await {
                tracing::warn!("[{}] 确保远程父目录失败 {}: {}", task_id, parent_str, e);
            }
        }
    }

    let overwrite = action.db_mapping.is_some();

    // 打开文件（加重试，处理文件被占用的情况）
    let file = {
        let mut read_retries = 0u32;
        loop {
            match tokio::fs::File::open(&local_path).await {
                Ok(f) => break f,
                Err(e) if e.raw_os_error() == Some(32) && read_retries < 5 => {
                    read_retries += 1;
                    let delay = read_retries * 1000;
                    tracing::warn!("[{}] 文件被占用，{}ms后重试 ({}): {}", task_id, delay, read_retries, local_path.display());
                    tokio::time::sleep(std::time::Duration::from_millis(delay as u64)).await;
                }
                Err(e) => return Err(e.into()),
            }
        }
    };

    let last_modified = if local.mtime_ms > 0 { Some(local.mtime_ms) } else { None };
    let mime_type_str = local.mime_type.as_deref();
    let session = retry_upload_session(
        task_id, &file_uri, local.size, max_retries, overwrite, last_modified, mime_type_str, None, api,
    ).await?;
    let chunk_size = session.chunk_size as usize;

    tracing::info!("[{}] chunk_size={}bytes, 开始上传: {} ({}bytes)", task_id, chunk_size, action.relative_path, local.size);

    // 逐块读取 + 上传，内存占用仅为一个 chunk
    // 分片上传要求：每个分片（除最后一个）必须恰好 chunk_size 字节
    // 因此需要循环 read 直到读满 buffer 或到达 EOF，才能作为一个分片上传
    let mut reader = tokio::io::BufReader::new(file);
    let mut buf = vec![0u8; chunk_size];
    let mut index: u32 = 0;

    loop {
        if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
            return Err(SyncError::Cancelled);
        }
        use tokio::io::AsyncReadExt;
        let mut filled = 0usize;
        loop {
            let n = reader.read(&mut buf[filled..]).await?;
            if n == 0 { break; }
            filled += n;
            if filled >= chunk_size { break; }
        }
        if filled == 0 { break; }

        let chunk = &buf[..filled];
        let mut chunk_retries = 0u32;
        loop {
            if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
                return Err(SyncError::Cancelled);
            }
            match api.upload_chunk(&session, index, chunk, local.size, task_id).await {
                Ok(_) => break,
                Err(SyncError::Auth(_)) => return Err(SyncError::Auth("Token 过期".into())),
                // 业务错误，重试无意义，直接失败
                Err(e @ SyncError::StoragePolicyDenied(_))
                | Err(e @ SyncError::UploadFailed(_))
                | Err(e @ SyncError::FileNotFound(_))
                | Err(e @ SyncError::PermissionDenied(_))
                | Err(e @ SyncError::ObjectExisted) => return Err(e),
                Err(e) if chunk_retries < max_retries => {
                    chunk_retries += 1;
                    let delay = crate::utils::retry_delay_ms(chunk_retries, 1000, 30000);
                    tracing::warn!("[{}] 上传重试 ({}/{}): {}: {}", task_id, chunk_retries, max_retries, action.relative_path, e);
                    tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
                        return Err(SyncError::Cancelled);
                    }
                }
                Err(e) => return Err(e),
            }
        }
        index += 1;
    }

    // 远程存储策略：上传完成后回调 Cloudreve 服务端
    if session.is_remote_storage() {
        if let Err(e) = api.callback_upload_complete(&session, task_id).await {
            tracing::warn!("[{}][{}] 上传完成回调失败: {}", task_id, session.file_name, e);
        }
    }

    // 上传完成后获取远程文件信息
    let remote_uri = file_uri.clone();
    let (remote_file_id, remote_hash) = match api.get_file_info(&remote_uri).await {
        Ok(info) => (info.file_id.clone(), info.hash.clone()),
        Err(e) => {
            tracing::warn!("[{}] 上传后获取文件信息失败: {}", task_id, e);
            (None, None)
        }
    };

    db.upsert_file_mapping(&FileMapping {
        id: 0,
        sync_root_id: root_id.to_string(),
        local_path: local.relative_path.clone(),
        remote_uri,
        remote_file_id,
        local_hash: Some(local.quick_hash.clone()),
        remote_hash: remote_hash.or(Some(local.quick_hash.clone())),
        local_mtime: Some(local.mtime_ms),
        remote_mtime: Some(local.mtime_ms),
        local_size: Some(local.size),
        remote_size: Some(local.size),
        sync_status: SyncFileStatus::Synced,
        is_placeholder: false,
    }).await?;

    tracing::info!("[{}] 上传完成: {}", task_id, action.relative_path);
    Ok(())
}

/// 带重试的创建上传会话（遇到锁冲突自动强制解锁）
#[allow(clippy::too_many_arguments)]
pub async fn retry_upload_session(
    task_id: &str,
    file_uri: &str,
    file_size: u64,
    max_retries: u32,
    overwrite: bool,
    last_modified: Option<i64>,
    mime_type: Option<&str>,
    policy_id: Option<&str>,
    api: &ApiClient,
) -> Result<UploadSession> {
    let mut attempt = 0u32;
    let mut tried_overwrite = overwrite;
    loop {
        attempt += 1;
        match api.create_upload_session(file_uri, file_size, tried_overwrite, last_modified, mime_type, policy_id).await {
            Ok(session) => return Ok(session),
            Err(SyncError::Auth(_)) => return Err(SyncError::Auth("Token 过期".into())),
            Err(SyncError::ObjectExisted) if !tried_overwrite => {
                tracing::info!("[{}] 远程文件已存在，切换为覆盖上传", task_id);
                tried_overwrite = true;
                continue;
            }
            Err(SyncError::LockConflict { tokens }) => {
                tracing::warn!("[{}] 文件锁定冲突，强制解锁 {} 个锁后重试", task_id, tokens.len());
                if let Err(e) = api.force_unlock_files(&tokens).await {
                    tracing::error!("[{}] 强制解锁失败: {}", task_id, e);
                }
                if attempt <= max_retries {
                    continue;
                }
                return Err(SyncError::LockConflict { tokens });
            }
            // 业务错误，重试无意义，直接失败
            Err(e @ SyncError::StoragePolicyDenied(_))
            | Err(e @ SyncError::UploadFailed(_))
            | Err(e @ SyncError::FileNotFound(_))
            | Err(e @ SyncError::PermissionDenied(_)) => return Err(e),
            Err(e) if attempt <= max_retries => {
                let delay = crate::utils::retry_delay_ms(attempt, 1000, 30000);
                tracing::warn!("[{}] 创建上传会话失败，{}ms后重试 ({}): {}", task_id, delay, attempt, e);
                tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
            }
            Err(e) => return Err(e),
        }
    }
}

/// 递归确保远程目录链存在（带缓存）
pub async fn ensure_remote_dirs(
    task_id: &str,
    remote_root: &str,
    relative_path: &str,
    api: &ApiClient,
    ensured_dirs: &DashMap<String, ()>,
) -> Result<()> {
    let parts: Vec<&str> = relative_path.split('/').filter(|p| !p.is_empty()).collect();
    if parts.is_empty() {
        return Ok(());
    }

    let mut current = remote_root.to_string();
    let mut dirs_to_create: Vec<(String, String)> = Vec::new();

    for part in &parts {
        let next_uri = format!("{}/{}", current, part);
        if ensured_dirs.contains_key(&next_uri) {
            current = next_uri;
            continue;
        }
        dirs_to_create.push((current.clone(), part.to_string()));
        current = next_uri;
    }

    if dirs_to_create.is_empty() {
        return Ok(());
    }

    for (parent_uri, dir_name) in &dirs_to_create {
        let uri = format!("{}/{}", parent_uri, dir_name);
        match api.create_directory(parent_uri, dir_name).await {
            Ok(_) => {
                tracing::debug!("[{}] 创建远程目录: {}", task_id, uri);
                ensured_dirs.insert(uri.clone(), ());
            }
            Err(e) => {
                let msg = e.to_string();
                if msg.contains("exist") || msg.contains("already") || msg.contains("40004") {
                    ensured_dirs.insert(uri.clone(), ());
                } else {
                    tracing::warn!("[{}] 创建远程目录失败 {}: {}", task_id, uri, e);
                }
            }
        }
    }

    Ok(())
}

/// 逐块读取文件并上传分片（用于相册同步等场景，避免全量加载到内存）
/// 分片上传要求：每个分片（除最后一个）必须恰好 chunk_size 字节
pub async fn upload_file_chunked(
    api: &ApiClient,
    local_path: &Path,
    session: &UploadSession,
    task_id: &str,
) -> Result<()> {
    let chunk_size = session.chunk_size as usize;
    let file = tokio::fs::File::open(local_path).await?;
    let file_size = file.metadata().await.map(|m| m.len()).unwrap_or(0);
    let mut reader = tokio::io::BufReader::new(file);
    let mut buf = vec![0u8; chunk_size];
    let mut index: u32 = 0;

    loop {
        use tokio::io::AsyncReadExt;
        let mut filled = 0usize;
        loop {
            let n = reader.read(&mut buf[filled..]).await?;
            if n == 0 { break; }
            filled += n;
            if filled >= chunk_size { break; }
        }
        if filled == 0 { break; }

        api.upload_chunk(session, index, &buf[..filled], file_size, task_id).await?;
        index += 1;
    }

    // 远程存储策略：上传完成后回调 Cloudreve 服务端
    if session.is_remote_storage() {
        if let Err(e) = api.callback_upload_complete(session, task_id).await {
            tracing::warn!("[{}][{}] 上传完成回调失败: {}", task_id, session.file_name, e);
        }
    }

    Ok(())
}
