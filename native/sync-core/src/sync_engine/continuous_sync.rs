use crate::errors::Result;
use crate::event_handler::EventHandler;
use crate::models::*;
use crate::utils::lock_recover;

use super::SyncEngine;

impl SyncEngine {
    /// 持续同步：双事件源驱动 (SSE + 本地文件监听)，按 sync_mode 选择事件源
    pub async fn run_continuous(&self) -> Result<()> {
        let event_handler = EventHandler::new(
            self.api.clone(),
            self.api.client_id().to_string(),
        );

        let (local_root, remote_root, sync_mode) = {
            let config = self.config.read().await;
            (config.local_root.clone(), config.remote_root.clone(), config.sync_mode.clone())
        };

        // 仅 DownloadOnly、Full、MirrorWcf、AlbumDownload 订阅 SSE
        let mut remote_rx = if matches!(sync_mode, SyncMode::DownloadOnly | SyncMode::Full | SyncMode::MirrorWcf | SyncMode::AlbumDownload) {
            Some(event_handler.subscribe_sse(&remote_root).await?)
        } else {
            tracing::info!("仅上传模式: 不订阅 SSE 远程事件");
            None
        };

        // 仅 UploadOnly、Full、MirrorWcf、AlbumUpload 启动本地文件监听
        // 但 FUSE 模式下不需要：所有文件操作都经过 FUSE handler，监听器只会造成无限循环
        #[cfg(feature = "linux-fuse")]
        let fuse_active = lock_recover(&self.fuse_request_rx).is_some();
        #[cfg(not(feature = "linux-fuse"))]
        let fuse_active = false;

        let mut local_rx = if matches!(sync_mode, SyncMode::UploadOnly | SyncMode::Full | SyncMode::MirrorWcf | SyncMode::AlbumUpload) && !fuse_active {
            Some(spawn_local_watcher(&local_root, lock_recover(&self.shutdown_token).clone()))
        } else if fuse_active {
            tracing::info!("FUSE 模式: 不启动本地文件监听（FUSE handler 已处理所有操作）");
            None
        } else {
            tracing::info!("仅下载模式: 不启动本地文件监听");
            None
        };

        *self.state.write().await = SyncState::Continuous;
        tracing::info!("持续同步已启动, 模式={:?}", sync_mode);

        // MirrorWcf: 取走 WCF 回调接收端
        #[cfg(feature = "windows-cfapi")]
        let mut wcf_fetch_rx = if matches!(sync_mode, SyncMode::MirrorWcf) {
            lock_recover(&self.wcf_fetch_rx).take()
        } else {
            None
        };
        #[cfg(not(feature = "windows-cfapi"))]
        let _wcf_fetch_rx: Option<()> = None;

        // MirrorFUSE: 取走 FUSE 请求接收端
        #[cfg(feature = "linux-fuse")]
        let mut fuse_request_rx = if matches!(sync_mode, SyncMode::MirrorWcf) {
            lock_recover(&self.fuse_request_rx).take()
        } else {
            None
        };
        #[cfg(not(feature = "linux-fuse"))]
        let _fuse_request_rx: Option<()> = None;

        let mut debounce = crate::event_handler::EventDebouncer::new(
            std::time::Duration::from_millis(500),
        );

        let shutdown_token = lock_recover(&self.shutdown_token).clone();
        loop {
            tokio::select! {
                _ = shutdown_token.cancelled() => {
                    tracing::info!("持续同步收到停止信号");
                    break;
                }

                // 本地文件变化（仅 UploadOnly / Full / MirrorWcf）
                Some(event) = async {
                    match &mut local_rx {
                        Some(rx) => rx.recv().await,
                        None => std::future::pending().await,
                    }
                } => {
                    let mut all_events = vec![event];
                    let idle_timeout = std::time::Duration::from_secs(3);
                    if let Some(rx) = &mut local_rx {
                        while let Ok(Some(e)) = tokio::time::timeout(idle_timeout, rx.recv()).await {
                            all_events.push(e)
                        }
                    }

                    self.handle_local_events(all_events, &local_root, &mut debounce).await;
                }

                // 远程文件变化（DownloadOnly / Full / MirrorWcf）
                Some(event) = async {
                    match &mut remote_rx {
                        Some(rx) => rx.recv().await,
                        None => std::future::pending().await,
                    }
                } => {
                    self.handle_remote_event(event, &local_root, &remote_root).await;
                }

                // WCF 水合请求（仅 MirrorWcf）
                request = async {
                    #[cfg(feature = "windows-cfapi")]
                    {
                        match &mut wcf_fetch_rx {
                            Some(rx) => rx.recv().await,
                            None => std::future::pending().await,
                        }
                    }
                    #[cfg(not(feature = "windows-cfapi"))]
                    {
                        let _: Option<()> = std::future::pending().await;
                        None::<()>
                    }
                } => {
                    if let Some(req) = request {
                        #[cfg(feature = "windows-cfapi")]
                        self.handle_wcf_fetch(req, &local_root).await;
                        #[cfg(not(feature = "windows-cfapi"))]
                        let _: () = req;
                    }
                }

                // FUSE 请求（仅 MirrorFUSE）
                request = async {
                    #[cfg(feature = "linux-fuse")]
                    {
                        match &mut fuse_request_rx {
                            Some(rx) => rx.recv().await,
                            None => std::future::pending().await,
                        }
                    }
                    #[cfg(not(feature = "linux-fuse"))]
                    {
                        let _: Option<()> = std::future::pending().await;
                        None::<()>
                    }
                } => {
                    if let Some(req) = request {
                        #[cfg(feature = "linux-fuse")]
                        self.handle_fuse_request(req, &local_root).await;
                        #[cfg(not(feature = "linux-fuse"))]
                        let _: () = req;
                    }
                }

                // 定期心跳
                _ = tokio::time::sleep(std::time::Duration::from_secs(60)) => {
                    tracing::trace!("持续同步心跳");
                    debounce.cleanup();
                }
            }
        }

        Ok(())
    }
}

