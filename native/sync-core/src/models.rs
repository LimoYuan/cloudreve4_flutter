use serde::{Deserialize, Serialize};
use std::path::PathBuf;

// ===== 同步状态 =====

#[derive(Debug, Clone, PartialEq)]
pub enum SyncState {
    Idle,
    Initializing,
    InitialSync { progress: InitialSyncProgress },
    Continuous,
    Paused,
    Error { message: String },
    Stopped,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct InitialSyncProgress {
    pub scanned_local: u64,
    pub scanned_remote: u64,
    pub uploaded: u64,
    pub downloaded: u64,
    pub conflicts: u64,
    pub total_to_sync: u64,
}

// ===== 同步配置 =====

#[derive(Debug, Clone)]
pub struct SyncConfig {
    pub base_url: String,
    pub access_token: String,
    pub refresh_token: String,
    pub local_root: PathBuf,
    pub remote_root: String,
    pub sync_mode: SyncMode,
    pub conflict_strategy: ConflictStrategy,
    pub wcf_delete_mode: WcfDeleteMode,
    pub max_concurrent_transfers: usize,
    pub bandwidth_limit: Option<u64>,
    pub excluded_paths: Vec<String>,
    pub max_workers: usize,
    pub data_dir: PathBuf,
    pub client_id: String,
    /// FUSE 水合缓存大小上限（GB），默认 2，最小 1，最大 100
    pub max_hydration_cache_size_gb: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SyncMode {
    Full,
    UploadOnly,
    DownloadOnly,
    AlbumUpload,
    AlbumDownload,
    MirrorWcf,
}

// ===== 文件条目 =====

#[derive(Debug, Clone)]
pub struct LocalFileEntry {
    pub relative_path: PathBuf,
    pub size: u64,
    pub mtime_ms: i64,
    pub quick_hash: String,
    pub is_dir: bool,
    pub mime_type: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteFileEntry {
    pub uri: String,
    pub name: String,
    pub size: u64,
    pub mtime_ms: i64,
    pub hash: Option<String>,
    pub is_dir: bool,
    pub file_id: Option<String>,
    pub path: String,
    pub created_at_ms: i64,
}

// ===== 文件映射 =====

#[derive(Debug, Clone)]
pub struct FileMapping {
    pub id: i64,
    pub sync_root_id: String,
    pub local_path: PathBuf,
    pub remote_uri: String,
    pub remote_file_id: Option<String>,
    pub local_hash: Option<String>,
    pub remote_hash: Option<String>,
    pub local_mtime: Option<i64>,
    pub remote_mtime: Option<i64>,
    pub local_size: Option<u64>,
    pub remote_size: Option<u64>,
    pub sync_status: SyncFileStatus,
    pub is_placeholder: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SyncFileStatus {
    Synced,
    Uploading,
    Downloading,
    Conflict,
    Placeholder,
}

// ===== 冲突 =====

#[derive(Debug, Clone, PartialEq)]
pub enum ConflictType {
    BothModified,
    DeleteVsModify,
    NameCollision,
    TypeMismatch,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ConflictStrategy {
    KeepLocal,
    KeepRemote,
    KeepBoth,
    NewestWins,
    LargestWins,
    Manual,
}

/// 镜像同步(WCF)本地删除模式 — 仅 MirrorWcf 模式下生效
#[derive(Debug, Clone, PartialEq)]
pub enum WcfDeleteMode {
    /// 仅删除本地，保留远程（可重新水合）
    LocalOnly,
    /// 同步删除远程副本
    SyncRemote,
}

#[derive(Debug, Clone)]
pub enum ConflictResolution {
    UploadLocal,
    DownloadRemote,
    RenameLocal { new_name: String },
    DeleteLocal,
    DeleteRemote,
    MarkManual,
}

// ===== 传输 =====

#[derive(Debug, Clone)]
pub struct TransferTask {
    pub id: i64,
    pub sync_root_id: String,
    pub file_mapping_id: Option<i64>,
    pub direction: TransferDirection,
    pub local_path: PathBuf,
    pub remote_uri: String,
    pub file_size: u64,
    pub bytes_done: u64,
    pub status: TransferStatus,
    pub retry_count: u32,
    pub max_retries: u32,
    pub error_message: Option<String>,
    pub session_id: Option<String>,
    pub chunk_index: Option<u32>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TransferDirection {
    Upload,
    Download,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TransferStatus {
    Pending,
    Active,
    Paused,
    Completed,
    Failed,
}

#[derive(Debug, Clone)]
pub struct TransferConfig {
    pub max_concurrent: usize,
    pub max_retries: u32,
    pub retry_base_delay_ms: u64,
    pub retry_max_delay_ms: u64,
    pub bandwidth_limit: Option<u64>,
    pub disk_space_reserve: u64,
}

impl Default for TransferConfig {
    fn default() -> Self {
        Self {
            max_concurrent: 3,
            max_retries: 5,
            retry_base_delay_ms: 1000,
            retry_max_delay_ms: 60000,
            bandwidth_limit: None,
            disk_space_reserve: 1024 * 1024 * 1024,
        }
    }
}

// ===== 同步摘要 =====

#[derive(Debug, Clone, Default)]
pub struct SyncSummary {
    pub uploaded: u32,
    pub downloaded: u32,
    pub renamed: u32,
    pub moved: u32,
    pub conflicts: u32,
    pub failed: u32,
    pub skipped: u32,
    pub deleted_local: u32,
    pub deleted_remote: u32,
    pub duration_ms: u64,
}

// ===== 同步状态快照 =====

#[derive(Debug, Clone)]
pub struct SyncStatusSnapshot {
    pub state: SyncState,
    pub synced_files: u64,
    pub total_files: u64,
    pub uploading_count: u32,
    pub downloading_count: u32,
    pub conflict_count: u32,
    pub error_count: u32,
    pub last_sync_time: Option<String>,
    pub error_message: Option<String>,
}

// ===== 本地文件事件 =====

#[derive(Debug, Clone)]
pub enum LocalFileEvent {
    Created(Vec<PathBuf>),
    Modified(Vec<PathBuf>),
    Deleted(Vec<PathBuf>),
    Renamed {
        old_paths: Vec<PathBuf>,
        new_paths: Vec<PathBuf>,
    },
    Moved {
        old_paths: Vec<PathBuf>,
        new_paths: Vec<PathBuf>,
    },
}

impl LocalFileEvent {
    pub fn paths(&self) -> &[PathBuf] {
        match self {
            LocalFileEvent::Created(p) => p,
            LocalFileEvent::Modified(p) => p,
            LocalFileEvent::Deleted(p) => p,
            LocalFileEvent::Renamed { .. } | LocalFileEvent::Moved { .. } => &[],
        }
    }
}

// ===== 远程文件事件 =====

#[derive(Debug, Clone)]
pub enum RemoteFileEvent {
    Created(RemoteFileEntry),
    Modified(RemoteFileEntry),
    Deleted {
        uri: String,
        name: String,
    },
    Renamed {
        old_uri: String,
        new_entry: RemoteFileEntry,
    },
    Moved {
        old_uri: String,
        new_entry: RemoteFileEntry,
    },
}

// ===== 平台回调事件 (Windows CFApi) =====

#[derive(Debug, Clone)]
pub enum PlatformCallbackEvent {
    HydrateRequested {
        local_path: String,
        transfer_key: i64,
    },
}

// ===== 上传会话 =====

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadSession {
    pub session_id: String,
    pub chunk_size: u64,
    /// 远程存储的上传 URL 列表（每个分片一个 URL）
    /// 仅当 storage_policy_type != "local" 时有值
    pub upload_urls: Vec<String>,
    /// 存储策略类型：local / onedrive / s3 / oss / cos / etc.
    pub storage_policy_type: String,
    /// 回调密钥（远程存储上传完成后需要回调通知服务端）
    pub callback_secret: String,
    /// 上传文件名（仅用于日志标识，并发时区分不同文件）
    pub file_name: String,
}

impl UploadSession {
    /// 是否使用远程存储直接上传（非本地策略）
    pub fn is_remote_storage(&self) -> bool {
        self.storage_policy_type != "local" && !self.upload_urls.is_empty()
    }

    /// 获取第 index 个分片的上传 URL
    /// 远程存储：返回 upload_urls[index]（不足则用最后一个）
    /// 本地存储：返回 None，由调用方拼接 /file/upload/{session_id}/{index}
    pub fn chunk_upload_url(&self, index: usize) -> Option<&str> {
        if !self.is_remote_storage() {
            return None;
        }
        if self.upload_urls.is_empty() {
            return None;
        }
        Some(self.upload_urls[index.min(self.upload_urls.len() - 1)].as_str())
    }
}

// ===== API 分页响应 =====

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ListFilesResponse {
    pub files: Vec<RemoteFileEntry>,
    pub pagination: Pagination,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pagination {
    pub next_page_token: Option<String>,
    pub is_cursor: bool,
    pub total: Option<u64>,
}

// ===== 同步计划 =====

/// 重命名操作（本地触发 → 远程重命名，同目录下改文件名）
#[derive(Debug, Clone)]
pub struct RenameAction {
    pub old_relative_path: String,
    pub new_relative_path: String,
    pub remote_uri: String,
    pub new_name: String,
}

/// 移动操作（本地触发 → 远程移动，跨目录）
#[derive(Debug, Clone)]
pub struct MoveAction {
    pub old_relative_path: String,
    pub new_relative_path: String,
    pub remote_uri: String,
    pub dst_remote_dir_uri: String,
}

/// 本地重命名/移动操作（远程触发 → 本地执行）
#[derive(Debug, Clone)]
pub struct LocalRenameAction {
    pub old_relative_path: String,
    pub new_relative_path: String,
    pub new_remote_uri: String,
}

#[derive(Debug, Clone, Default)]
pub struct SyncPlan {
    pub uploads: Vec<SyncAction>,
    pub downloads: Vec<SyncAction>,
    pub delete_local: Vec<SyncAction>,
    pub delete_remote: Vec<SyncAction>,
    pub rename_remote: Vec<RenameAction>,
    pub move_remote: Vec<MoveAction>,
    pub rename_local: Vec<LocalRenameAction>,
    pub move_local: Vec<LocalRenameAction>,
    pub conflicts: Vec<SyncConflict>,
    pub mkdirs_local: Vec<String>,
    pub mkdirs_remote: Vec<String>,
    /// 需要递归扫描的顶层目录（持续同步场景，目录整体提交给 Worker）
    pub scan_dirs: Vec<String>,
}

impl SyncPlan {
    /// 判断是否有实际操作需要执行（含 scan_dirs 则为非空，因为扫描可能发现新文件）
    pub fn has_work(&self) -> bool {
        !self.uploads.is_empty()
            || !self.downloads.is_empty()
            || !self.delete_local.is_empty()
            || !self.delete_remote.is_empty()
            || !self.rename_remote.is_empty()
            || !self.move_remote.is_empty()
            || !self.rename_local.is_empty()
            || !self.move_local.is_empty()
            || !self.conflicts.is_empty()
            || !self.scan_dirs.is_empty()
    }
}

#[derive(Debug, Clone)]
pub struct SyncAction {
    pub relative_path: String,
    pub local_entry: Option<LocalFileEntry>,
    pub remote_entry: Option<RemoteFileEntry>,
    pub db_mapping: Option<FileMapping>,
}

#[derive(Debug, Clone)]
pub struct SyncConflict {
    pub relative_path: String,
    pub conflict_type: ConflictType,
    pub local_entry: Option<LocalFileEntry>,
    pub remote_entry: Option<RemoteFileEntry>,
    pub db_mapping: Option<FileMapping>,
}

impl SyncPlan {
    pub fn total_actions(&self) -> u64 {
        self.uploads.len() as u64
            + self.downloads.len() as u64
            + self.delete_local.len() as u64
            + self.delete_remote.len() as u64
            + self.rename_remote.len() as u64
            + self.move_remote.len() as u64
    }
}

// ===== Worker / Task 类型 =====

/// Worker 配置快照 — 创建时一次性读取，运行中不读任何锁
#[derive(Debug, Clone)]
pub struct WorkerConfig {
    pub local_root: PathBuf,
    pub remote_root: String,
    pub max_concurrent_transfers: usize,
    pub bandwidth_limit: Option<u64>,
    pub conflict_strategy: ConflictStrategy,
    pub wcf_delete_mode: WcfDeleteMode,
    pub sync_root_id: String,
    pub sync_mode: SyncMode,
}

/// Worker 触发来源
#[derive(Debug, Clone, PartialEq)]
pub enum WorkerTrigger {
    InitialSync,
    Continuous,
    Manual,
    /// WCF 按需水合
    Hydration,
    /// WCF 远程事件（占位符/删除/重命名/移动）
    WcfEvent,
}

impl WorkerTrigger {
    pub fn as_str(&self) -> &'static str {
        match self {
            WorkerTrigger::InitialSync => "initial_sync",
            WorkerTrigger::Continuous => "continuous",
            WorkerTrigger::Manual => "manual",
            WorkerTrigger::Hydration => "hydration",
            WorkerTrigger::WcfEvent => "wcf_event",
        }
    }
}

/// Worker 级别状态
#[derive(Debug, Clone, PartialEq)]
pub enum WorkerStatus {
    Pending,
    Running,
    Paused,
    Completed,
    Failed,
    Cancelled,
}

impl WorkerStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            WorkerStatus::Pending => "pending",
            WorkerStatus::Running => "running",
            WorkerStatus::Paused => "paused",
            WorkerStatus::Completed => "completed",
            WorkerStatus::Failed => "failed",
            WorkerStatus::Cancelled => "cancelled",
        }
    }
}

impl std::str::FromStr for WorkerStatus {
    type Err = ();

    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s {
            "pending" => Ok(WorkerStatus::Pending),
            "running" => Ok(WorkerStatus::Running),
            "paused" => Ok(WorkerStatus::Paused),
            "completed" => Ok(WorkerStatus::Completed),
            "failed" => Ok(WorkerStatus::Failed),
            "cancelled" => Ok(WorkerStatus::Cancelled),
            _ => Err(()),
        }
    }
}

/// 单文件操作状态
#[derive(Debug, Clone, PartialEq)]
pub enum TaskItemStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Skipped,
}

impl TaskItemStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskItemStatus::Pending => "pending",
            TaskItemStatus::Running => "running",
            TaskItemStatus::Completed => "completed",
            TaskItemStatus::Failed => "failed",
            TaskItemStatus::Skipped => "skipped",
        }
    }
}

