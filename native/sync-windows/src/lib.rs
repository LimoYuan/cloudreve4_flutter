#![cfg(target_os = "windows")]

//! Windows 平台适配层 - Cloud Filter API (CFApi) 集成

use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::io::AsRawHandle;
use std::path::Path;
use tokio::sync::mpsc;

use windows::core::*;
use windows::Win32::Foundation::*;
use windows::Win32::Storage::CloudFilters::*;
use windows::Win32::Storage::FileSystem::*;

/// 全局回调通道发送端（CFApi 回调 → 异步运行时）
/// 使用 Mutex 包装以支持重连时替换
static CALLBACK_SENDER: std::sync::Mutex<Option<mpsc::Sender<FetchDataRequest>>> =
    std::sync::Mutex::new(None);

/// CFApi FETCH_DATA 回调请求数据
#[derive(Debug, Clone)]
pub struct FetchDataRequest {
    pub connection_key: i64,
    pub transfer_key: i64,
    pub file_identity: Vec<u8>,
    pub required_offset: i64,
    pub required_length: i64,
}

pub struct WindowsAdapter {
    connection_key: Option<CF_CONNECTION_KEY>,
    callback_rx: Option<mpsc::Receiver<FetchDataRequest>>,
}

/// 占位符创建信息
#[derive(Debug, Clone)]
pub struct PlaceholderEntry {
    pub relative_path: String,
    pub file_size: u64,
    pub is_dir: bool,
    pub file_identity: Vec<u8>,
}

impl Default for WindowsAdapter {
    fn default() -> Self {
        Self::new()
    }
}

impl WindowsAdapter {
    pub fn new() -> Self {
        Self {
            connection_key: None,
            callback_rx: None,
        }
    }

    /// 注册同步根目录（先清理残留注册）
    pub fn register_sync_root(
        &self,
        root_path: &Path,
        provider_name: &str,
        provider_version: &str,
    ) -> anyhow::Result<()> {
        unsafe {
            let sync_root_path = to_pcwstr(root_path);

            // 先尝试注销残留的同步根（忽略未注册的错误）
            let unregister_result = CfUnregisterSyncRoot(PCWSTR(sync_root_path.as_ptr()));
            if let Err(e) = unregister_result {
                tracing::debug!("注销旧同步根（可忽略）: {}", e);
            }

            let provider_name_w = to_pcwstr_str(provider_name);
            let provider_version_w = to_pcwstr_str(provider_version);

            let provider_name_pcw = PCWSTR(provider_name_w.as_ptr());
            let provider_version_pcw = PCWSTR(provider_version_w.as_ptr());

            let provider_id = GUID::from_values(
                0x4E_5F_8C_D7, 0xA2_B1, 0x43_9F, [0x8C, 0x12, 0xD5, 0xE7, 0xF3, 0x21, 0x9A, 0xB4],
            );

            let root_identity = b"cloudreve-sync-root".to_vec();

            let registration = CF_SYNC_REGISTRATION {
                StructSize: std::mem::size_of::<CF_SYNC_REGISTRATION>() as u32,
                ProviderName: provider_name_pcw,
                ProviderVersion: provider_version_pcw,
                SyncRootIdentity: root_identity.as_ptr() as *const std::os::raw::c_void,
                SyncRootIdentityLength: root_identity.len() as u32,
                FileIdentity: std::ptr::null(),
                FileIdentityLength: 0,
                ProviderId: provider_id,
            };

            let policies = CF_SYNC_POLICIES {
                StructSize: std::mem::size_of::<CF_SYNC_POLICIES>() as u32,
                Hydration: CF_HYDRATION_POLICY {
                    Primary: CF_HYDRATION_POLICY_PARTIAL,
                    Modifier: CF_HYDRATION_POLICY_MODIFIER_NONE,
                },
                Population: CF_POPULATION_POLICY {
                    Primary: CF_POPULATION_POLICY_ALWAYS_FULL,
                    Modifier: CF_POPULATION_POLICY_MODIFIER_NONE,
                },
                InSync: CF_INSYNC_POLICY_NONE,
                HardLink: CF_HARDLINK_POLICY_NONE,
                PlaceholderManagement: CF_PLACEHOLDER_MANAGEMENT_POLICY_DEFAULT,
            };

            CfRegisterSyncRoot(
                PCWSTR(sync_root_path.as_ptr()),
                &registration,
                &policies,
                CF_REGISTER_FLAG_UPDATE,
            )?;

            tracing::info!("同步根已注册: {}", root_path.display());
            Ok(())
        }
    }

