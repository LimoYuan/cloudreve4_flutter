//! Linux FUSE 平台适配器
//! 仅在 linux-fuse feature 启用时编译
//!
//! 提供云端文件系统的 FUSE 读写挂载，支持：
//! - 按需水合（read 时下载）
//! - 写入上传（write → flush 时上传到云端）
//! - 创建/删除/重命名/移动 同步到远程
//! - 远程事件 → inode 增量更新

#![cfg(feature = "linux-fuse")]

use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

use dashmap::DashMap;
use fuser::{
    FileAttr, FileType, Filesystem, ReplyAttr, ReplyData, ReplyDirectory, ReplyEntry, ReplyStatfs,
    ReplyWrite, Request,
};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use crate::api_client::ApiClient;
use crate::sync_db::SyncDb;
use crate::models::SyncConfig;

// ========== 常量 ==========

const FUSE_ROOT_INO: u64 = 1;
/// 小文件阈值：<= 此值纯内存缓冲，超过则落临时文件
const MEMORY_BUFFER_THRESHOLD: u64 = 256 * 1024 * 1024; // 256MB

// ========== Inode 存储 ==========

#[derive(Debug, Clone)]
pub struct InodeEntry {
    pub ino: u64,
    pub parent_ino: u64,
    pub name: String,
    pub is_dir: bool,
    pub size: u64,
    pub mtime_ms: i64,
    pub remote_uri: String,
    pub remote_hash: Option<String>,
    pub dir_loaded: bool,
}

pub struct InodeStore {
    entries: DashMap<u64, InodeEntry>,
    path_to_inode: DashMap<String, u64>,
    children: DashMap<u64, Vec<(String, u64)>>,
    next_inode: AtomicU64,
}

impl Default for InodeStore {
    fn default() -> Self { Self::new() }
}

impl InodeStore {
    pub fn new() -> Self {
        let store = Self {
            entries: DashMap::new(),
            path_to_inode: DashMap::new(),
            children: DashMap::new(),
            next_inode: AtomicU64::new(FUSE_ROOT_INO + 1),
        };
        store.entries.insert(FUSE_ROOT_INO, InodeEntry {
            ino: FUSE_ROOT_INO,
            parent_ino: FUSE_ROOT_INO,
            name: String::new(),
            is_dir: true,
            size: 0,
            mtime_ms: 0,
            remote_uri: String::new(),
            remote_hash: None,
            dir_loaded: false,
        });
        store.path_to_inode.insert(String::new(), FUSE_ROOT_INO);
        store
    }

    pub fn alloc_inode(&self) -> u64 {
        self.next_inode.fetch_add(1, Ordering::Relaxed)
    }

    pub fn upsert(&self, relative_path: &str, parent_ino: u64, name: &str, entry: InodeEntry) -> u64 {
        if let Some(existing_ino) = self.path_to_inode.get(relative_path).map(|r| *r.value()) {
            if let Some(mut e) = self.entries.get_mut(&existing_ino) {
                e.size = entry.size;
                e.mtime_ms = entry.mtime_ms;
                e.remote_uri = entry.remote_uri;
                e.remote_hash = entry.remote_hash;
            }
            existing_ino
        } else {
            let ino = entry.ino;
            self.entries.insert(ino, entry);
            self.path_to_inode.insert(relative_path.to_string(), ino);
            self.children.entry(parent_ino).or_default().push((name.to_string(), ino));
            ino
        }
    }

    pub fn remove(&self, relative_path: &str) -> Option<InodeEntry> {
        let (_, ino) = self.path_to_inode.remove(relative_path)?;
        let (_, entry) = self.entries.remove(&ino)?;
        if let Some(mut children) = self.children.get_mut(&entry.parent_ino) {
            children.retain(|(child_name, child_ino)| !(*child_ino == ino && child_name == &entry.name));
        }
        if entry.is_dir {
            self.remove_children_recursive(ino);
        }
        Some(entry)
    }

    fn remove_children_recursive(&self, parent_ino: u64) {
        let (_, child_list) = match self.children.remove(&parent_ino) {
            Some(pair) => pair,
            None => return,
        };
        for (_, child_ino) in &child_list {
            if let Some((_, child_entry)) = self.entries.remove(child_ino) {
                let mut to_remove = None;
                for item in self.path_to_inode.iter() {
                    if *item.value() == *child_ino {
                        to_remove = Some(item.key().clone());
                        break;
                    }
                }
                if let Some(path) = to_remove {
                    self.path_to_inode.remove(&path);
                }
                if child_entry.is_dir {
                    self.remove_children_recursive(*child_ino);
                }
            }
        }
    }

    pub fn get(&self, ino: u64) -> Option<InodeEntry> {
        self.entries.get(&ino).map(|r| r.value().clone())
    }