/// 启动本地文件监听器，返回事件接收端
fn spawn_local_watcher(
    watch_root: &std::path::Path,
    shutdown_token: tokio_util::sync::CancellationToken,
) -> tokio::sync::mpsc::Receiver<LocalFileEvent> {
    let (local_tx, rx) = tokio::sync::mpsc::channel::<LocalFileEvent>(256);
    let watch_root = watch_root.to_path_buf();

    std::thread::spawn(move || {
        use notify_debouncer_full::notify::{RecursiveMode, EventKind};
        use notify_debouncer_full::notify::event::{ModifyKind, RenameMode};
        use notify_debouncer_full::new_debouncer;

        let tx = local_tx.clone();
        let shutdown = shutdown_token.clone();

        let mut debouncer = match new_debouncer(
            std::time::Duration::from_millis(500),
            None,
            move |result: notify_debouncer_full::DebounceEventResult| {
                match result {
                    Ok(events) => {
                        for event in events {
                            if shutdown.is_cancelled() { return; }
                            let kind = event.kind;
                            let paths = &event.paths;

                            let filtered: Vec<_> = paths.iter()
                                .filter(|p| !p.extension().map(|e| e == "sync_tmp").unwrap_or(false))
                                .cloned()
                                .collect();
                            if filtered.is_empty() { continue; }

                            match kind {
                                EventKind::Create(_) => {
                                    let _ = tx.blocking_send(LocalFileEvent::Created(filtered));
                                }
                                EventKind::Modify(ModifyKind::Name(RenameMode::From)) => {}
                                EventKind::Modify(ModifyKind::Name(RenameMode::To)) => {}
                                EventKind::Modify(ModifyKind::Name(RenameMode::Both)) => {
                                    if filtered.len() == 2 {
                                        let _ = tx.blocking_send(LocalFileEvent::Renamed {
                                            old_paths: vec![filtered[0].clone()],
                                            new_paths: vec![filtered[1].clone()],
                                        });
                                    }
                                }
                                EventKind::Modify(ModifyKind::Name(RenameMode::Other)) => {
                                    let _ = tx.blocking_send(LocalFileEvent::Modified(filtered));
                                }
                                EventKind::Modify(_) => {
                                    let _ = tx.blocking_send(LocalFileEvent::Modified(filtered));
                                }
                                EventKind::Remove(_) => {
                                    let _ = tx.blocking_send(LocalFileEvent::Deleted(filtered));
                                }
                                _ => {}
                            }
                        }
                    }
                    Err(errors) => {
                        for e in errors {
                            tracing::warn!("文件监听去抖错误: {}", e);
                        }
                    }
                }
            },
        ) {
            Ok(d) => d,
            Err(e) => {
                tracing::error!("无法启动文件监听: {}", e);
                return;
            }
        };

        if let Err(e) = debouncer.watch(&watch_root, RecursiveMode::Recursive) {
            tracing::error!("文件监听启动失败: {}", e);
            return;
        }

        tracing::info!("本地文件监听已启动(debouncer): {}", watch_root.display());

        while !shutdown_token.is_cancelled() {
            std::thread::sleep(std::time::Duration::from_millis(500));
        }

        let _ = debouncer.unwatch(&watch_root);
        tracing::info!("本地文件监听已停止");
    });

    rx
}