    /// 连接同步根，注册回调（先断开残留连接）
    pub fn connect_sync_root(&mut self, root_path: &Path) -> anyhow::Result<()> {
        // 先断开残留的旧连接
        if let Some(key) = self.connection_key.take() {
            unsafe {
                let _ = CfDisconnectSyncRoot(key);
            }
            tracing::debug!("已断开旧的同步根连接");
        }

        let (tx, rx) = mpsc::channel(256);
        // 替换全局回调发送端
        {
            let mut guard = CALLBACK_SENDER.lock().unwrap_or_else(|p| p.into_inner());
            *guard = Some(tx);
        }

        unsafe {
            let sync_root_path = to_pcwstr(root_path);

            let callbacks = [
                CF_CALLBACK_REGISTRATION {
                    Type: CF_CALLBACK_TYPE_FETCH_DATA,
                    Callback: Some(cf_fetch_data_callback),
                },
                CF_CALLBACK_REGISTRATION {
                    Type: CF_CALLBACK_TYPE_CANCEL_FETCH_DATA,
                    Callback: Some(cf_cancel_fetch_callback),
                },
                CF_CALLBACK_REGISTRATION {
                    Type: CF_CALLBACK_TYPE_NONE,
                    Callback: None,
                },
            ];

            let connection_key = CfConnectSyncRoot(
                PCWSTR(sync_root_path.as_ptr()),
                callbacks.as_ptr(),
                None,
                CF_CONNECT_FLAG_NONE,
            )?;

            self.connection_key = Some(connection_key);
            self.callback_rx = Some(rx);

            tracing::info!("同步根已连接: {}", root_path.display());
        }

        Ok(())
    }

    /// 取走回调接收端（供 sync-core 消费）
    pub fn take_callback_receiver(&mut self) -> Option<mpsc::Receiver<FetchDataRequest>> {
        self.callback_rx.take()
    }

    /// 创建占位符文件（批量）
    pub fn create_placeholders(
        &self,
        base_dir: &Path,
        entries: &[PlaceholderEntry],
    ) -> anyhow::Result<u32> {
        if entries.is_empty() {
            return Ok(0);
        }

        unsafe {
            let base_path = to_pcwstr(base_dir);

            let mut placeholders: Vec<CF_PLACEHOLDER_CREATE_INFO> = entries
                .iter()
                .map(|entry| {
                    let relative_name_w = to_pcwstr_str(&entry.relative_path);
                    let file_attributes = if entry.is_dir {
                        FILE_ATTRIBUTE_DIRECTORY.0
                    } else {
                        FILE_ATTRIBUTE_NORMAL.0
                    };

                    CF_PLACEHOLDER_CREATE_INFO {
                        RelativeFileName: PCWSTR(relative_name_w.as_ptr()),
                        FsMetadata: CF_FS_METADATA {
                            BasicInfo: FILE_BASIC_INFO {
                                CreationTime: 0,
                                LastAccessTime: 0,
                                LastWriteTime: 0,
                                ChangeTime: 0,
                                FileAttributes: file_attributes,
                            },
                            FileSize: entry.file_size as i64,
                        },
                        FileIdentity: entry.file_identity.as_ptr() as *const std::os::raw::c_void,
                        FileIdentityLength: entry.file_identity.len() as u32,
                        Flags: CF_PLACEHOLDER_CREATE_FLAG_NONE,
                        Result: S_OK,
                        CreateUsn: 0,
                    }
                })
                .collect();

            let mut entries_processed: u32 = 0;

            CfCreatePlaceholders(
                PCWSTR(base_path.as_ptr()),
                &mut placeholders,
                CF_CREATE_FLAG_NONE,
                Some(&mut entries_processed),
            )?;

            tracing::debug!("创建占位符: {} 个", entries_processed);
            Ok(entries_processed)
        }
    }

