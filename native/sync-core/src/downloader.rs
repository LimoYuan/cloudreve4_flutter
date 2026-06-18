use crate::api_client::ApiClient;
use crate::errors::{Result, SyncError};
use crate::file_lock::FileLockRegistry;
use crate::models::*;
use crate::sync_db::SyncDb;
use tokio::sync::Semaphore;
use tokio_util::sync::CancellationToken;

/// 下载单个文件（含重试 + 断点续传），受并发信号量控制
#[allow(clippy::too_many_arguments)]
pub async fn download_file(
    task_id: &str,
    action: &SyncAction,
    config: &WorkerConfig,
    api: &ApiClient,
    db: &SyncDb,
    file_locks: &FileLockRegistry,
    semaphore: &Semaphore,
    root_id: &str,
    shutdown_token: &CancellationToken,
    pause_token: &CancellationToken,
) -> Result<()> {
    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
        return Err(SyncError::Cancelled);
    }

    let remote = action.remote_entry.as_ref().ok_or_else(|| {
        SyncError::Internal("下载操作缺少远程文件信息".into())
    })?;

    let _lock = file_locks.acquire(&action.relative_path).await;

    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
        return Err(SyncError::Cancelled);
    }

    if remote.is_dir {
        let local_path = config.local_root.join(&action.relative_path);
        tokio::fs::create_dir_all(&local_path).await?;
        tracing::debug!("[{}] 创建本地目录: {}", task_id, action.relative_path);
        return Ok(());
    }

    let local_path = config.local_root.join(&action.relative_path);

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
            "download",
            &TaskItemStatus::Running,
            None,
        )
        .await;

    tracing::info!("[{}] 开始下载: {} ({}bytes)", task_id, action.relative_path, remote.size);

    // 确保父目录存在
    if let Some(parent) = local_path.parent() {
        if !parent.exists() {
            tokio::fs::create_dir_all(parent).await?;
        }
    }

    let max_retries = 3u32;
    let mut attempt = 0u32;
    let tmp_path = local_path.with_extension(".sync_tmp");

    loop {
        if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
            return Err(SyncError::Cancelled);
        }
        attempt += 1;

        // 检查临时文件已有大小，用于断点续传
        let resume_offset = if tmp_path.exists() {
            tokio::fs::metadata(&tmp_path).await.map(|m| m.len()).unwrap_or(0)
        } else {
            0
        };

        let urls = match api.get_download_url(&[&remote.uri]).await {
            Ok(urls) => urls,
            Err(SyncError::Auth(_)) => return Err(SyncError::Auth("Token 过期".into())),
            Err(SyncError::Cancelled) => return Err(SyncError::Cancelled),
            Err(e) if attempt <= max_retries => {
                let delay = crate::utils::retry_delay_ms(attempt, 1000, 30000);
                tracing::warn!("[{}] 下载重试 ({}/{}): {} 获取链接失败: {}", task_id, attempt, max_retries, action.relative_path, e);
                tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                continue;
            }
            Err(e) => return Err(e),
        };

        let download_url = match urls.first() {
            Some(u) => u.clone(),
            None => {
                tracing::error!("[{}] 未获取到下载链接, uri={}", task_id, remote.uri);
                return Err(SyncError::Network("未获取到下载链接".into()));
            }
        };

        let resp = match api.stream_download(&download_url, resume_offset).await {
            Ok(r) => r,
            Err(SyncError::Auth(_)) => return Err(SyncError::Auth("Token 过期".into())),
            Err(e) if attempt <= max_retries => {
                let delay = crate::utils::retry_delay_ms(attempt, 1000, 30000);
                tracing::warn!("[{}] 下载重试 ({}/{}): {} 连接失败: {}", task_id, attempt, max_retries, action.relative_path, e);
                tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                continue;
            }
            Err(e) => return Err(e),
        };

        match stream_to_file_cancellable(resp, &tmp_path, config.bandwidth_limit, resume_offset, shutdown_token, pause_token).await {
            Ok(_) => {
                tracing::debug!("[{}] 下载写入完成: {} ({}bytes)", task_id, tmp_path.display(), remote.size);
                tokio::fs::rename(&tmp_path, &local_path).await?;

                if remote.mtime_ms > 0 {
                    let mtime = std::time::UNIX_EPOCH + std::time::Duration::from_millis(remote.mtime_ms as u64);
                    let _ = filetime::set_file_mtime(&local_path, filetime::FileTime::from_system_time(mtime));
                }

                let local_hash = crate::utils::quick_hash(&local_path, remote.size).await.unwrap_or_default();
                db.upsert_file_mapping(&FileMapping {
                    id: 0,
                    sync_root_id: root_id.to_string(),
                    local_path: std::path::PathBuf::from(&action.relative_path),
                    remote_uri: remote.uri.clone(),
                    remote_file_id: remote.file_id.clone(),
                    local_hash: Some(local_hash.clone()),
                    remote_hash: remote.hash.clone().or(Some(local_hash)),
                    local_mtime: Some(remote.mtime_ms),
                    remote_mtime: Some(remote.mtime_ms),
                    local_size: Some(remote.size),
                    remote_size: Some(remote.size),
                    sync_status: SyncFileStatus::Synced,
                    is_placeholder: false,
                }).await?;

                tracing::info!("[{}] 下载完成: {}", task_id, action.relative_path);
                return Ok(());
            }
            Err(SyncError::Cancelled) => return Err(SyncError::Cancelled),
            Err(e) if attempt <= max_retries => {
                let delay = crate::utils::retry_delay_ms(attempt, 1000, 30000);
                // 保留临时文件用于断点续传
                let existing_size = tokio::fs::metadata(&tmp_path).await.map(|m| m.len()).unwrap_or(0);
                if existing_size > 0 {
                    tracing::warn!(
                        "[{}] 下载重试 ({}/{}): {} 写入失败(已下载{}bytes，将从断点续传): {}",
                        task_id, attempt, max_retries, action.relative_path, existing_size, e,
                    );
                } else {
                    tracing::warn!(
                        "[{}] 下载重试 ({}/{}): {} 写入失败: {}",
                        task_id, attempt, max_retries, action.relative_path, e,
                    );
                }
                tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                continue;
            }
            Err(e) => {
                let _ = tokio::fs::remove_file(&tmp_path).await;
                return Err(e);
            }
        }
    }
}