    pub fn get_children(&self, parent_ino: u64) -> Vec<(String, u64)> {
        self.children.get(&parent_ino).map(|r| r.value().clone()).unwrap_or_default()
    }

    pub fn lookup_child(&self, parent_ino: u64, name: &str) -> Option<InodeEntry> {
        let children = self.get_children(parent_ino);
        for (child_name, child_ino) in &children {
            if child_name == name {
                return self.get(*child_ino);
            }
        }
        None
    }

    /// 根据 inode 查找相对路径
    pub fn path_for_ino(&self, ino: u64) -> Option<String> {
        self.path_to_inode.iter().find(|e| *e.value() == ino).map(|e| e.key().clone())
    }

    /// 更新 inode 的 remote_uri（上传成功后调用）
    pub fn update_remote_uri(&self, ino: u64, uri: &str) {
        if let Some(mut e) = self.entries.get_mut(&ino) {
            e.remote_uri = uri.to_string();
        }
    }

    /// 更新 inode 大小
    pub fn update_size(&self, ino: u64, size: u64) {
        if let Some(mut e) = self.entries.get_mut(&ino) {
            e.size = size;
        }
    }

    /// 重命名：更新 inode 的名称和父 inode，同时更新 path_to_inode
    pub fn rename_inode(&self, old_rel: &str, new_rel: &str, new_parent_ino: u64, new_name: &str) {
        let ino = match self.path_to_inode.remove(old_rel) {
            Some((_, ino)) => ino,
            None => return,
        };
        // 从旧父目录子项中移除
        if let Some(mut e) = self.entries.get_mut(&ino) {
            let old_parent = e.parent_ino;
            e.parent_ino = new_parent_ino;
            e.name = new_name.to_string();
            // 从旧父目录子项中移除
            if let Some(mut children) = self.children.get_mut(&old_parent) {
                children.retain(|(_, cino)| *cino != ino);
            }
            // 添加到新父目录子项
            self.children.entry(new_parent_ino).or_default().push((new_name.to_string(), ino));
        }
        self.path_to_inode.insert(new_rel.to_string(), ino);
    }
}

// ========== FUSE 请求 ==========

/// 统一请求通道：FUSE → SyncEngine
pub enum FuseRequest {
    /// 按需水合（read）
    Read {
        inode: u64,
        remote_uri: String,
        offset: i64,
        length: i64,
        reply_tx: tokio::sync::oneshot::Sender<Result<Vec<u8>, String>>,
    },
    /// 上传文件（flush 时触发）
    Upload {
        inode: u64,
        parent_ino: u64,
        name: String,
        /// 相对路径
        relative_path: String,
        /// 文件数据（小文件直接内存，大文件为空需从临时文件读取）
        data: Vec<u8>,
        /// 大文件临时文件路径（data 为空时使用）
        tmp_path: Option<String>,
        mtime_ms: i64,
        /// 是否为覆盖写入（已存在远程文件的修改）
        overwrite: bool,
        reply_tx: tokio::sync::oneshot::Sender<Result<UploadResult, String>>,
    },
    /// 创建远程目录
    Mkdir {
        inode: u64,
        parent_ino: u64,
        name: String,
        relative_path: String,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    },
    /// 删除远程文件/目录
    Unlink {
        inode: u64,
        name: String,
        is_dir: bool,
        remote_uri: String,
        relative_path: String,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    },
    /// 重命名/移动
    Rename {
        inode: u64,
        old_name: String,
        old_relative_path: String,
        old_remote_uri: String,
        new_parent_ino: u64,
        new_name: String,
        new_relative_path: String,
        reply_tx: tokio::sync::oneshot::Sender<Result<(), String>>,
    },
}

/// 上传结果
pub struct UploadResult {
    pub remote_uri: String,
    pub remote_hash: Option<String>,
    pub size: u64,
}

// ========== 写缓冲 ==========

/// 单个文件的写缓冲
enum WriteBuffer {
    /// 小文件：纯内存
    Memory { data: Vec<u8>, modified: bool },
    /// 大文件：临时文件
    File { path: std::path::PathBuf, modified: bool, len: u64 },
}

impl WriteBuffer {
    fn new_memory() -> Self {
        WriteBuffer::Memory { data: Vec::new(), modified: false }
    }