    /// 创建单个占位符文件
    pub fn create_single_placeholder(
        &self,
        base_dir: &Path,
        file_name: &str,
        file_size: u64,
        file_identity: &[u8],
    ) -> anyhow::Result<()> {
        let entry = PlaceholderEntry {
            relative_path: file_name.to_string(),
            file_size,
            is_dir: false,
            file_identity: file_identity.to_vec(),
        };
        self.create_placeholders(base_dir, &[entry])?;
        Ok(())
    }

    /// 水合文件
    pub fn hydrate_placeholder(&self, file_path: &Path) -> anyhow::Result<()> {
        unsafe {
            let file = std::fs::File::open(file_path)?;
            let handle = HANDLE(file.as_raw_handle() as *mut _);

            CfHydratePlaceholder(
                handle,
                0,
                -1i64,
                CF_HYDRATE_FLAG_NONE,
                None,
            )?;

            tracing::debug!("水合完成: {}", file_path.display());
            Ok(())
        }
    }

    /// 脱水文件
    pub fn dehydrate_placeholder(&self, file_path: &Path) -> anyhow::Result<()> {
        unsafe {
            let file = std::fs::File::open(file_path)?;
            let handle = HANDLE(file.as_raw_handle() as *mut _);

            CfDehydratePlaceholder(
                handle,
                0,
                -1i64,
                CF_DEHYDRATE_FLAG_NONE,
                None,
            )?;

            tracing::debug!("脱水完成: {}", file_path.display());
            Ok(())
        }
    }

    /// 断开同步根连接
    pub fn disconnect(&mut self) -> anyhow::Result<()> {
        if let Some(key) = self.connection_key.take() {
            unsafe {
                CfDisconnectSyncRoot(key)?;
            }
            tracing::info!("同步根已断开");
        }
        self.callback_rx = None;
        Ok(())
    }

    /// 通过 CfExecute 将数据推送回 CFApi 完成水合
    /// 这是由内核层写入文件，绕过应用锁
    pub fn fulfill_fetch_data(
        connection_key: i64,
        transfer_key: i64,
        data: &[u8],
        offset: i64,
    ) -> anyhow::Result<()> {
        unsafe {
            let op_info = CF_OPERATION_INFO {
                StructSize: std::mem::size_of::<CF_OPERATION_INFO>() as u32,
                Type: CF_OPERATION_TYPE_TRANSFER_DATA,
                ConnectionKey: CF_CONNECTION_KEY(connection_key),
                TransferKey: transfer_key,
                CorrelationVector: std::ptr::null(),
                SyncStatus: std::ptr::null(),
                RequestKey: 0,
            };

            let mut op_params = CF_OPERATION_PARAMETERS {
                ParamSize: std::mem::size_of::<CF_OPERATION_PARAMETERS>() as u32,
                Anonymous: CF_OPERATION_PARAMETERS_0 {
                    TransferData: CF_OPERATION_PARAMETERS_0_6 {
                        Flags: CF_OPERATION_TRANSFER_DATA_FLAG_NONE,
                        CompletionStatus: NTSTATUS(0), // STATUS_SUCCESS
                        Buffer: data.as_ptr() as *const core::ffi::c_void,
                        Offset: offset,
                        Length: data.len() as i64,
                    },
                },
            };

            CfExecute(&op_info, &mut op_params)?;
            tracing::debug!("CfExecute TRANSFER_DATA 成功: offset={}, len={}", offset, data.len());
            Ok(())
        }
    }

