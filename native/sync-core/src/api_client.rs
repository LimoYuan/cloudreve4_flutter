use crate::errors::{Result, SyncError};
use crate::models::*;
use crate::server_error_code::api_code_to_error;
use reqwest::Client;
use serde::Deserialize;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};

#[derive(Debug, Clone, Deserialize)]
struct ApiResponse<T> {
    code: i32,
    data: Option<T>,
    msg: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct RefreshResponse {
    access_token: String,
    refresh_token: String,
}

/// Token 刷新状态：确保并发请求只刷新一次
struct RefreshState {
    refreshing: bool,
    notify: Arc<tokio::sync::Notify>,
}

pub struct ApiClient {
    base_url: String,
    access_token: RwLock<String>,
    refresh_token: RwLock<String>,
    refresh_state: Arc<Mutex<RefreshState>>,
    client: Client,
    /// 流式下载专用 client，不设整体超时，仅限制连接和读取间隔
    download_client: Client,
    client_id: String,
}

impl ApiClient {
    pub fn new(base_url: &str, access_token: &str, refresh_token: &str, client_id: &str) -> Self {
        let client = Client::builder()
            .connect_timeout(std::time::Duration::from_secs(15))
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("Failed to create HTTP client");

        let download_client = Client::builder()
            .connect_timeout(std::time::Duration::from_secs(30))
            .read_timeout(std::time::Duration::from_secs(300))
            .build()
            .expect("Failed to create download HTTP client");

        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            access_token: RwLock::new(access_token.to_string()),
            refresh_token: RwLock::new(refresh_token.to_string()),
            refresh_state: Arc::new(Mutex::new(RefreshState { refreshing: false, notify: Arc::new(tokio::sync::Notify::new()) })),
            client,
            download_client,
            client_id: client_id.to_string(),
        }
    }

    pub async fn update_token(&self, token: String) {
        *self.access_token.write().await = token;
    }

    pub async fn update_tokens(&self, access: &str, refresh: &str) {
        *self.access_token.write().await = access.to_string();
        *self.refresh_token.write().await = refresh.to_string();
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    pub fn client_id(&self) -> &str {
        &self.client_id
    }

    pub async fn token(&self) -> String {
        self.access_token.read().await.clone()
    }

    /// 带并发去重的 token 刷新
    /// 多个任务同时遇到 401 时，只有一个执行刷新，其他等待刷新完成后自动获取新 token
    pub async fn refresh_access_token(&self) -> Result<()> {
        let mut state = self.refresh_state.lock().await;

        if state.refreshing {
            // 已经有另一个任务在刷新了，等待通知
            let notify = state.notify.clone();
            drop(state);
            notify.notified().await;
            return Ok(());
        }

        state.refreshing = true;
        let notify = state.notify.clone();
        drop(state);

        let result = self.do_refresh().await;

        let mut state = self.refresh_state.lock().await;
        state.refreshing = false;
        drop(state);

        // 通知所有等待者刷新已完成
        notify.notify_waiters();

        result
    }

    async fn do_refresh(&self) -> Result<()> {
        let refresh_token = self.refresh_token.read().await.clone();
        if refresh_token.is_empty() {
            return Err(SyncError::Auth("无 refresh_token，无法刷新".into()));
        }

        tracing::info!("正在刷新 access_token...");

        let resp = self.client
            .post(format!("{}/session/token/refresh", self.base_url))
            .json(&serde_json::json!({
                "refresh_token": refresh_token,
            }))
            .send()
            .await?;

        if !resp.status().is_success() {
            return Err(SyncError::Auth(format!("Token 刷新失败: HTTP {}", resp.status())));
        }

        let api_resp: ApiResponse<RefreshResponse> = resp.json().await?;
        if api_resp.code != 0 {
            return Err(SyncError::Auth(format!(
                "Token 刷新失败: {}",
                api_resp.msg.unwrap_or_else(|| "未知错误".into())
            )));
        }

        if let Some(data) = api_resp.data {
            *self.access_token.write().await = data.access_token;
            *self.refresh_token.write().await = data.refresh_token;
            tracing::info!("access_token 刷新成功");
            Ok(())
        } else {
            Err(SyncError::Auth("Token 刷新响应缺少数据".into()))
        }
    }

    /// 解析 API 响应
    async fn parse_response(&self, resp: reqwest::Response) -> Result<serde_json::Value> {
        if !resp.status().is_success() {
            return Err(SyncError::Network(format!("HTTP {}", resp.status())));
        }
        let api_resp: ApiResponse<serde_json::Value> = resp.json().await?;
        if api_resp.code == 0 {
            return Ok(api_resp.data.unwrap_or_default());
        }

        // 40073 锁冲突需要特殊处理 data
        if api_resp.code == 40073 {
            let items = api_resp.data
                .and_then(|d| d.as_array().cloned())
                .unwrap_or_default()
                .iter()
                .filter_map(|item| {
                    let path = item.get("path").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    let token = item.get("token").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    if !token.is_empty() {
                        Some(crate::errors::LockConflictItem { path, token })
                    } else {
                        None
                    }
                })
                .collect();
            return Err(SyncError::LockConflict { tokens: items });
        }

        let msg = api_resp.msg
            .filter(|m| !m.is_empty())
            .unwrap_or_default();
        Err(api_code_to_error(api_resp.code, &msg))
    }

    /// 发送带认证的请求，自动处理 401（刷新 token 后重试一次）
    /// request_builder 接收当前 token，返回 RequestBuilder
    /// 所有请求自动附加 X-Cr-Client-Id header，服务端据此过滤 SSE 自身事件
    async fn send_with_auth_retry(
        &self,
        request_builder: impl Fn(String) -> reqwest::RequestBuilder,
    ) -> Result<serde_json::Value> {
        let client_id = self.client_id.clone();

        // 第一次尝试
        let token = self.token().await;
        let resp = match request_builder(token)
            .header("X-Cr-Client-Id", &client_id)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                tracing::warn!(
                    "请求发送失败: kind={:?}, url={:?}, error={}",
                    e.is_connect(),
                    e.url().map(|u| u.as_str()),
                    e
                );
                return Err(e.into());
            }
        };
        let result = self.parse_response(resp).await;