    fn write(&mut self, offset: i64, data: &[u8], tmp_dir: &Path) -> std::result::Result<(), String> {
        match self {
            WriteBuffer::Memory { data: buf, modified } => {
                let end = (offset as usize) + data.len();
                if end > buf.len() {
                    buf.resize(end, 0);
                }
                buf[offset as usize..end].copy_from_slice(data);
                *modified = true;
                // 超过阈值则切换到文件模式
                if buf.len() as u64 > MEMORY_BUFFER_THRESHOLD {
                    let tmp_path = tmp_dir.join(format!("fuse_write_{}", std::process::id()));
                    std::fs::write(&tmp_path, buf.as_slice()).map_err(|e| format!("写临时文件失败: {}", e))?;
                    let len = buf.len() as u64;
                    *self = WriteBuffer::File { path: tmp_path, modified: true, len };
                }
                Ok(())
            }
            WriteBuffer::File { path, modified, len } => {
                use std::io::{Seek, SeekFrom, Write};
                let mut f = std::fs::OpenOptions::new()
                    .write(true)
                    .create(true)
                    .truncate(false)
                    .open(path)
                    .map_err(|e| format!("打开临时文件失败: {}", e))?;
                f.seek(SeekFrom::Start(offset as u64)).map_err(|e| format!("seek 失败: {}", e))?;
                f.write_all(data).map_err(|e| format!("写临时文件失败: {}", e))?;
                let new_end = (offset as u64) + data.len() as u64;
                if new_end > *len {
                    *len = new_end;
                }
                *modified = true;
                Ok(())
            }
        }
    }

    fn len(&self) -> u64 {
        match self {
            WriteBuffer::Memory { data, .. } => data.len() as u64,
            WriteBuffer::File { len, .. } => *len,
        }
    }

    fn is_modified(&self) -> bool {
        match self {
            WriteBuffer::Memory { modified, .. } => *modified,
            WriteBuffer::File { modified, .. } => *modified,
        }
    }

    /// 取出数据（小文件返回内存数据，大文件返回空 Vec 需从 tmp_path 读取）
    fn take_data(&mut self) -> (Vec<u8>, Option<String>) {
        match std::mem::replace(self, WriteBuffer::Memory { data: Vec::new(), modified: false }) {
            WriteBuffer::Memory { data, .. } => (data, None),
            WriteBuffer::File { path, .. } => (Vec::new(), Some(path.to_string_lossy().to_string())),
        }
    }
}

// ========== FUSE 文件系统 ==========

struct CloudreveFuseFs {
    inode_store: Arc<InodeStore>,
    request_tx: mpsc::Sender<FuseRequest>,
    runtime: tokio::runtime::Handle,
    /// fh → (inode, WriteBuffer)
    write_buffers: DashMap<u64, (u64, WriteBuffer)>,
    /// 下一个 fh 号
    next_fh: AtomicU64,
    /// 远程根 URI（用于构建新文件的 remote_uri）
    #[allow(dead_code)]
    remote_root: String,
    /// 临时文件目录
    tmp_dir: std::path::PathBuf,
}

impl CloudreveFuseFs {
    fn new(
        inode_store: Arc<InodeStore>,
        request_tx: mpsc::Sender<FuseRequest>,
        runtime: tokio::runtime::Handle,
        remote_root: String,
        tmp_dir: std::path::PathBuf,
    ) -> Self {
        Self {
            inode_store,
            request_tx,
            runtime,
            write_buffers: DashMap::new(),
            next_fh: AtomicU64::new(1),
            remote_root,
            tmp_dir,
        }
    }

    fn alloc_fh(&self) -> u64 {
        self.next_fh.fetch_add(1, Ordering::Relaxed)
    }

    fn entry_to_attr(&self, entry: &InodeEntry) -> FileAttr {
        let mtime = std::time::UNIX_EPOCH + std::time::Duration::from_millis(entry.mtime_ms as u64);
        let kind = if entry.is_dir { FileType::Directory } else { FileType::RegularFile };
        FileAttr {
            ino: entry.ino,
            size: entry.size,
            blocks: entry.size.div_ceil(512),
            atime: mtime,
            mtime,
            ctime: mtime,
            crtime: mtime,
            kind,
            perm: if entry.is_dir { 0o755 } else { 0o644 },
            nlink: if entry.is_dir { 2 } else { 1 },
            uid: unsafe { libc::getuid() },
            gid: unsafe { libc::getgid() },
            rdev: 0,
            flags: 0,
            blksize: 4096,
        }
    }

    /// 根据 parent_ino 和 name 计算相对路径
    fn relative_path(&self, parent_ino: u64, name: &str) -> String {
        let parent_rel = self.inode_store.path_for_ino(parent_ino).unwrap_or_default();
        if parent_rel.is_empty() {
            name.to_string()
        } else {
            format!("{}/{}", parent_rel, name)
        }
    }

}

impl Filesystem for CloudreveFuseFs {
    fn init(&mut self, _req: &Request, _config: &mut fuser::KernelConfig) -> std::result::Result<(), libc::c_int> {
        tracing::info!("FUSE 文件系统已初始化（读写模式）");
        Ok(())
    }

    fn destroy(&mut self) {
        self.write_buffers.clear();
        tracing::info!("FUSE 文件系统已销毁");
    }