    /// 通过 CfExecute 报告水合失败
    pub fn reject_fetch_data(
        connection_key: i64,
        transfer_key: i64,
    ) -> anyhow::Result<()> {
        unsafe {
            let op_info = CF_OPERATION_INFO {
                StructSize: std::mem::size_of::<CF_OPERATION_INFO>() as u32,
                Type: CF_OPERATION_TYPE_TRANSFER_DATA,
                ConnectionKey: CF_CONNECTION_KEY(connection_key),
                TransferKey: transfer_key,
                CorrelationVector: std::ptr::null(),
                SyncStatus: std::ptr::null(),
                RequestKey: 0,
            };

            let mut op_params = CF_OPERATION_PARAMETERS {
                ParamSize: std::mem::size_of::<CF_OPERATION_PARAMETERS>() as u32,
                Anonymous: CF_OPERATION_PARAMETERS_0 {
                    TransferData: CF_OPERATION_PARAMETERS_0_6 {
                        Flags: CF_OPERATION_TRANSFER_DATA_FLAG_NONE,
                        CompletionStatus: NTSTATUS(0xC000_0001_u32 as i32), // STATUS_UNSUCCESSFUL
                        Buffer: std::ptr::null(),
                        Offset: 0,
                        Length: 0,
                    },
                },
            };

            CfExecute(&op_info, &mut op_params)?;
            Ok(())
        }
    }
}

/// CFApi 回调：水合请求 — 将请求发送到全局通道
unsafe extern "system" fn cf_fetch_data_callback(
    callback_info: *const CF_CALLBACK_INFO,
    callback_parameters: *const CF_CALLBACK_PARAMETERS,
) {
    if callback_info.is_null() {
        return;
    }
    let info = &*callback_info;

    // 提取 FileIdentity
    let file_identity = if info.FileIdentityLength > 0 && !info.FileIdentity.is_null() {
        std::slice::from_raw_parts(
            info.FileIdentity as *const u8,
            info.FileIdentityLength as usize,
        ).to_vec()
    } else {
        Vec::new()
    };

    // 提取请求范围
    let (required_offset, required_length) = if callback_parameters.is_null() {
        (0i64, -1i64)
    } else {
        let params = &*callback_parameters;
        let fetch = &params.Anonymous.FetchData;
        (fetch.RequiredFileOffset, fetch.RequiredLength)
    };

    let request = FetchDataRequest {
        connection_key: info.ConnectionKey.0,
        transfer_key: info.TransferKey,
        file_identity,
        required_offset,
        required_length,
    };

    tracing::debug!(
        "CFApi 水合请求: transfer_key={}, identity_len={}, offset={}, length={}",
        info.TransferKey,
        info.FileIdentityLength,
        required_offset,
        required_length,
    );

    if let Ok(guard) = CALLBACK_SENDER.lock() {
        if let Some(ref sender) = *guard {
            let _ = sender.blocking_send(request);
        }
    }
}

/// CFApi 回调：取消水合
unsafe extern "system" fn cf_cancel_fetch_callback(
    callback_info: *const CF_CALLBACK_INFO,
    _callback_parameters: *const CF_CALLBACK_PARAMETERS,
) {
    if callback_info.is_null() {
        return;
    }
    tracing::debug!("CFApi 取消水合请求: transfer_key={}", (*callback_info).TransferKey);
}

/// Path → wide null-terminated Vec<u16>
fn to_pcwstr(path: &Path) -> Vec<u16> {
    let mut wide: Vec<u16> = OsStr::new(path).encode_wide().collect();
    wide.push(0);
    wide
}

/// &str → wide null-terminated Vec<u16>
fn to_pcwstr_str(s: &str) -> Vec<u16> {
    let mut wide: Vec<u16> = s.encode_utf16().collect();
    wide.push(0);
    wide
}