impl std::str::FromStr for TaskItemStatus {
    type Err = ();

    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s {
            "pending" => Ok(TaskItemStatus::Pending),
            "running" => Ok(TaskItemStatus::Running),
            "completed" => Ok(TaskItemStatus::Completed),
            "failed" => Ok(TaskItemStatus::Failed),
            "skipped" => Ok(TaskItemStatus::Skipped),
            _ => Err(()),
        }
    }
}

/// 操作类型 — 精确记录每个文件的操作
#[derive(Debug, Clone, PartialEq)]
pub enum TaskActionType {
    Upload,
    Download,
    DeleteLocal,
    DeleteRemote,
    Rename,
    Move,
    MkdirRemote,
    MkdirLocal,
    ConflictResolve,
    CreatePlaceholder,
    /// WCF 按需水合（用户打开占位符文件时触发下载）
    Hydration,
}

impl TaskActionType {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskActionType::Upload => "upload",
            TaskActionType::Download => "download",
            TaskActionType::DeleteLocal => "delete_local",
            TaskActionType::DeleteRemote => "delete_remote",
            TaskActionType::Rename => "rename",
            TaskActionType::Move => "move",
            TaskActionType::MkdirRemote => "mkdir_remote",
            TaskActionType::MkdirLocal => "mkdir_local",
            TaskActionType::ConflictResolve => "conflict_resolve",
            TaskActionType::CreatePlaceholder => "create_placeholder",
            TaskActionType::Hydration => "hydration",
        }
    }
}