/// 流式写入文件（含带宽限速 + 断点续传）
/// resume_offset > 0 时以追加模式打开文件，跳过已下载部分
pub async fn stream_to_file(
    resp: reqwest::Response,
    tmp_path: &std::path::Path,
    bandwidth_limit: Option<u64>,
    resume_offset: u64,
) -> Result<()> {
    let shutdown_token = CancellationToken::new();
    let pause_token = CancellationToken::new();
    stream_to_file_cancellable(
        resp,
        tmp_path,
        bandwidth_limit,
        resume_offset,
        &shutdown_token,
        &pause_token,
    )
    .await
}

/// 流式写入文件（可由同步控制 token 中断，保留 .sync_tmp 供恢复续传）
pub async fn stream_to_file_cancellable(
    resp: reqwest::Response,
    tmp_path: &std::path::Path,
    bandwidth_limit: Option<u64>,
    resume_offset: u64,
    shutdown_token: &CancellationToken,
    pause_token: &CancellationToken,
) -> Result<()> {
    use tokio::io::{AsyncWriteExt, AsyncSeekExt};
    use futures_util::StreamExt;

    let mut file = if resume_offset > 0 && tmp_path.exists() {
        // 断点续传：追加模式
        let mut f = tokio::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open(tmp_path)
            .await?;
        f.seek(std::io::SeekFrom::End(0)).await?;
        f
    } else {
        tokio::fs::File::create(tmp_path).await?
    };

    let mut stream = resp.bytes_stream();
    let mut total_bytes = resume_offset;

    match bandwidth_limit {
        None => {
            while let Some(chunk) = stream.next().await {
                if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
                    return Err(SyncError::Cancelled);
                }
                let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                file.write_all(&chunk).await?;
            }
        }
        Some(limit) => {
            // limit == 0 视为无限速，避免除零 panic
            if limit == 0 {
                tracing::warn!(
                    "stream_to_file: bandwidth_limit=Some(0) 被识别为无限速，请检查上层是否应传 None（tmp={}）",
                    tmp_path.display()
                );
                while let Some(chunk) = stream.next().await {
                    if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
                        return Err(SyncError::Cancelled);
                    }
                    let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                    file.write_all(&chunk).await?;
                }
                file.flush().await?;
                return Ok(());
            }
            let transfer_start = std::time::Instant::now();

            while let Some(chunk) = stream.next().await {
                if shutdown_token.is_cancelled() || pause_token.is_cancelled() {
                    return Err(SyncError::Cancelled);
                }
                let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                total_bytes += chunk.len() as u64;
                file.write_all(&chunk).await?;

                let expected_elapsed = std::time::Duration::from_micros(
                    total_bytes * 1_000_000 / limit
                );
                let actual_elapsed = transfer_start.elapsed();
                if expected_elapsed > actual_elapsed {
                    tokio::time::sleep(expected_elapsed - actual_elapsed).await;
                }
            }
        }
    }

    file.flush().await?;
    Ok(())
}