    fn getattr(&mut self, _req: &Request, ino: u64, _fh: Option<u64>, reply: ReplyAttr) {
        match self.inode_store.get(ino) {
            Some(entry) => reply.attr(&std::time::Duration::from_secs(1), &self.entry_to_attr(&entry)),
            None => reply.error(libc::ENOENT),
        }
    }

    fn lookup(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, reply: ReplyEntry) {
        let name_str = name.to_string_lossy().to_string();
        match self.inode_store.lookup_child(parent, &name_str) {
            Some(entry) => reply.entry(&std::time::Duration::from_secs(1), &self.entry_to_attr(&entry), 0),
            None => reply.error(libc::ENOENT),
        }
    }

    fn readdir(&mut self, _req: &Request, ino: u64, _fh: u64, offset: i64, mut reply: ReplyDirectory) {
        let entry = match self.inode_store.get(ino) {
            Some(e) => e,
            None => { reply.error(libc::ENOENT); return; }
        };

        if !entry.is_dir { reply.error(libc::ENOTDIR); return; }

        if offset == 0 && reply.add(entry.ino, 1, FileType::Directory, ".") {
            reply.ok(); return;
        }
        if offset <= 1 {
            let parent_ino = if entry.ino == FUSE_ROOT_INO { FUSE_ROOT_INO } else { entry.parent_ino };
            if reply.add(parent_ino, 2, FileType::Directory, "..") {
                reply.ok(); return;
            }
        }

        let children = self.inode_store.get_children(ino);
        for (i, (name, child_ino)) in children.iter().enumerate() {
            let idx = (i + 2) as i64;
            if idx < offset { continue; }
            let child_entry = match self.inode_store.get(*child_ino) {
                Some(e) => e,
                None => continue,
            };
            let kind = if child_entry.is_dir { FileType::Directory } else { FileType::RegularFile };
            if reply.add(*child_ino, idx + 1, kind, name.as_str()) { break; }
        }
        reply.ok();
    }

    // ========== 读操作 ==========

    fn open(&mut self, _req: &Request, ino: u64, flags: i32, reply: fuser::ReplyOpen) {
        let fh = self.alloc_fh();
        // 如果是写打开（O_WRONLY 或 O_RDWR），初始化写缓冲
        let write_mode = (flags & libc::O_WRONLY != 0) || (flags & libc::O_RDWR != 0);
        if write_mode {
            self.write_buffers.insert(fh, (ino, WriteBuffer::new_memory()));
        }
        reply.opened(fh, fuser::consts::FOPEN_KEEP_CACHE);
    }

    fn read(&mut self, _req: &Request, ino: u64, _fh: u64, offset: i64, size: u32, _flags: i32, _lock_owner: Option<u64>, reply: ReplyData) {
        // 如果有写缓冲（正在写入的文件），从写缓冲读取
        if let Some(pair) = self.write_buffers.get(&(_fh)) {
            if pair.0 == ino {
                match &pair.1 {
                    WriteBuffer::Memory { data, .. } => {
                        let start = offset as usize;
                        let end = (offset as usize + size as usize).min(data.len());
                        if start < data.len() {
                            reply.data(&data[start..end]);
                        } else {
                            reply.data(&[]);
                        }
                        return;
                    }
                    WriteBuffer::File { path, len, .. } => {
                        let start = offset as u64;
                        let end = (start + size as u64).min(*len);
                        if start < *len {
                            match std::fs::read(path) {
                                Ok(data) => {
                                    let s = start as usize;
                                    let e = end as usize;
                                    reply.data(&data[s..e.min(data.len())]);
                                }
                                Err(_) => reply.error(libc::EIO),
                            }
                        } else {
                            reply.data(&[]);
                        }
                        return;
                    }
                }
            }
        }

        // 已有文件的读：走水合
        let entry = match self.inode_store.get(ino) {
            Some(e) => e,
            None => { reply.error(libc::ENOENT); return; }
        };
        if entry.is_dir { reply.error(libc::EISDIR); return; }
        if entry.remote_uri.is_empty() { reply.error(libc::EIO); return; }

        let (tx, rx) = tokio::sync::oneshot::channel();
        let request = FuseRequest::Read {
            inode: ino,
            remote_uri: entry.remote_uri.clone(),
            offset,
            length: size as i64,
            reply_tx: tx,
        };

        if self.request_tx.blocking_send(request).is_err() {
            tracing::error!("FUSE read: 请求发送失败");
            reply.error(libc::EIO);
            return;
        }

        match self.runtime.block_on(rx) {
            Ok(Ok(data)) => {
                let start = offset as usize;
                let end = (offset as usize + size as usize).min(data.len());
                if start < data.len() {
                    reply.data(&data[start..end]);
                } else {
                    reply.data(&[]);
                }
            }
            Ok(Err(e)) => {
                tracing::error!("FUSE read: 水合失败: {}", e);
                reply.error(libc::EIO);
            }
            Err(_) => {
                tracing::error!("FUSE read: 请求被丢弃");
                reply.error(libc::EIO);
            }
        }
    }

