/// Windows Cloud Filter API 平台适配器
/// 仅在 windows-cfapi feature 启用时编译
#[cfg(feature = "windows-cfapi")]
use std::path::Path;
#[cfg(feature = "windows-cfapi")]
use std::sync::Arc;
#[cfg(feature = "windows-cfapi")]
use tokio::sync::mpsc;

#[cfg(feature = "windows-cfapi")]
use crate::api_client::ApiClient;
#[cfg(feature = "windows-cfapi")]
use crate::errors::Result;
#[cfg(feature = "windows-cfapi")]
use crate::models::SyncConfig;
#[cfg(feature = "windows-cfapi")]
use crate::sync_db::SyncDb;
#[cfg(feature = "windows-cfapi")]
use crate::utils::lock_recover;
#[cfg(feature = "windows-cfapi")]
use crate::worker::PlaceholderCreator;

#[cfg(feature = "windows-cfapi")]
pub struct WcfPlatformAdapter {
    adapter: std::sync::Mutex<sync_windows::WindowsAdapter>,
    fetch_rx: std::sync::Mutex<Option<mpsc::Receiver<sync_windows::FetchDataRequest>>>,
    #[allow(dead_code)]
    db: Arc<SyncDb>,
    #[allow(dead_code)]
    api: Arc<ApiClient>,
    #[allow(dead_code)]
    config: SyncConfig,
}

#[cfg(feature = "windows-cfapi")]
impl WcfPlatformAdapter {
    pub fn new(
        db: Arc<SyncDb>,
        api: Arc<ApiClient>,
        config: SyncConfig,
    ) -> anyhow::Result<Self> {
        let mut adapter = sync_windows::WindowsAdapter::new();

        // 注册同步根目录
        adapter.register_sync_root(
            &config.local_root,
            "Cloudreve4",
            "1.0",
        )?;

        // 连接同步根，注册回调
        adapter.connect_sync_root(&config.local_root)?;
        let fetch_rx = adapter.take_callback_receiver();

        tracing::info!("WcfPlatformAdapter 初始化完成: {}", config.local_root.display());

        Ok(Self {
            adapter: std::sync::Mutex::new(adapter),
            fetch_rx: std::sync::Mutex::new(fetch_rx),
            db,
            api,
            config,
        })
    }

    /// 取走 FETCH_DATA 回调接收端（供 SyncEngine 持续同步消费）
    pub fn take_fetch_receiver(&self) -> Option<mpsc::Receiver<sync_windows::FetchDataRequest>> {
        lock_recover(&self.fetch_rx).take()
    }

    /// 创建占位符文件
    pub fn create_placeholder_for_remote(
        &self,
        base_dir: &Path,
        file_name: &str,
        file_size: u64,
        remote_uri: &str,
        remote_hash: Option<&str>,
        remote_mtime_ms: i64,
    ) -> Result<()> {
        let file_identity = serde_json::to_vec(&serde_json::json!({
            "uri": remote_uri,
            "size": file_size,
            "hash": remote_hash.unwrap_or(""),
            "mtime_ms": remote_mtime_ms,
        })).unwrap_or_default();

        lock_recover(&self.adapter).create_single_placeholder(
            base_dir,
            file_name,
            file_size,
            &file_identity,
        ).map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))?;

        Ok(())
    }

    /// 水合文件（按需下载）
    pub fn hydrate_file(&self, local_path: &Path) -> Result<()> {
        lock_recover(&self.adapter).hydrate_placeholder(local_path)
            .map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }

    /// 脱水文件（释放本地空间）
    pub fn dehydrate_file(&self, local_path: &Path) -> Result<()> {
        lock_recover(&self.adapter).dehydrate_placeholder(local_path)
            .map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }

    /// 通过 CfExecute 将数据推送回 CFApi（内核层写入，绕过文件锁）
    pub fn fulfill_fetch_data(
        connection_key: i64,
        transfer_key: i64,
        data: &[u8],
        offset: i64,
    ) -> Result<()> {
        sync_windows::WindowsAdapter::fulfill_fetch_data(connection_key, transfer_key, data, offset)
            .map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }

    /// 通过 CfExecute 报告水合失败
    pub fn reject_fetch_data(
        connection_key: i64,
        transfer_key: i64,
    ) -> Result<()> {
        sync_windows::WindowsAdapter::reject_fetch_data(connection_key, transfer_key)
            .map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }

    /// 断开连接
    pub fn disconnect(&self) -> Result<()> {
        lock_recover(&self.adapter).disconnect()
            .map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }
}

#[cfg(feature = "windows-cfapi")]
#[async_trait::async_trait]
impl PlaceholderCreator for WcfPlatformAdapter {
    async fn create_placeholder_file(
        &self,
        base_dir: &Path,
        file_name: String,
        file_size: u64,
        file_identity: &[u8],
    ) -> Result<()> {
        lock_recover(&self.adapter).create_single_placeholder(
            base_dir,
            &file_name,
            file_size,
            file_identity,
        ).map_err(|e| crate::errors::SyncError::FileSystem(e.to_string()))
    }
}