        if let Err(SyncError::Auth(_)) = result {
            // 刷新 token
            self.refresh_access_token().await?;
            // 用新 token 重试
            let new_token = self.token().await;
            let resp = match request_builder(new_token)
                .header("X-Cr-Client-Id", &client_id)
                .send()
                .await
            {
                Ok(r) => r,
                Err(e) => {
                    tracing::warn!(
                        "重试请求发送失败: kind={:?}, url={:?}, error={}",
                        e.is_connect(),
                        e.url().map(|u| u.as_str()),
                        e
                    );
                    return Err(e.into());
                }
            };
            return self.parse_response(resp).await;
        }

        result
    }

    // ===== 文件列表 =====

    /// 递归列出指定 URI 下的所有文件和目录
    pub async fn list_all_files(&self, uri: &str) -> Result<Vec<RemoteFileEntry>> {
        let mut all_files = Vec::new();
        self.list_all_files_recursive(uri, &mut all_files).await?;
        Ok(all_files)
    }

    fn list_all_files_recursive<'a>(
        &'a self,
        uri: &'a str,
        result: &'a mut Vec<RemoteFileEntry>,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<()>> + Send + 'a>> {
        Box::pin(async move {
            if result.len() > 1_000_000 {
                tracing::warn!("文件数量超过 100 万，截断初始同步");
                return Ok(());
            }

            let mut next_page_token: Option<String> = None;
            let mut page = 0u32;
            let page_size = 2000u32;
            let mut dirs_to_recurse = Vec::new();

            loop {
                let resp = self.list_files_page(uri, page, page_size, next_page_token.as_deref()).await?;
                let count = resp.files.len();

                for file in resp.files {
                    if file.is_dir {
                        dirs_to_recurse.push(file.uri.clone());
                    }
                    result.push(file);
                }

                if let Some(token) = resp.pagination.next_page_token {
                    next_page_token = Some(token);
                } else if count < page_size as usize {
                    break;
                } else {
                    page += 1;
                }
            }

            for dir_uri in dirs_to_recurse {
                let mut retry = 0u32;
                loop {
                    match self.list_all_files_recursive(&dir_uri, result).await {
                        Ok(()) => break,
                        Err(e) => {
                            retry += 1;
                            if retry > 3 {
                                tracing::error!("递归列出目录失败，跳过: {}: {}", dir_uri, e);
                                break;
                            }
                            let delay = crate::utils::retry_delay_ms(retry, 2000, 30000);
                            tracing::warn!("递归列出目录失败 (重试 {}/3): {}: {}, {}ms后重试", retry, dir_uri, e, delay);
                            tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                        }
                    }
                }
            }

            Ok(())
        })
    }

    pub async fn list_files_page(
        &self,
        uri: &str,
        page: u32,
        page_size: u32,
        next_page_token: Option<&str>,
    ) -> Result<ListFilesResponse> {
        let max_retries = 3u32;
        let mut attempt = 0u32;
        loop {
            attempt += 1;
            match self.list_files_page_inner(uri, page, page_size, next_page_token).await {
                Ok(resp) => return Ok(resp),
                Err(SyncError::Auth(_)) => return Err(SyncError::Auth("Token 过期".into())),
                Err(e) if attempt <= max_retries => {
                    let delay = crate::utils::retry_delay_ms(attempt, 2000, 30000);
                    tracing::warn!(
                        "列出文件失败 (重试 {}/{}): uri={}, error={}, {}ms后重试",
                        attempt, max_retries, uri, e, delay,
                    );
                    tokio::time::sleep(std::time::Duration::from_millis(delay)).await;
                }
                Err(e) => return Err(e),
            }
        }
    }

    async fn list_files_page_inner(
        &self,
        uri: &str,
        page: u32,
        page_size: u32,
        next_page_token: Option<&str>,
    ) -> Result<ListFilesResponse> {
        let data = self.send_with_auth_retry(|token| {
            let mut req = self.client
                .get(format!("{}/file", self.base_url))
                .bearer_auth(&token)
                .query(&[
                    ("uri", uri),
                    ("page", &page.to_string()),
                    ("page_size", &page_size.to_string()),
                ]);
            if let Some(npt) = next_page_token {
                req = req.query(&[("next_page_token", npt)]);
            }
            req
        }).await?;

        let parent_uri = uri.to_string();
        let files: Vec<RemoteFileEntry> = if let Some(items) = data.get("files").and_then(|f| f.as_array()) {
            items.iter().filter_map(|obj| {
                let name_raw = obj.get("name")?.as_str()?.to_string();
                let name = percent_decode_str(&name_raw);
                let path_raw = obj.get("path").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let path = percent_decode_str(&path_raw);
                let entry_uri = if path_raw.is_empty() {
                    format!("{}/{}", parent_uri, name_raw)
                } else {
                    path_raw.clone()
                };
                let size = obj.get("size").and_then(|s| s.as_u64()).unwrap_or(0);
                let file_type = obj.get("type").and_then(|t| t.as_u64()).unwrap_or(0);
                let is_dir = file_type == 1;
                let file_id = obj.get("id").and_then(|s| s.as_str()).map(String::from);
                let created_at = obj.get("created_at").and_then(|t| t.as_str()).unwrap_or("");
                let updated_at = obj.get("updated_at").and_then(|t| t.as_str()).unwrap_or("");

                Some(RemoteFileEntry {
                    uri: entry_uri,
                    name,
                    size,
                    mtime_ms: parse_timestamp(updated_at),
                    hash: None,
                    is_dir,
                    file_id,
                    path,
                    created_at_ms: parse_timestamp(created_at),
                })
            }).collect()
        } else {
            tracing::warn!("API 响应中未找到 files 数组, data keys: {:?}", data.as_object().map(|m| m.keys().collect::<Vec<_>>()));
            Vec::new()
        };

        let pagination = data.get("pagination").cloned().unwrap_or_default();
        let next_token = pagination.get("next_page_token")
            .and_then(|t| t.as_str())
            .map(String::from);
        let is_cursor = pagination.get("is_cursor")
            .and_then(|c| c.as_bool())
            .unwrap_or(false);
        let total = pagination.get("total_items")
            .and_then(|t| t.as_u64())
            .or_else(|| pagination.get("total").and_then(|t| t.as_u64()));

        Ok(ListFilesResponse {
            files,
            pagination: Pagination {
                next_page_token: next_token,
                is_cursor,
                total,
            },
        })
    }

    // ===== 上传 =====

    pub async fn create_upload_session(
        &self,
        uri: &str,
        size: u64,
        overwrite: bool,
        last_modified: Option<i64>,
        mime_type: Option<&str>,
        policy_id: Option<&str>,
    ) -> Result<UploadSession> {
        let mut body = serde_json::json!({
            "uri": uri,
            "size": size,
        });
        if overwrite {
            body["entity_type"] = serde_json::Value::String("version".to_string());
        }
        if let Some(mtime) = last_modified {
            body["last_modified"] = serde_json::Value::Number(mtime.into());
        }
        if let Some(mime) = mime_type {
            body["mime_type"] = serde_json::Value::String(mime.to_string());
        }
        if let Some(pid) = policy_id {
            body["policy_id"] = serde_json::Value::String(pid.to_string());
        }

        let data = self.send_with_auth_retry(|token| {
            self.client
                .put(format!("{}/file/upload", self.base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        let session_id = data.get("session_id")
            .and_then(|s| s.as_str())
            .unwrap_or("")
            .to_string();
        let chunk_size = data.get("chunk_size")
            .and_then(|c| c.as_u64())
            .unwrap_or(10 * 1024 * 1024);
        let upload_urls: Vec<String> = data.get("upload_urls")
            .and_then(|u| u.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default();
        let storage_policy_type = data.get("storage_policy")
            .and_then(|sp| sp.get("type"))
            .and_then(|t| t.as_str())
            .unwrap_or("local")
            .to_string();
        let callback_secret = data.get("callback_secret")
            .and_then(|s| s.as_str())
            .unwrap_or("")
            .to_string();

        let file_name = uri.rsplit('/').next().unwrap_or(uri).to_string();

        tracing::info!(
            "[{}] 创建上传会话: policy={}, urls={}, chunk_size={}",
            file_name, storage_policy_type, upload_urls.len(), chunk_size,
        );

        Ok(UploadSession {
            session_id,
            chunk_size,
            upload_urls,
            storage_policy_type,
            callback_secret,
            file_name,
        })
    }

    pub async fn upload_chunk(
        &self,
        session: &UploadSession,
        index: u32,
        data: &[u8],
        file_size: u64,
        task_id: &str,
    ) -> Result<()> {
        if let Some(url) = session.chunk_upload_url(index as usize) {
            // 远程存储策略：直接上传到外部 URL（OneDrive/S3/OSS 等）
            self.upload_chunk_to_remote(url, data, index, file_size, session, task_id).await
        } else {
            // 本地存储策略：上传到 Cloudreve 服务端
            self.upload_chunk_local(&session.session_id, index, data).await
        }
    }

    /// 本地存储：上传分片到 /file/upload/{session_id}/{index}
    async fn upload_chunk_local(
        &self,
        session_id: &str,
        index: u32,
        data: &[u8],
    ) -> Result<()> {
        let chunk_data = data.to_vec();
        let content_len = data.len().to_string();
        self.send_with_auth_retry(|token| {
            self.client
                .post(format!(
                    "{}/file/upload/{}/{}",
                    self.base_url, session_id, index
                ))
                .bearer_auth(&token)
                .header("Content-Length", &content_len)
                .body(chunk_data.clone())
        }).await?;
        Ok(())
    }

    /// 远程存储：上传分片到外部 URL（OneDrive/S3 等），无需 Cloudreve token
    /// 必须带 Content-Range 头：bytes {start}-{end}/{total}
    async fn upload_chunk_to_remote(
        &self,
        url: &str,
        data: &[u8],
        index: u32,
        file_size: u64,
        session: &UploadSession,
        task_id: &str,
    ) -> Result<()> {
        let chunk_size = session.chunk_size;
        let file_name = &session.file_name;
        let start = index as u64 * chunk_size;
        let end = start + data.len() as u64 - 1;
        let content_range = format!("bytes {}-{}/{}", start, end, file_size);
        let content_len = data.len().to_string();

        tracing::debug!("[{}][{}] 远程存储上传分片 {}: Content-Range={}", task_id, file_name, index, content_range);

        let resp = self.client
            .put(url)
            .header("Content-Length", &content_len)
            .header("Content-Range", &content_range)
            .body(data.to_vec())
            .timeout(std::time::Duration::from_secs(300))
            .send()
            .await
            .map_err(|e| {
                tracing::warn!("[{}][{}] 远程存储上传失败: error={}", task_id, file_name, e);
                SyncError::from(e)
            })?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(SyncError::UploadFailed(format!(
                "远程存储返回 HTTP {}: {}",
                status,
                body.chars().take(200).collect::<String>()
            )));
        }

        // 202 = 分片已接收，上传未完成，继续下一个分片
        // 200/201 = 上传完成，文件已创建
        let status = resp.status();
        if status.as_u16() == 202 {
            tracing::debug!("[{}][{}] 远程存储分片 {} 已接收(202)，继续上传", task_id, file_name, index);
        } else if status.as_u16() == 200 || status.as_u16() == 201 {
            tracing::info!("[{}][{}] 远程存储上传完成({}), 分片 {}", task_id, file_name, status, index);
        }

        Ok(())
    }

    /// 远程存储上传完成后回调 Cloudreve 服务端
    /// POST /callback/{storage_policy_type}/{session_id}/{callback_secret}
    pub async fn callback_upload_complete(&self, session: &UploadSession, task_id: &str) -> Result<()> {
        if session.callback_secret.is_empty() {
            tracing::warn!("[{}][{}] 上传回调跳过: callback_secret 为空", task_id, session.file_name);
            return Ok(());
        }

        let url = format!(
            "{}/callback/{}/{}/{}",
            self.base_url,
            session.storage_policy_type,
            session.session_id,
            session.callback_secret,
        );
        tracing::info!("[{}][{}] 上传完成回调: policy={}, session={}", task_id, session.file_name, session.storage_policy_type, session.session_id);

        self.send_with_auth_retry(|token| {
            self.client
                .post(&url)
                .bearer_auth(&token)
        }).await?;

        tracing::info!("[{}][{}] 上传完成回调成功: policy={}, session={}", task_id, session.file_name, session.storage_policy_type, session.session_id);
        Ok(())
    }

    // ===== 下载 =====

    pub async fn get_download_url(&self, uris: &[&str]) -> Result<Vec<String>> {
        let body = serde_json::json!({
            "uris": uris,
            "download": false,
        });

        let data = self.send_with_auth_retry(|token| {
            self.client
                .post(format!("{}/file/url", self.base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        let urls = data.get("urls")
            .and_then(|u| u.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|item| item.get("url")?.as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        Ok(urls)
    }

    pub async fn stream_download(
        &self,
        url: &str,
        offset: u64,
    ) -> Result<reqwest::Response> {
        let mut req = self.download_client.get(url);
        if offset > 0 {
            req = req.header("Range", format!("bytes={}-", offset));
        }
        let resp = req.send().await?;
        Ok(resp)
    }

    // ===== 创建文件/目录 =====

    pub async fn create_directory(&self, parent_uri: &str, name: &str) -> Result<RemoteFileEntry> {
        let uri = format!("{}/{}", parent_uri, name);
        let body = serde_json::json!({
            "uri": uri,
            "type": "folder",
        });

        let _data = self.send_with_auth_retry(|token| {
            self.client
                .post(format!("{}/file/create", self.base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        Ok(RemoteFileEntry {
            uri,
            name: name.to_string(),
            size: 0,
            mtime_ms: 0,
            hash: None,
            is_dir: true,
            file_id: None,
            path: String::new(),
            created_at_ms: 0,
        })
    }

    // ===== 删除 =====

    pub async fn delete_files(&self, uris: &[&str]) -> Result<()> {
        let body = serde_json::json!({
            "uris": uris,
        });

        let result = self.send_with_auth_retry(|token| {
            let client = &self.client;
            let base_url = &self.base_url;
            let body = body.clone();
            client
                .delete(format!("{}/file", base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await;

        match result {
            Ok(_) => Ok(()),
            Err(SyncError::LockConflict { tokens }) => {
                for item in &tokens {
                    tracing::warn!(
                        "删除异常: code(40073), 进行解锁, token: {}, path: {}",
                        item.token, item.path
                    );
                }
                self.force_unlock_files(&tokens).await?;

                // 解锁后重试删除
                self.send_with_auth_retry(|token| {
                    let client = &self.client;
                    let base_url = &self.base_url;
                    let body = body.clone();
                    client
                        .delete(format!("{}/file", base_url))
                        .bearer_auth(&token)
                        .json(&body)
                }).await?;
                Ok(())
            }
            Err(e) => Err(e),
        }
    }

    /// 强制解锁文件 — DELETE /file/lock
    pub async fn force_unlock_files(&self, items: &[crate::errors::LockConflictItem]) -> Result<()> {
        let tokens: Vec<&str> = items.iter().map(|i| i.token.as_str()).collect();
        if tokens.is_empty() {
            return Ok(());
        }

        let body = serde_json::json!({
            "tokens": tokens,
        });

        self.send_with_auth_retry(|token| {
            let client = &self.client;
            let base_url = &self.base_url;
            let body = body.clone();
            client
                .delete(format!("{}/file/lock", base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        tracing::info!("强制解锁完成: {} 个文件", items.len());
        Ok(())
    }

    // ===== 移动 =====

    pub async fn move_files(&self, src_uris: &[&str], dst_uri: &str, copy: bool) -> Result<()> {
        let body = serde_json::json!({
            "uris": src_uris,
            "dst": dst_uri,
            "copy": copy,
        });

        self.send_with_auth_retry(|token| {
            self.client
                .post(format!("{}/file/move", self.base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        Ok(())
    }

    // ===== 重命名 =====

    pub async fn rename_file(&self, uri: &str, new_name: &str) -> Result<()> {
        let body = serde_json::json!({
            "uri": uri,
            "new_name": new_name,
        });

        self.send_with_auth_retry(|token| {
            self.client
                .post(format!("{}/file/rename", self.base_url))
                .bearer_auth(&token)
                .json(&body)
        }).await?;

        Ok(())
    }

    // ===== 获取文件信息 =====

    pub async fn get_file_info(&self, uri: &str) -> Result<RemoteFileEntry> {
        let data = self.send_with_auth_retry(|token| {
            self.client
                .get(format!("{}/file/info", self.base_url))
                .bearer_auth(&token)
                .query(&[("uri", uri)])
        }).await?;

        Ok(RemoteFileEntry {
            uri: data.get("uri").and_then(|u| u.as_str()).unwrap_or(uri).to_string(),
            name: percent_decode_str(data.get("name").and_then(|n| n.as_str()).unwrap_or("")),
            size: data.get("size").and_then(|s| s.as_u64()).unwrap_or(0),
            mtime_ms: data.get("updated_at").and_then(|t| t.as_str()).map(parse_timestamp).unwrap_or(0),
            hash: None,
            is_dir: data.get("type").and_then(|t| t.as_u64()).unwrap_or(0) == 1,
            file_id: data.get("id").and_then(|i| i.as_str()).map(String::from),
            path: percent_decode_str(data.get("path").and_then(|p| p.as_str()).unwrap_or("")),
            created_at_ms: data.get("created_at").and_then(|t| t.as_str()).map(parse_timestamp).unwrap_or(0),
        })
    }

    /// 幂等创建多级 Cloudreve 目录路径。
    ///
    /// 例：cloudreve://my/DCIM/Camera 会在缺失时依次创建 DCIM 和 Camera。
    /// 用于相册同步等需要保证深层目录存在的场景。
    pub async fn ensure_directory_path(&self, uri: &str) -> Result<()> {
        let normalized = uri.trim().trim_end_matches('/');
        let (root_uri, segments) = split_cloudreve_uri(normalized)?;
        if segments.is_empty() {
            return Ok(());
        }

        let mut parent_uri = root_uri;
        for segment in segments {
            if segment.is_empty() {
                continue;
            }

            if self.directory_child_exists(&parent_uri, segment).await? {
                parent_uri = format!("{}/{}", parent_uri, segment);
                continue;
            }

            match self.create_directory(&parent_uri, segment).await {
                Ok(_) => {
                    tracing::info!("创建云端目录: {}/{}", parent_uri, segment);
                }
                Err(SyncError::ObjectExisted) => {
                    tracing::debug!("云端目录已存在: {}/{}", parent_uri, segment);
                }
                Err(e) => return Err(e),
            }

            parent_uri = format!("{}/{}", parent_uri, segment);
        }

        Ok(())
    }

    async fn directory_child_exists(&self, parent_uri: &str, name: &str) -> Result<bool> {
        let page = self.list_files_page(parent_uri, 0, 2000, None).await?;
        Ok(page.files.iter().any(|f| f.is_dir && f.name == name))
    }
}

fn split_cloudreve_uri(uri: &str) -> Result<(String, Vec<&str>)> {
    const PREFIX: &str = "cloudreve://";
    if !uri.starts_with(PREFIX) {
        return Err(SyncError::Internal(format!("不支持的云端 URI: {}", uri)));
    }

    let rest = &uri[PREFIX.len()..];
    let mut parts = rest.split('/').filter(|part| !part.is_empty());
    let Some(root_name) = parts.next() else {
        return Err(SyncError::Internal(format!("无效的云端 URI: {}", uri)));
    };

    let root_uri = format!("{}{}", PREFIX, root_name);
    let segments = parts.collect::<Vec<_>>();
    Ok((root_uri, segments))
}

/// 解析 Cloudreve 时间戳 (ISO 8601 或 Unix ms)
fn parse_timestamp(s: &str) -> i64 {
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(s) {
        return dt.timestamp_millis();
    }
    if let Ok(ts) = s.parse::<i64>() {
        if ts < 10_000_000_000 {
            return ts * 1000;
        }
        return ts;
    }
    0
}

fn percent_decode_str(s: &str) -> String {
    urlencoding::decode(s).unwrap_or_else(|_| s.into()).to_string()
}