    // ========== 写操作 ==========

    fn write(&mut self, _req: &Request, ino: u64, fh: u64, offset: i64, data: &[u8], _write_flags: u32, _flags: i32, _lock_owner: Option<u64>, reply: ReplyWrite) {
        let mut buffer = match self.write_buffers.get_mut(&fh) {
            Some(b) if b.0 == ino => b,
            _ => {
                // 没有写缓冲但收到 write，自动创建
                drop(self.write_buffers.entry(fh).or_insert((ino, WriteBuffer::new_memory())));
                self.write_buffers.get_mut(&fh).unwrap()
            }
        };

        if let Err(e) = buffer.1.write(offset, data, &self.tmp_dir) {
            tracing::error!("FUSE write: 缓冲失败: {}", e);
            reply.error(libc::EIO);
            return;
        }

        // 更新 inode size
        let new_size = buffer.1.len();
        self.inode_store.update_size(ino, new_size);

        reply.written(data.len() as u32);
    }

    fn flush(&mut self, _req: &Request, ino: u64, fh: u64, _lock_owner: u64, reply: fuser::ReplyEmpty) {
        let mut buffer = match self.write_buffers.get_mut(&fh) {
            Some(b) if b.0 == ino => b,
            _ => { reply.ok(); return; }
        };

        if !buffer.1.is_modified() {
            reply.ok();
            return;
        }

        let relative_path = match self.inode_store.path_for_ino(ino) {
            Some(p) => p,
            None => {
                // 新创建的文件可能还没有 path，从 parent 推算
                let entry = self.inode_store.get(ino);
                match entry {
                    Some(e) => self.relative_path(e.parent_ino, &e.name),
                    None => { reply.error(libc::EIO); return; }
                }
            }
        };

        let entry = match self.inode_store.get(ino) {
            Some(e) => e,
            None => { reply.error(libc::ENOENT); return; }
        };

        let (data, tmp_path) = buffer.1.take_data();
        let overwrite = !entry.remote_uri.is_empty();
        let parent_ino = entry.parent_ino;
        let name = entry.name.clone();
        let mtime_ms = entry.mtime_ms;

        let (tx, rx) = tokio::sync::oneshot::channel();
        let request = FuseRequest::Upload {
            inode: ino,
            parent_ino,
            name,
            relative_path,
            data,
            tmp_path,
            mtime_ms,
            overwrite,
            reply_tx: tx,
        };

        if self.request_tx.blocking_send(request).is_err() {
            tracing::error!("FUSE flush: 上传请求发送失败");
            reply.error(libc::EIO);
            return;
        }

        match self.runtime.block_on(rx) {
            Ok(Ok(result)) => {
                self.inode_store.update_remote_uri(ino, &result.remote_uri);
                self.inode_store.update_size(ino, result.size);
                reply.ok();
            }
            Ok(Err(e)) => {
                tracing::error!("FUSE flush: 上传失败: {}", e);
                reply.error(libc::EIO);
            }
            Err(_) => {
                tracing::error!("FUSE flush: 上传请求被丢弃");
                reply.error(libc::EIO);
            }
        }
    }

    fn release(&mut self, _req: &Request, _ino: u64, fh: u64, _flags: i32, _lock_owner: Option<u64>, _flush: bool, reply: fuser::ReplyEmpty) {
        if let Some((_, (_, WriteBuffer::File { path, .. }))) = self.write_buffers.remove(&fh) {
            let _ = std::fs::remove_file(&path);
        }
        reply.ok();
    }

    fn create(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, _mode: u32, _umask: u32, _flags: i32, reply: fuser::ReplyCreate) {
        let name_str = name.to_string_lossy().to_string();
        let relative_path = self.relative_path(parent, &name_str);
        let ino = self.inode_store.alloc_inode();
        let now_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        let entry = InodeEntry {
            ino,
            parent_ino: parent,
            name: name_str,
            is_dir: false,
            size: 0,
            mtime_ms: now_ms,
            remote_uri: String::new(), // 上传成功后填充
            remote_hash: None,
            dir_loaded: false,
        };
        self.inode_store.upsert(&relative_path, parent, &entry.name.clone(), entry);

        let fh = self.alloc_fh();
        self.write_buffers.insert(fh, (ino, WriteBuffer::new_memory()));

        let attr = self.entry_to_attr(&self.inode_store.get(ino).unwrap());
        reply.created(&std::time::Duration::from_secs(1), &attr, 0, fh, 0);
    }

