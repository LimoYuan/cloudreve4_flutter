/// 存储键常量
class StorageKeys {
  // 设置相关
  static const String themeMode = 'theme_mode';
  static const String customBaseUrl = 'custom_base_url';
  static const String servers = 'flutter_servers';
  static const String lastSelectedServer = 'last_selected_server_label';

  // 上传相关
  static const String uploadQueue = 'upload_queue';
  static const String uploadTasks = 'upload_tasks';

  // 下载相关
  static const String downloadTasks = 'download_tasks';
  static const String downloadWifiOnly = 'download_wifi_only';
  static const String downloadRetries = 'download_retries';
  static const String downloadDefaultDirectory = 'download_default_directory';

  // 任务记录
  static const String taskRetentionDays = 'task_retention_days';

  // 缓存相关
  static const String cacheSettings = 'cache_settings';

  // Gravatar 镜像
  static const String gravatarMirrorEnabled = 'gravatar_mirror_enabled';
  static const String gravatarMirrorUrl = 'gravatar_mirror_url';

  // 搜索历史
  static const String searchHistory = 'search_history';

  // 同步相关
  static const String syncConfig = 'sync_config';
  static const String syncState = 'sync_state';
  static const String syncCumStats = 'sync_cum_stats';
  static const String clientId = 'client_id';
  static const String desktopSyncWizardCompleted = 'desktop_sync_wizard_completed';
  // v2 严格桌面同步向导标记：不再因为已有 sync_config 自动跳过向导。
  static const String desktopSyncWizardCompletedV2 = 'desktop_sync_wizard_completed_v2';
  static const String desktopSyncWizardCompletedV3 = 'desktop_sync_wizard_completed_v3';

  // 文件排序
  static const String fileSortOption = 'file_sort_option';

  // 文件视图
  static const String fileViewType = 'file_view_type';

  // 编辑器
  static const String editorTheme = 'editor_theme';

  // 日志级别
  static const String logLevel = 'app_log_level';

  // 公告
  static const String siteAnnouncementDismissedFingerprint = 'site_announcement_dismissed_fingerprint';

  // 桌面系统设置
  static const String shutdownAfterUploadsComplete = 'shutdown_after_uploads_complete';
  static const String launchAtStartupEnabled = 'launch_at_startup_enabled';

  // 概览最近活动
  static const String recentActivityDisplayLimit = 'recent_activity_display_limit';
  static const String localRecentFileActivities = 'local_recent_file_activities';
  static const String localRecentShareActivities = 'local_recent_share_activities';
}
