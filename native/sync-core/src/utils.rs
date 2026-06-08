use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard};

use crate::errors::{Result, SyncError};

/// 获取 `std::sync::Mutex` 锁，PoisonError 自动恢复（into_inner）。
///
/// 与裸 `.lock().unwrap()` 的差异：调用方在持锁期间 panic 时，本函数仍可继续工作，
/// 避免一次 panic 把同一 Mutex 上后续所有操作连锁炸掉。同步引擎里所有跨线程共享的
/// `std::sync::Mutex` 都应通过此 helper 取锁。
///
/// 触发 PoisonError 恢复时会以 `warn` 级别记录调用方位置（依赖 `#[track_caller]`），
/// 方便排查是哪个调用点持锁时 panic。
#[inline]
#[track_caller]
pub fn lock_recover<T>(m: &Mutex<T>) -> MutexGuard<'_, T> {
    m.lock().unwrap_or_else(|p| {
        let loc = std::panic::Location::caller();
        tracing::warn!(
            "lock_recover: Mutex 被 poison 后恢复 at {}:{}:{}（说明此前有线程持锁时 panic，请追溯日志）",
            loc.file(), loc.line(), loc.column()
        );
        p.into_inner()
    })
}

/// 增量哈希：前 8KB + 文件大小（快速判断文件是否变更）
pub async fn quick_hash(path: &Path, size: u64) -> Result<String> {
    if size == 0 {
        return Ok("0:0:0".to_string());
    }
    let file = tokio::fs::File::open(path).await?;
    let mut reader = tokio::io::BufReader::new(file);
    let mut head = vec![0u8; 8192.min(size as usize)];
    let n = tokio::io::AsyncReadExt::read(&mut reader, &mut head).await?;
    head.truncate(n);
    let mut hasher = Sha256::new();
    hasher.update(&head);
    let hash = hasher.finalize();
    Ok(format!("{}:{}:{}", hex::encode(hash), n, size))
}

/// 验证路径在同步根目录下，防止路径遍历攻击
pub fn validate_path(root: &Path, path: &Path) -> Result<()> {
    let canonical_root = root.canonicalize().map_err(|e| SyncError::FileSystem(
        format!("无法解析根目录: {}", e)
    ))?;

    let canonical_path = path.canonicalize()
        .unwrap_or_else(|_| path.to_path_buf());

    let relative = canonical_path.strip_prefix(&canonical_root)
        .map_err(|_| SyncError::PathTraversal {
            path: path.to_string_lossy().to_string(),
            root: canonical_root.to_string_lossy().to_string(),
        })?;

    if relative.components().any(|c| matches!(c, std::path::Component::ParentDir)) {
        return Err(SyncError::PathTraversal {
            path: path.to_string_lossy().to_string(),
            root: canonical_root.to_string_lossy().to_string(),
        });
    }

    Ok(())
}

/// 路径规范化：统一使用正斜杠，去除尾部斜杠
pub fn normalize_path(path: &str) -> String {
    let p = path.replace('\\', "/");
    p.trim_end_matches('/').to_string()
}

/// 冲突文件标记前缀
pub const CONFLICT_MARKER: &str = "sync-conflict";

/// 判断文件名是否为冲突副本
pub fn is_conflict_file(name: &str) -> bool {
    name.contains(CONFLICT_MARKER)
}

/// 生成冲突副本名称
pub fn generate_conflict_name(original: &str) -> String {
    let path = PathBuf::from(original);
    let stem = path.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("file");
    let ext = path.extension()
        .and_then(|s| s.to_str())
        .unwrap_or("");

    let date = chrono::Local::now().format("%Y-%m-%d");
    if ext.is_empty() {
        format!("{}.{}.{}", stem, CONFLICT_MARKER, date)
    } else {
        format!("{}.{}.{}.{}", stem, CONFLICT_MARKER, date, ext)
    }
}

/// 计算重试延迟（指数退避）
pub fn retry_delay_ms(attempt: u32, base_ms: u64, max_ms: u64) -> u64 {
    let delay = base_ms * 2u64.saturating_pow(attempt);
    delay.min(max_ms)
}

/// 判断路径是否为同步临时文件
pub fn is_temp_file(path: &Path) -> bool {
    path.extension()
        .map(|ext| ext == "sync_tmp" || ext == "sync_temp")
        .unwrap_or(false)
}

/// 清理目录下残留的 .sync_tmp 文件
pub fn cleanup_temp_files<'a>(dir: &'a Path) -> std::pin::Pin<Box<dyn std::future::Future<Output = u32> + Send + 'a>> {
    Box::pin(async move {
        let mut cleaned = 0u32;
        let mut entries = match tokio::fs::read_dir(dir).await {
            Ok(e) => e,
            Err(_) => return 0,
        };

        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            if path.is_dir() {
                cleaned += cleanup_temp_files(&path).await;
            } else if is_temp_file(&path) && tokio::fs::remove_file(&path).await.is_ok() {
                tracing::debug!("清理临时文件: {}", path.display());
                cleaned += 1;
            }
        }

        cleaned
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_path() {
        assert_eq!(normalize_path("foo\\bar\\baz"), "foo/bar/baz");
        assert_eq!(normalize_path("foo/bar/"), "foo/bar");
        assert_eq!(normalize_path("/foo/bar"), "/foo/bar");
    }

    #[test]
    fn test_generate_conflict_name() {
        let name = generate_conflict_name("photo.jpg");
        assert!(name.starts_with("photo.sync-conflict."));
        assert!(name.ends_with(".jpg"));

        let name_no_ext = generate_conflict_name("README");
        assert!(name_no_ext.starts_with("README.sync-conflict."));
    }

    #[test]
    fn test_is_conflict_file() {
        assert!(is_conflict_file("photo.sync-conflict.2026-05-14.jpg"));
        assert!(is_conflict_file("README.sync-conflict.2026-05-14"));
        assert!(!is_conflict_file("photo.jpg"));
        assert!(!is_conflict_file("normal_file.txt"));
    }

    #[test]
    fn test_retry_delay() {
        assert_eq!(retry_delay_ms(0, 1000, 60000), 1000);
        assert_eq!(retry_delay_ms(1, 1000, 60000), 2000);
        assert_eq!(retry_delay_ms(5, 1000, 60000), 32000);
        assert_eq!(retry_delay_ms(10, 1000, 60000), 60000);
    }
}