    fn mkdir(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, _mode: u32, _umask: u32, reply: ReplyEntry) {
        let name_str = name.to_string_lossy().to_string();
        let relative_path = self.relative_path(parent, &name_str);
        let ino = self.inode_store.alloc_inode();

        let entry = InodeEntry {
            ino,
            parent_ino: parent,
            name: name_str.clone(),
            is_dir: true,
            size: 0,
            mtime_ms: 0,
            remote_uri: String::new(),
            remote_hash: None,
            dir_loaded: false,
        };
        self.inode_store.upsert(&relative_path, parent, &name_str, entry);

        // 异步创建远程目录
        let (tx, rx) = tokio::sync::oneshot::channel();
        let request = FuseRequest::Mkdir {
            inode: ino,
            parent_ino: parent,
            name: name_str,
            relative_path,
            reply_tx: tx,
        };

        if self.request_tx.blocking_send(request).is_err() {
            tracing::error!("FUSE mkdir: 请求发送失败");
            // 本地 inode 已创建，但远程创建失败，inode 标记为无 remote_uri
        }

        // 不阻塞等待远程结果，先返回本地 inode
        let attr = self.entry_to_attr(&self.inode_store.get(ino).unwrap());
        reply.entry(&std::time::Duration::from_secs(1), &attr, 0);

        // 后台更新 remote_uri
        let inode_store = self.inode_store.clone();
        let runtime = self.runtime.clone();
        std::thread::spawn(move || {
            if let Ok(Ok(())) = runtime.block_on(rx) {
                // remote_uri 在 SyncEngine 端更新
            }
            let _ = inode_store; // keep Arc alive
        });
    }

    fn unlink(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, reply: fuser::ReplyEmpty) {
        let name_str = name.to_string_lossy().to_string();
        let child = match self.inode_store.lookup_child(parent, &name_str) {
            Some(c) => c,
            None => { reply.error(libc::ENOENT); return; }
        };
        if child.is_dir { reply.error(libc::EISDIR); return; }

        let relative_path = self.relative_path(parent, &name_str);
        let remote_uri = child.remote_uri.clone();
        let ino = child.ino;

        // 从 InodeStore 移除
        self.inode_store.remove(&relative_path);

        // 异步删除远程文件
        if !remote_uri.is_empty() {
            let (tx, rx) = tokio::sync::oneshot::channel();
            let request = FuseRequest::Unlink {
                inode: ino,
                name: name_str,
                is_dir: false,
                remote_uri,
                relative_path,
                reply_tx: tx,
            };
            if self.request_tx.blocking_send(request).is_err() {
                tracing::error!("FUSE unlink: 请求发送失败");
            } else {
                let runtime = self.runtime.clone();
                std::thread::spawn(move || {
                    let _ = runtime.block_on(rx);
                });
            }
        }

        reply.ok();
    }

    fn rmdir(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, reply: fuser::ReplyEmpty) {
        let name_str = name.to_string_lossy().to_string();
        let child = match self.inode_store.lookup_child(parent, &name_str) {
            Some(c) => c,
            None => { reply.error(libc::ENOENT); return; }
        };
        if !child.is_dir { reply.error(libc::ENOTDIR); return; }

        // 检查目录是否为空
        let children = self.inode_store.get_children(child.ino);
        if !children.is_empty() {
            reply.error(libc::ENOTEMPTY);
            return;
        }

        let relative_path = self.relative_path(parent, &name_str);
        let remote_uri = child.remote_uri.clone();
        let ino = child.ino;

        self.inode_store.remove(&relative_path);

        if !remote_uri.is_empty() {
            let (tx, rx) = tokio::sync::oneshot::channel();
            let request = FuseRequest::Unlink {
                inode: ino,
                name: name_str,
                is_dir: true,
                remote_uri,
                relative_path,
                reply_tx: tx,
            };
            if self.request_tx.blocking_send(request).is_err() {
                tracing::error!("FUSE rmdir: 请求发送失败");
            } else {
                let runtime = self.runtime.clone();
                std::thread::spawn(move || {
                    let _ = runtime.block_on(rx);
                });
            }
        }

        reply.ok();
    }

