/// FFI 错误类型
#[derive(Debug, Clone)]
pub enum SyncErrorFfi {
    NotInitialized,
    NetworkError { message: String },
    DiskFull { needed: u64, available: u64 },
    AuthError { message: String },
    ConflictError { count: u32 },
    InternalError { message: String },
}

/// 同步配置
#[derive(Debug, Clone)]
pub struct SyncConfigFfi {
    pub base_url: String,
    pub access_token: String,
    pub refresh_token: String,
    pub local_root: String,
    pub remote_root: String,
    pub sync_mode: String,
    pub conflict_strategy: String,
    pub wcf_delete_mode: String,
    pub max_concurrent_transfers: u32,
    pub bandwidth_limit_kbps: u64,
    pub excluded_paths: Vec<String>,
    pub max_workers: u32,
    pub data_dir: String,
    pub client_id: String,
    pub log_level: String,
    /// FUSE 水合缓存大小上限（GB），默认 2
    pub max_hydration_cache_size_gb: u32,
}

/// 同步状态快照
#[derive(Debug, Clone)]
pub struct SyncStatusFfi {
    pub state: String,
    pub synced_files: u64,
    pub total_files: u64,
    pub uploading_count: u32,
    pub downloading_count: u32,
    pub conflict_count: u32,
    pub error_count: u32,
    pub last_sync_time: Option<String>,
    pub error_message: Option<String>,
}

/// 初始同步摘要
#[derive(Debug, Clone)]
pub struct SyncSummaryFfi {
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

/// 同步事件（Rust → Dart 推送）
#[derive(Debug, Clone)]
pub enum SyncEventFfi {
    StateChanged { new_state: String },
    Progress {
        synced: u64,
        total: u64,
        current_file: String,
    },
    FileUploaded {
        local_path: String,
        remote_uri: String,
    },
    FileDownloaded {
        local_path: String,
        remote_uri: String,
    },
    ConflictDetected {
        local_path: String,
        conflict_type: String,
    },
    Error {
        message: String,
        recoverable: bool,
    },
    TokenExpired,
    DiskSpaceWarning { available_mb: u64 },
    InitialSyncComplete { summary: SyncSummaryFfi },

    // Worker 事件
    WorkerStarted {
        task_id: String,
        trigger: String,
        upload_count: u32,
        download_count: u32,
    },
    WorkerCompleted {
        task_id: String,
        uploaded: u32,
        downloaded: u32,
        renamed: u32,
        moved: u32,
        failed: u32,
        duration_ms: u64,
    },
    WorkerFailed {
        task_id: String,
        message: String,
    },
    TaskItemUpdated {
        task_id: String,
        relative_path: String,
        action: String,
        status: String,
    },
}

/// Android: 云端相册目录检查结果
#[derive(Debug, Clone)]
pub struct CloudAlbumCheckResultFfi {
    pub dcim_exists: bool,
    pub pictures_exists: bool,
    pub dcim_uri: Option<String>,
    pub pictures_uri: Option<String>,
    pub camera_exists: bool,
    pub camera_uri: Option<String>,
}

/// 同步任务摘要（FFI）
#[derive(Debug, Clone)]
pub struct SyncTaskFfi {
    pub id: String,
    pub trigger: String,
    pub total_count: u32,
    pub completed_count: u32,
    pub failed_count: u32,
    pub status: String,
    pub created_at: String,
    pub updated_at: String,
    pub finished_at: Option<String>,
}

/// 同步任务项（FFI）
#[derive(Debug, Clone)]
pub struct SyncTaskItemFfi {
    pub id: i64,
    pub task_id: String,
    pub relative_path: String,
    pub action_type: String,
    pub status: String,
    pub file_size: u64,
    pub error_message: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 累积统计（FFI）
#[derive(Debug, Clone)]
pub struct SyncCumStatsFfi {
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

/// 任务项查询过滤器（FFI）
#[derive(Debug, Clone)]
pub struct TaskItemFilterFfi {
    pub task_id: Option<String>,
    pub relative_path_contains: Option<String>,
    pub action_type: Option<String>,
    pub status: Option<String>,
    pub limit: u32,
    pub offset: u32,
}
