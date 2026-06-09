use crate::errors::Result;
use crate::models::*;
use std::path::Path;

use super::SyncEngine;

impl SyncEngine {
    pub async fn sync_album(&self, album_paths: Vec<String>, remote_dcim_uri: &str) -> Result<()> {
        let synced = self.db.get_album_sync_records().await?;
        let new_photos: Vec<_> = album_paths.iter().filter(|p| !synced.contains_key(*p)).collect();
        let total = new_photos.len();
        if total == 0 { return Ok(()); }

        for (i, photo_path) in new_photos.iter().enumerate() {
            let local_path = Path::new(photo_path);
            let file_name = local_path.file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| format!("photo_{}", i));

            match tokio::fs::metadata(photo_path).await {
                Ok(metadata) => {
                    let file_size = metadata.len();
                    match self.api.create_upload_session(remote_dcim_uri, file_size, false, None, None, None).await {
                        Ok(session) => {
                            match crate::uploader::upload_file_chunked(&self.api, local_path, &session, "album").await {
                                Ok(_) => {
                                    let remote_uri = format!("{}/{}", remote_dcim_uri, file_name);
                                    let hash = crate::utils::quick_hash(local_path, file_size).await.unwrap_or_default();
                                    if let Err(e) = self.db.add_album_sync_record(photo_path, &remote_uri, &hash).await {
                                        tracing::warn!("记录同步状态失败: {}", e);
                                    }
                                    tracing::info!("照片上传完成 ({}/{}): {}", i + 1, total, file_name);
                                }
                                Err(e) => tracing::error!("上传照片失败 {}: {}", file_name, e),
                            }
                        }
                        Err(e) => tracing::error!("创建上传会话失败 {}: {}", file_name, e),
                    }
                }
                Err(e) => tracing::warn!("无法读取照片元数据 {}: {}", photo_path, e),
            }
        }
        Ok(())
    }

    pub async fn check_album_dirs(&self, base_uri: &str) -> Result<CloudAlbumCheckResult> {
        let files = self.api.list_files_page(base_uri, 0, 200, None).await?;
        let dcim_exists = files.files.iter().any(|f| f.name == "DCIM" && f.is_dir);
        let pictures_exists = files.files.iter().any(|f| f.name == "Pictures" && f.is_dir);
        let dcim_uri = if dcim_exists { Some(format!("{}/DCIM", base_uri)) } else { None };

        // 检查 DCIM/Camera 子目录
        let camera_exists = if let Some(ref dcim_uri) = dcim_uri {
            let dcim_files = self.api.list_files_page(dcim_uri, 0, 200, None).await?;
            dcim_files.files.iter().any(|f| f.name == "Camera" && f.is_dir)
        } else {
            false
        };

        Ok(CloudAlbumCheckResult {
            dcim_exists,
            pictures_exists,
            dcim_uri,
            pictures_uri: if pictures_exists { Some(format!("{}/Pictures", base_uri)) } else { None },
            camera_exists,
            camera_uri: if camera_exists { Some(format!("{}/DCIM/Camera", base_uri)) } else { None },
        })
    }

    pub async fn create_album_dirs(&self, base_uri: &str) -> Result<()> {
        let base_uri = base_uri.trim_end_matches('/');
        self.api.ensure_directory_path(&format!("{}/DCIM/Camera", base_uri)).await?;
        self.api.ensure_directory_path(&format!("{}/Pictures", base_uri)).await?;
        Ok(())
    }
}