    fn rename(&mut self, _req: &Request, parent: u64, name: &std::ffi::OsStr, new_parent: u64, new_name: &std::ffi::OsStr, _flags: u32, reply: fuser::ReplyEmpty) {
        let old_name = name.to_string_lossy().to_string();
        let new_name_str = new_name.to_string_lossy().to_string();
        let old_rel = self.relative_path(parent, &old_name);
        let new_rel = self.relative_path(new_parent, &new_name_str);

        let child = match self.inode_store.lookup_child(parent, &old_name) {
            Some(c) => c,
            None => { reply.error(libc::ENOENT); return; }
        };
        let remote_uri = child.remote_uri.clone();
        let ino = child.ino;

        // 如果目标已存在，先移除
        if self.inode_store.lookup_child(new_parent, &new_name_str).is_some() {
            let target_rel = new_rel.clone();
            self.inode_store.remove(&target_rel);
        }

        // 更新 InodeStore
        self.inode_store.rename_inode(&old_rel, &new_rel, new_parent, &new_name_str);

        // 异步重命名远程文件
        if !remote_uri.is_empty() {
            let (tx, rx) = tokio::sync::oneshot::channel();
            let request = FuseRequest::Rename {
                inode: ino,
                old_name,
                old_relative_path: old_rel,
                old_remote_uri: remote_uri,
                new_parent_ino: new_parent,
                new_name: new_name_str,
                new_relative_path: new_rel,
                reply_tx: tx,
            };
            if self.request_tx.blocking_send(request).is_err() {
                tracing::error!("FUSE rename: 请求发送失败");
            } else {
                let runtime = self.runtime.clone();
                std::thread::spawn(move || {
                    let _ = runtime.block_on(rx);
                });
            }
        }

        reply.ok();
    }

    fn setattr(&mut self, _req: &Request, ino: u64, _mode: Option<u32>, uid: Option<u32>, gid: Option<u32>, size: Option<u64>, _atime: Option<fuser::TimeOrNow>, _mtime: Option<fuser::TimeOrNow>, _ctime: Option<std::time::SystemTime>, fh: Option<u64>, _crtime: Option<std::time::SystemTime>, _chgtime: Option<std::time::SystemTime>, _bkuptime: Option<std::time::SystemTime>, _flags: Option<u32>, reply: ReplyAttr) {
        let _ = (uid, gid);
        if self.inode_store.get(ino).is_none() {
            reply.error(libc::ENOENT);
            return;
        }

        if let Some(new_size) = size {
            self.inode_store.update_size(ino, new_size);
            if let Some(fh_val) = fh {
                if let Some(mut buf) = self.write_buffers.get_mut(&fh_val) {
                    match &mut buf.1 {
                        WriteBuffer::Memory { data, .. } => {
                            data.resize(new_size as usize, 0);
                        }
                        WriteBuffer::File { len, .. } => {
                            *len = new_size;
                        }
                    }
                }
            }
        }

        let entry = self.inode_store.get(ino).unwrap();
        reply.attr(&std::time::Duration::from_secs(1), &self.entry_to_attr(&entry));
    }

    fn statfs(&mut self, _req: &Request, _ino: u64, reply: ReplyStatfs) {
        reply.statfs(0, 0, 0, 0, 0, 4096, 255, 0);
    }
}

// ========== FUSE 平台适配器 ==========

pub struct FusePlatformAdapter {
    mount_path: std::path::PathBuf,
    inode_store: Arc<InodeStore>,
    request_rx: std::sync::Mutex<Option<mpsc::Receiver<FuseRequest>>>,
    shutdown: CancellationToken,
    #[allow(dead_code)]
    runtime: tokio::runtime::Handle,
    #[allow(dead_code)]
    db: Arc<SyncDb>,
    #[allow(dead_code)]
    api: Arc<ApiClient>,
    #[allow(dead_code)]
    config: SyncConfig,
}

impl FusePlatformAdapter {
    pub fn new(
        mount_path: &Path,
        db: Arc<SyncDb>,
        api: Arc<ApiClient>,
        config: SyncConfig,
    ) -> anyhow::Result<Self> {
        let runtime = tokio::runtime::Handle::current();
        let inode_store = Arc::new(InodeStore::new());
        let (request_tx, request_rx) = mpsc::channel::<FuseRequest>(256);
        let shutdown = CancellationToken::new();
        let shutdown_clone = shutdown.clone();
        let mount_path_buf = mount_path.to_path_buf();

        std::fs::create_dir_all(mount_path)
            .map_err(|e| anyhow::anyhow!("创建 FUSE 挂载目录失败: {}", e))?;

        // 创建临时文件目录
        let tmp_dir = config.data_dir.join("sync_core").join("tmp");
        std::fs::create_dir_all(&tmp_dir)
            .map_err(|e| anyhow::anyhow!("创建临时目录失败: {}", e))?;

        let inode_store_clone = inode_store.clone();
        let mount_path_clone = mount_path_buf.clone();
        let runtime_for_thread = runtime.clone();
        let remote_root = config.remote_root.clone();
        let tmp_dir_clone = tmp_dir.clone();

        std::thread::Builder::new()
            .name("fuse-mount".to_string())
            .spawn(move || {
                let fs = CloudreveFuseFs::new(
                    inode_store_clone,
                    request_tx,
                    runtime_for_thread,
                    remote_root,
                    tmp_dir_clone,
                );

                let options = vec![
                    fuser::MountOption::FSName("cloudreve".to_string()),
                    fuser::MountOption::Subtype("cloudreve".to_string()),
                    fuser::MountOption::NoAtime,
                ];

                tracing::info!("FUSE 挂载中（读写模式）: {}", mount_path_clone.display());

                match fuser::mount2(fs, &mount_path_clone, &options) {
                    Ok(()) => tracing::info!("FUSE 挂载已结束: {}", mount_path_clone.display()),
                    Err(e) => {
                        if shutdown_clone.is_cancelled() {
                            tracing::info!("FUSE 挂载已关闭（正常退出）");
                        } else {
                            tracing::error!("FUSE 挂载失败: {}", e);
                        }
                    }
                }
            })
            .map_err(|e| anyhow::anyhow!("启动 FUSE 线程失败: {}", e))?;

        tracing::info!("FusePlatformAdapter 初始化完成: {}", mount_path.display());

        Ok(Self {
            mount_path: mount_path_buf,
            inode_store,
            request_rx: std::sync::Mutex::new(Some(request_rx)),
            shutdown,
            runtime,
            db,
            api,
            config,
        })
    }

