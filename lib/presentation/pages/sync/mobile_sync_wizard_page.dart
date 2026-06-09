import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/sync_defaults.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/sync_config_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/folder_picker.dart';
import '../../widgets/toast_helper.dart';

/// Mobile first-run sync setup wizard.
///
/// The flow mirrors the desktop setup concepts, but keeps Android-specific
/// decisions explicit: album upload/download mode, DCIM/Camera local path,
/// cloud album path, permission checks, and a final confirmation step.
class MobileSyncWizardPage extends StatefulWidget {
  const MobileSyncWizardPage({super.key});

  @override
  State<MobileSyncWizardPage> createState() => _MobileSyncWizardPageState();
}

class _MobileSyncWizardPageState extends State<MobileSyncWizardPage> {
  final PageController _pageController = PageController();

  int _step = 0;
  String _syncMode = SyncDefaults.defaultAndroidSyncMode;
  String _localRoot = '';
  String _remoteRoot = SyncDefaults.defaultAndroidRemoteRoot;
  final int _maxConcurrent = SyncDefaults.defaultMaxConcurrentTransfers;
  bool _isFinishing = false;

  static const int _lastStep = 3;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final localRoot = await SyncDefaults.getDefaultAndroidLocalRoot();
    if (!mounted) return;
    setState(() {
      _localRoot = localRoot;
      _remoteRoot = SyncDefaults.defaultAndroidRemoteRoot;
    });
  }

  void _next() {
    if (_step >= _lastStep) return;
    final next = _step + 1;
    setState(() => _step = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step <= 0) return;
    final prev = _step - 1;
    setState(() => _step = prev);
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _setMode(String mode) {
    setState(() {
      _syncMode = mode;
      _remoteRoot = SyncDefaults.defaultAndroidRemoteRoot;
    });
  }

  Future<void> _pickRemoteFolder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择云端相册目录'),
        content: SizedBox(
          width: 420,
          height: 520,
          child: FolderPicker(
            currentPath: _remoteRoot,
            onFolderSelected: (path) => Navigator.pop(ctx, path),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _remoteRoot = result == '/'
          ? SyncDefaults.defaultRemoteRoot
          : '${SyncDefaults.defaultRemoteRoot}${result.startsWith('/') ? result : '/$result'}';
    });
  }

  Future<bool> _ensurePermissions() async {
    if (_syncMode == 'album_upload') {
      return _ensureAlbumUploadPermission();
    }

    if (_syncMode == 'album_download') {
      return _ensureAlbumDownloadPermission();
    }

    return true;
  }

  Future<bool> _ensureAlbumUploadPermission() async {
    // Android 12 and below use READ_EXTERNAL_STORAGE for media access.
    // Request it first so older devices show the real system permission dialog.
    final storageStatus = await Permission.storage.request();
    if (_isPermissionGranted(storageStatus)) {
      return true;
    }

    // Android 13+ uses the split media permissions. Request them only after
    // storage is not available/granted, otherwise Android 12 devices will log
    // "No permissions found in manifest" for photos/videos and never show the
    // expected prompt.
    final mediaStatuses = await [
      Permission.photos,
      Permission.videos,
    ].request();

    final hasPhotoAccess = _isPermissionGranted(
      mediaStatuses[Permission.photos],
    );
    final hasVideoAccess = _isPermissionGranted(
      mediaStatuses[Permission.videos],
    );

    if (hasPhotoAccess && hasVideoAccess) {
      return true;
    }

    if (!mounted) return false;
    return _showPermissionDialog(
      title: '需要照片和视频权限',
      message: '相册上传需要读取手机照片和视频。请先在系统权限弹窗中允许访问；如果刚才拒绝了，请到系统设置中重新开启。',
    );
  }

  Future<bool> _ensureAlbumDownloadPermission() async {
    // Try normal storage first. On Android 12 and below this is the expected
    // runtime permission dialog, and it is enough for common DCIM/Camera writes.
    final storageStatus = await Permission.storage.request();
    if (_isPermissionGranted(storageStatus)) {
      return true;
    }

    // If normal storage is not enough, fall back to all-files access.
    final manageStatus = await Permission.manageExternalStorage.request();
    if (_isPermissionGranted(manageStatus)) {
      return true;
    }

    if (!mounted) return false;
    return _showPermissionDialog(
      title: '需要所有文件管理权限',
      message:
          '相册下载需要写入 DCIM/Camera 目录。请先在系统权限弹窗中允许访问；如果刚才拒绝了，请到系统设置中开启所有文件管理权限。',
    );
  }

  bool _isPermissionGranted(PermissionStatus? status) {
    if (status == null) return false;
    return status.isGranted || status.isLimited;
  }

  Future<bool> _showPermissionDialog({
    required String title,
    required String message,
  }) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去系统设置'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _finish() async {
    if (_isFinishing) return;

    final auth = context.read<AuthProvider>();
    final sync = context.read<SyncProvider>();
    final server = auth.currentServer;
    final token = auth.token;

    if (server == null || token == null) {
      ToastHelper.failure('请先登录后再设置同步');
      return;
    }

    setState(() => _isFinishing = true);

    try {
      final ok = await _ensurePermissions();
      if (!ok) return;

      final appSupportDir = await getApplicationSupportDirectory();
      final config = SyncConfigModel(
        baseUrl: server.baseUrl,
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        localRoot: _localRoot,
        remoteRoot: _remoteRoot,
        syncMode: _syncMode,
        conflictStrategy: 'keep_both',
        wcfDeleteMode: 'wcf_delete_local_only',
        maxConcurrentTransfers: _maxConcurrent,
        bandwidthLimitKbps: 0,
        maxWorkers: SyncDefaults.defaultMaxWorkers,
        dataDir: appSupportDir.path,
        clientId: '',
        logLevel: SyncDefaults.defaultLogLevel,
      );

      await sync.startSync(config);
      if (mounted) ToastHelper.success('同步已开始');

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      AppLogger.e('移动端同步向导完成失败: $e');
      if (mounted) ToastHelper.failure('同步设置失败：$e');
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('同步设置向导')),
      body: SafeArea(
        child: Column(
          children: [
            _WizardProgress(currentStep: _step, totalSteps: _lastStep + 1),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildIntroStep(context),
                  _buildModeStep(context),
                  _buildPathStep(context),
                  _buildConfirmStep(context),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroStep(BuildContext context) {
    final theme = Theme.of(context);
    return _WizardStep(
      icon: Icons.sync_outlined,
      title: '设置手机文件同步',
      subtitle: '按向导完成首次配置后，可以把手机相册和云端目录保持同步。未完成前将不能使用文件同步。',
      children: [
        _InfoTile(
          icon: Icons.photo_library_outlined,
          title: '相册上传',
          description: '把 DCIM/Camera 中的新照片和视频备份到云端。',
        ),
        _InfoTile(
          icon: Icons.cloud_download_outlined,
          title: '相册下载',
          description: '把云端相册目录下载回手机 Camera 目录。',
        ),
        _InfoTile(
          icon: Icons.shield_outlined,
          title: '权限说明',
          description: '最后点击“保存并开始同步”时会先弹出系统权限请求；只有用户拒绝后，才会显示权限说明。',
        ),
        const SizedBox(height: 12),
        Text(
          '这一步只配置手机端同步，不会影响 Windows 端同步设置。你可以返回上一页，但未完成向导前不能开始同步。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildModeStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.compare_arrows_outlined,
      title: '选择同步方式',
      subtitle: '手机端默认按相册场景配置。后续仍可在同步设置中修改。',
      children: [
        _ModeCard(
          selected: _syncMode == 'album_upload',
          icon: Icons.cloud_upload_outlined,
          title: '仅上传',
          subtitle: '备份手机照片到云端，不会从云端下载到本地。',
          onTap: () => _setMode('album_upload'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          selected: _syncMode == 'album_download',
          icon: Icons.cloud_download_outlined,
          title: '仅下载',
          subtitle: '从云端下载照片到手机 Camera 目录。',
          onTap: () => _setMode('album_download'),
        ),
      ],
    );
  }

  Widget _buildPathStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.folder_outlined,
      title: '确认同步目录',
      subtitle: '默认使用手机系统相册目录，对应云端 DCIM/Camera。',
      children: [
        _PathTile(
          icon: Icons.phone_android_outlined,
          title: '手机本地目录',
          path: _localRoot.isEmpty ? '正在获取 DCIM/Camera...' : _localRoot,
        ),
        const SizedBox(height: 12),
        _PathTile(
          icon: Icons.cloud_outlined,
          title: '云端目录',
          path: _remoteRoot,
          action: TextButton(
            onPressed: _pickRemoteFolder,
            child: const Text('更改'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.task_alt_outlined,
      title: '确认并开始',
      subtitle: '保存配置后会直接启动初始同步，不再跳转到二次设置页面。',
      children: [
        _SummaryRow(label: '同步方式', value: _modeLabel(_syncMode)),
        _SummaryRow(label: '本地目录', value: _localRoot),
        _SummaryRow(label: '云端目录', value: _remoteRoot),
        _SummaryRow(label: '并发传输', value: '$_maxConcurrent'),
        const SizedBox(height: 16),
        _InfoTile(
          icon: Icons.info_outline,
          title: '首次同步提示',
          description: '初始同步会建立本地和云端文件映射，耗时取决于文件数量和网络速度。',
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: _isFinishing ? null : _back,
              child: const Text('上一步'),
            )
          else
            TextButton(
              onPressed: _isFinishing
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text('返回'),
            ),
          const Spacer(),
          if (_step < _lastStep)
            FilledButton(onPressed: _next, child: const Text('下一步'))
          else
            FilledButton.icon(
              onPressed: _isFinishing ? null : _finish,
              icon: _isFinishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_outlined),
              label: const Text('保存并开始同步'),
            ),
        ],
      ),
    );
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'album_download' => '仅下载到手机相册',
      _ => '仅上传手机相册',
    };
  }
}

class _WizardProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _WizardProgress({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final active = index <= currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _WizardStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _WizardStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(icon, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle) : null,
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String path;
  final Widget? action;

  const _PathTile({
    required this.icon,
    required this.title,
    required this.path,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: action,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