/// 从 URL 下载文件到指定路径（WCF 水合使用）
pub async fn download_file_from_url(
    download_url: &str,
    local_path: &std::path::Path,
    expected_size: u64,
    bandwidth_limit: Option<u64>,
) -> Result<()> {
    let client = reqwest::Client::new();
    let mut request = client.get(download_url);

    // 断点续传
    let resume_offset = if local_path.exists() {
        let metadata = tokio::fs::metadata(local_path).await?;
        if metadata.len() > 0 && metadata.len() < expected_size {
            request = request.header("Range", format!("bytes={}-", metadata.len()));
            metadata.len()
        } else {
            0
        }
    } else {
        0
    };

    let resp = request.send().await.map_err(|e| SyncError::Network(e.to_string()))?;

    if !resp.status().is_success() && resp.status().as_u16() != 206 {
        return Err(SyncError::Network(format!("下载失败: HTTP {}", resp.status())));
    }

    let tmp_path = local_path.with_extension(format!(
        "{}.sync_tmp",
        local_path.extension().map(|e| e.to_string_lossy().to_string()).unwrap_or_default()
    ));

    stream_to_file(resp, &tmp_path, bandwidth_limit, resume_offset).await?;

    // 重命名临时文件为最终文件
    if tmp_path.exists() {
        let _ = std::fs::remove_file(local_path);
        std::fs::rename(&tmp_path, local_path)
            .map_err(|e| SyncError::FileSystem(format!("重命名临时文件失败: {}", e)))?;
    }

    Ok(())
}

/// 从 URL 下载数据到内存缓冲区（WCF CfExecute 水合使用）
pub async fn download_to_buffer(
    api: &ApiClient,
    download_url: &str,
    bandwidth_limit: Option<u64>,
) -> Result<Vec<u8>> {
    use futures_util::StreamExt;

    let resp = api.stream_download(download_url, 0).await?;

    if !resp.status().is_success() {
        return Err(SyncError::Network(format!("下载失败: HTTP {}", resp.status())));
    }

    let content_length = resp.content_length();
    let mut buffer = Vec::with_capacity(content_length.unwrap_or(0) as usize);
    let mut stream = resp.bytes_stream();
    let mut total_bytes: u64 = 0;

    match bandwidth_limit {
        None => {
            while let Some(chunk) = stream.next().await {
                let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                buffer.extend_from_slice(&chunk);
            }
        }
        Some(limit) => {
            // limit == 0 视为无限速，避免除零 panic
            if limit == 0 {
                tracing::warn!(
                    "download_to_buffer: bandwidth_limit=Some(0) 被识别为无限速，请检查上层是否应传 None"
                );
                while let Some(chunk) = stream.next().await {
                    let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                    buffer.extend_from_slice(&chunk);
                }
                return Ok(buffer);
            }
            let transfer_start = std::time::Instant::now();
            while let Some(chunk) = stream.next().await {
                let chunk = chunk.map_err(|e| SyncError::Network(e.to_string()))?;
                total_bytes += chunk.len() as u64;
                buffer.extend_from_slice(&chunk);

                let expected_elapsed = std::time::Duration::from_micros(
                    total_bytes * 1_000_000 / limit
                );
                let actual_elapsed = transfer_start.elapsed();
                if expected_elapsed > actual_elapsed {
                    tokio::time::sleep(expected_elapsed - actual_elapsed).await;
                }
            }
        }
    }

    Ok(buffer)
}