    pub fn take_request_receiver(&self) -> Option<mpsc::Receiver<FuseRequest>> {
        self.request_rx.lock().ok().and_then(|mut rx| rx.take())
    }

    pub fn inode_store(&self) -> &Arc<InodeStore> {
        &self.inode_store
    }

    #[allow(clippy::too_many_arguments)]
    pub fn create_placeholder_for_remote(
        &self,
        parent_rel: &str,
        name: &str,
        relative_path: &str,
        is_dir: bool,
        size: u64,
        remote_uri: &str,
        remote_hash: Option<&str>,
        mtime_ms: i64,
    ) {
        let parent_ino = self.inode_store.path_to_inode.get(parent_rel)
            .map(|r| *r.value())
            .unwrap_or(FUSE_ROOT_INO);

        let ino = self.inode_store.alloc_inode();
        let entry = InodeEntry {
            ino,
            parent_ino,
            name: name.to_string(),
            is_dir,
            size,
            mtime_ms,
            remote_uri: remote_uri.to_string(),
            remote_hash: remote_hash.map(|s| s.to_string()),
            dir_loaded: false,
        };

        self.inode_store.upsert(relative_path, parent_ino, name, entry);
        tracing::debug!("FUSE inode 注册: {} (ino={}, dir={})", relative_path, ino, is_dir);
    }

    pub fn remove_inode(&self, relative_path: &str) {
        if let Some(entry) = self.inode_store.remove(relative_path) {
            tracing::debug!("FUSE inode 移除: {} (ino={})", relative_path, entry.ino);
        }
    }

    /// 处理远程重命名/移动事件：直接更新 InodeStore（不走 FUSE handler）
    pub fn handle_remote_rename(&self, old_rel: &str, new_rel: &str, new_remote_uri: &str) {
        let new_path = std::path::Path::new(new_rel);
        let new_parent_rel = new_path.parent()
            .map(|p| crate::utils::normalize_path(&p.to_string_lossy()))
            .unwrap_or_default();
        let new_name = new_path.file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        let new_parent_ino = self.inode_store.path_to_inode.get(&new_parent_rel)
            .map(|r| *r.value())
            .unwrap_or(FUSE_ROOT_INO);

        let ino = self.inode_store.path_to_inode.get(old_rel)
            .map(|r| *r.value());

        self.inode_store.rename_inode(old_rel, new_rel, new_parent_ino, &new_name);

        if let Some(ino) = ino {
            self.inode_store.update_remote_uri(ino, new_remote_uri);
        }

        tracing::info!("FUSE 远程重命名: {} → {} (ino={:?})", old_rel, new_rel, ino);
    }

    pub fn unmount(&self) -> anyhow::Result<()> {
        self.shutdown.cancel();
        let result = std::process::Command::new("fusermount3")
            .args(["-u", "-z"])
            .arg(&self.mount_path)
            .status()
            .or_else(|_| {
                std::process::Command::new("fusermount")
                    .args(["-u", "-z"])
                    .arg(&self.mount_path)
                    .status()
            });

        match result {
            Ok(s) if s.success() => {
                tracing::info!("FUSE 已卸载: {}", self.mount_path.display());
                Ok(())
            }
            Ok(s) => {
                tracing::warn!("FUSE 卸载退出码: {}", s);
                Ok(())
            }
            Err(e) => {
                tracing::warn!("FUSE 卸载命令失败: {}", e);
                Ok(())
            }
        }
    }

    pub fn mount_path(&self) -> &Path {
        &self.mount_path
    }
}