impl std::str::FromStr for TaskActionType {
    type Err = ();

    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s {
            "upload" => Ok(TaskActionType::Upload),
            "download" => Ok(TaskActionType::Download),
            "delete_local" => Ok(TaskActionType::DeleteLocal),
            "delete_remote" => Ok(TaskActionType::DeleteRemote),
            "rename" => Ok(TaskActionType::Rename),
            "move" => Ok(TaskActionType::Move),
            "mkdir_remote" => Ok(TaskActionType::MkdirRemote),
            "mkdir_local" => Ok(TaskActionType::MkdirLocal),
            "conflict_resolve" => Ok(TaskActionType::ConflictResolve),
            "create_placeholder" => Ok(TaskActionType::CreatePlaceholder),
            "hydration" => Ok(TaskActionType::Hydration),
            _ => Err(()),
        }
    }
}

/// Worker 级别的任务摘要 — DB 持久化，供 UI 查询
#[derive(Debug, Clone)]
pub struct SyncTask {
    pub id: String,
    pub trigger: WorkerTrigger,
    pub total_count: u32,
    pub completed_count: u32,
    pub failed_count: u32,
    pub status: WorkerStatus,
    pub created_at: String,
    pub updated_at: String,
    pub finished_at: Option<String>,
}

/// 单文件操作记录 — DB 持久化，支持多维度查询
#[derive(Debug, Clone)]
pub struct SyncTaskItem {
    pub id: i64,
    pub task_id: String,
    pub relative_path: String,
    pub action_type: TaskActionType,
    pub status: TaskItemStatus,
    pub file_size: u64,
    pub error_message: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 累积统计（从 DB 聚合，跨所有同步任务）
#[derive(Debug, Clone, Default)]
pub struct SyncCumStats {
    pub uploaded: u32,
    pub downloaded: u32,
    pub renamed: u32,
    pub moved: u32,
    pub failed: u32,
    pub conflicts: u32,
    pub deleted_local: u32,
    pub deleted_remote: u32,
    pub skipped: u32,
}

/// 任务项查询过滤器
#[derive(Debug, Clone, Default)]
pub struct TaskItemFilter {
    pub task_id: Option<String>,
    pub relative_path_contains: Option<String>,
    pub action_type: Option<String>,
    pub status: Option<String>,
    pub limit: u32,
    pub offset: u32,
}

// ===== 云端相册检查结果 =====

#[derive(Debug, Clone)]
pub struct CloudAlbumCheckResult {
    pub dcim_exists: bool,
    pub pictures_exists: bool,
    pub dcim_uri: Option<String>,
    pub pictures_uri: Option<String>,
    pub camera_exists: bool,
    pub camera_uri: Option<String>,
}
