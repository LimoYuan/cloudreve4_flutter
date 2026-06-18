// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/sync_defaults.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/sync_config_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/folder_picker.dart';
import '../../widgets/toast_helper.dart';

/// Desktop first-run sync setup wizard.
///
/// This is a soft gate for desktop sync: until the wizard is completed, the
/// desktop sync page does not expose normal sync controls. The user can still
/// leave the sync page and use other parts of the app.
// AI_DESKTOP_SYNC_WIZARD_PAGE_V3
class DesktopSyncWizardPage extends StatefulWidget {
  const DesktopSyncWizardPage({super.key});

  @override
  State<DesktopSyncWizardPage> createState() => _DesktopSyncWizardPageState();
}

class _DesktopSyncWizardPageState extends State<DesktopSyncWizardPage> {
  final PageController _pageController = PageController();
  late final TextEditingController _localRootController;

  int _step = 0;
  String _remoteRoot = SyncDefaults.defaultRemoteRoot;
  String _syncMode = Platform.isWindows || Platform.isLinux
      ? 'mirror_wcf'
      : SyncDefaults.defaultSyncMode;
  String _conflictStrategy = SyncDefaults.defaultConflictStrategy;
  String _wcfDeleteMode = 'wcf_delete_local_only';
  int _maxConcurrent = SyncDefaults.defaultMaxConcurrentTransfers;
  int _bandwidthLimitKbps = SyncDefaults.defaultBandwidthLimitKbps;
  int _maxWorkers = SyncDefaults.defaultMaxWorkers;
  int _maxHydrationCacheSizeGb = 2;
  bool _isFinishing = false;

  static const int _lastStep = 5;

  bool get _isMirrorMode => _syncMode == 'mirror_wcf';
  bool get _isFullMode => _syncMode == 'full';

  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncProvider>();
    final config = sync.persistedConfig;

    _localRootController = TextEditingController(
      text: config?.localRoot.isNotEmpty == true
          ? config!.localRoot
          : SyncDefaults.defaultLocalRoot(),
    );

    if (config != null) {
      _remoteRoot = config.remoteRoot;
      _syncMode = config.syncMode;
      _conflictStrategy = config.conflictStrategy;
      _wcfDeleteMode = config.wcfDeleteMode;
      _maxConcurrent = config.maxConcurrentTransfers;
      _bandwidthLimitKbps = config.bandwidthLimitKbps;
      _maxWorkers = config.maxWorkers;
      _maxHydrationCacheSizeGb = config.maxHydrationCacheSizeGb;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _localRootController.dispose();
    super.dispose();
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

  Future<void> _pickLocalFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择本地同步目录',
      initialDirectory: _localRootController.text.isNotEmpty
          ? _localRootController.text
          : null,
    );
    if (result == null || result.isEmpty) return;
    setState(() => _localRootController.text = result);
  }

  Future<void> _pickRemoteFolder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择远程同步目录'),
        content: SizedBox(
          width: 520,
          height: 560,
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

  Future<void> _finish() async {
    if (_isFinishing) return;

    final localRoot = _localRootController.text.trim();
    if (localRoot.isEmpty) {
      ToastHelper.failure('请选择本地同步目录');
      return;
    }

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
      final appSupportDir = await getApplicationSupportDirectory();
      final config = SyncConfigModel(
        baseUrl: server.baseUrl,
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        localRoot: localRoot,
        remoteRoot: _remoteRoot,
        syncMode: _syncMode,
        conflictStrategy: _conflictStrategy,
        wcfDeleteMode: _wcfDeleteMode,
        maxConcurrentTransfers: _maxConcurrent,
        bandwidthLimitKbps: _bandwidthLimitKbps,
        maxWorkers: _maxWorkers,
        dataDir: appSupportDir.path,
        clientId: '',
        logLevel: SyncDefaults.defaultLogLevel,
        maxHydrationCacheSizeGb: _maxHydrationCacheSizeGb,
      );

      final savedConfig = await sync.saveDesktopSyncWizardConfig(config);
      await sync.completeDesktopSyncWizard();
      await sync.startSync(savedConfig);

      if (!mounted) return;
      ToastHelper.success('桌面同步已配置并开始');
      Navigator.of(context).pop(true);
    } catch (e) {
      AppLogger.e('桌面端同步向导完成失败: $e');
      if (mounted) ToastHelper.failure('同步设置失败：$e');
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('桌面同步设置向导'),
      ),
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
                  _buildBehaviorStep(context),
                  _buildPerformanceStep(context),
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
      icon: Icons.desktop_windows_outlined,
      title: '设置桌面文件同步',
      subtitle: '完成向导前不能启动文件同步，但可以离开同步页继续使用其它功能。',
      children: [
        const _InfoTile(
          icon: Icons.folder_outlined,
          title: '软强制配置',
          description: '向导只限制同步功能，不会锁住整个应用。未完成时可以随时返回其它页面。',
        ),
        const _InfoTile(
          icon: Icons.sync_alt_outlined,
          title: '桌面专属选项',
          description: '桌面端包含镜像同步、冲突处理、并发、带宽、WCF/FUSE 行为等更多设置。',
        ),
        const _InfoTile(
          icon: Icons.folder_copy_outlined,
          title: '目录先确认',
          description: '请选择稳定的本地同步目录和云端根目录。首次同步会建立映射，耗时取决于文件数量。',
        ),
        const SizedBox(height: 12),
        Text(
          '建议先使用空目录或测试目录确认行为，再切换到正式同步目录。',
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
      subtitle: '桌面端可选择镜像、全量、仅上传或仅下载。',
      children: [
        if (Platform.isWindows || Platform.isLinux)
          _ModeCard(
            selected: _syncMode == 'mirror_wcf',
            icon: Icons.cloud_queue,
            title: '镜像同步',
            badge: '推荐',
            subtitle: '本地保留占位文件，打开时按需下载。Windows 使用 WCF，Linux 使用 FUSE。',
            onTap: () => setState(() => _syncMode = 'mirror_wcf'),
          ),
        if (Platform.isWindows || Platform.isLinux) const SizedBox(height: 12),
        _ModeCard(
          selected: _syncMode == 'full',
          icon: Icons.sync_outlined,
          title: '全量同步',
          subtitle: '双向同步本地和云端，适合需要完整离线副本的目录。',
          onTap: () => setState(() => _syncMode = 'full'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          selected: _syncMode == 'upload_only',
          icon: Icons.cloud_upload_outlined,
          title: '仅上传',
          subtitle: '只把本地文件同步到云端，不主动下载远程文件。',
          onTap: () => setState(() => _syncMode = 'upload_only'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          selected: _syncMode == 'download_only',
          icon: Icons.cloud_download_outlined,
          title: '仅下载',
          subtitle: '只把云端文件同步到本地，不主动上传本地修改。',
          onTap: () => setState(() => _syncMode = 'download_only'),
        ),
      ],
    );
  }

  Widget _buildPathStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.folder_outlined,
      title: '选择同步目录',
      subtitle: '同步目录决定文件映射范围。不要选择系统目录或临时下载目录。',
      children: [
        _PathTile(
          icon: Icons.folder_open_outlined,
          title: '本地目录',
          path: _localRootController.text,
          action: TextButton(
            onPressed: _pickLocalFolder,
            child: const Text('选择'),
          ),
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

  Widget _buildBehaviorStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.tune_outlined,
      title: '同步行为',
      subtitle: '这些设置只影响桌面端同步行为。之后也可以在同步设置里修改。',
      children: [
        if (_isFullMode)
          _OptionCard(
            icon: Icons.merge_outlined,
            title: '冲突解决策略',
            value: _conflictStrategyLabel(_conflictStrategy),
            onTap: _pickConflictStrategy,
          ),
        if (_isFullMode && _isMirrorMode) const SizedBox(height: 12),
        if (_isMirrorMode)
          _OptionCard(
            icon: Icons.delete_outline,
            title: '本地删除行为',
            value: _wcfDeleteModeLabel(_wcfDeleteMode),
            onTap: _pickWcfDeleteMode,
          ),
        if (!_isFullMode && !_isMirrorMode)
          const _InfoTile(
            icon: Icons.info_outline,
            title: '当前模式无需额外行为设置',
            description: '仅上传和仅下载模式不会启用双向冲突处理。',
          ),
      ],
    );
  }

  Widget _buildPerformanceStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.speed_outlined,
      title: '性能设置',
      subtitle: '并发越高速度可能越快，但也会增加 CPU、磁盘和网络压力。',
      children: [
        _OptionCard(
          icon: Icons.work_outline,
          title: '最大并发任务数',
          value: _maxWorkersLabel,
          onTap: _pickMaxWorkers,
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.sync_outlined,
          title: '最大并发传输数',
          value: '$_maxConcurrent',
          onTap: _pickConcurrency,
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.speed_outlined,
          title: '带宽限制',
          value: _bandwidthLimitKbps > 0
              ? '${(_bandwidthLimitKbps / 1024).toStringAsFixed(1)} MB/s'
              : '不限制',
          onTap: _pickBandwidthLimit,
        ),
        if (Platform.isLinux && _isMirrorMode) ...[
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.sd_storage_outlined,
            title: '水合缓存大小',
            value: '$_maxHydrationCacheSizeGb GB',
            onTap: _pickHydrationCacheSize,
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    return _WizardStep(
      icon: Icons.task_alt_outlined,
      title: '确认并开始',
      subtitle: '保存配置后会启动初始同步。未完成向导前，同步页不会开放开始同步。',
      children: [
        _SummaryRow(label: '同步方式', value: _modeLabel(_syncMode)),
        _SummaryRow(label: '本地目录', value: _localRootController.text),
        _SummaryRow(label: '云端目录', value: _remoteRoot),
        if (_isFullMode)
          _SummaryRow(label: '冲突策略', value: _conflictStrategyLabel(_conflictStrategy)),
        if (_isMirrorMode)
          _SummaryRow(label: '删除行为', value: _wcfDeleteModeLabel(_wcfDeleteMode)),
        _SummaryRow(label: '任务并发', value: _maxWorkersLabel),
        _SummaryRow(label: '传输并发', value: '$_maxConcurrent'),
        _SummaryRow(
          label: '带宽限制',
          value: _bandwidthLimitKbps > 0
              ? '${(_bandwidthLimitKbps / 1024).toStringAsFixed(1)} MB/s'
              : '不限制',
        ),
        const SizedBox(height: 16),
        const _InfoTile(
          icon: Icons.warning_amber_outlined,
          title: '首次同步提示',
          description: '首次同步会扫描本地和云端文件，并建立映射。请不要在中途移动同步根目录。',
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
              child: const Text('稍后再说'),
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

  Future<void> _pickConflictStrategy() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'keep_both',
              groupValue: _conflictStrategy,
              onChanged: (v) => Navigator.pop(ctx, v),
              title: const Text('保留两者'),
              subtitle: const Text('冲突文件自动重命名保留'),
            ),
            RadioListTile<String>(
              value: 'local_wins',
              groupValue: _conflictStrategy,
              onChanged: (v) => Navigator.pop(ctx, v),
              title: const Text('本地优先'),
              subtitle: const Text('冲突时使用本地版本'),
            ),
            RadioListTile<String>(
              value: 'remote_wins',
              groupValue: _conflictStrategy,
              onChanged: (v) => Navigator.pop(ctx, v),
              title: const Text('云端优先'),
              subtitle: const Text('冲突时使用云端版本'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _conflictStrategy = result);
  }

  Future<void> _pickWcfDeleteMode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'wcf_delete_local_only',
              groupValue: _wcfDeleteMode,
              onChanged: (v) => Navigator.pop(ctx, v),
              title: const Text('仅本地删除'),
              subtitle: const Text('本地删除只移除占位/缓存，不删除云端文件'),
            ),
            RadioListTile<String>(
              value: 'wcf_delete_remote',
              groupValue: _wcfDeleteMode,
              onChanged: (v) => Navigator.pop(ctx, v),
              title: const Text('同步删除云端'),
              subtitle: const Text('本地删除会同步删除云端文件，请谨慎使用'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _wcfDeleteMode = result);
  }

  Future<void> _pickConcurrency() async {
    final result = await _pickNumber(
      title: '最大并发传输数',
      current: _maxConcurrent,
      min: 1,
      max: 16,
    );
    if (result != null) setState(() => _maxConcurrent = result);
  }

  Future<void> _pickMaxWorkers() async {
    final result = await _pickNumber(
      title: '最大并发任务数',
      current: _maxWorkers,
      min: 0,
      max: 32,
      zeroLabel: '0 表示自动使用 CPU 核心数',
    );
    if (result != null) setState(() => _maxWorkers = result);
  }

  Future<void> _pickBandwidthLimit() async {
    final result = await _pickNumber(
      title: '带宽限制 KB/s',
      current: _bandwidthLimitKbps,
      min: 0,
      max: 1024 * 1024,
      zeroLabel: '0 表示不限制',
    );
    if (result != null) setState(() => _bandwidthLimitKbps = result);
  }

  Future<void> _pickHydrationCacheSize() async {
    final result = await _pickNumber(
      title: '水合缓存大小 GB',
      current: _maxHydrationCacheSizeGb,
      min: 1,
      max: 100,
    );
    if (result != null) setState(() => _maxHydrationCacheSizeGb = result);
  }

  Future<int?> _pickNumber({
    required String title,
    required int current,
    required int min,
    required int max,
    String? zeroLabel,
  }) async {
    final controller = TextEditingController(text: '$current');
    try {
      return await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              helperText: zeroLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text) ?? current;
                Navigator.pop(ctx, value.clamp(min, max));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String get _maxWorkersLabel {
    if (_maxWorkers <= 0) return '自动（CPU 核心数）';
    return '$_maxWorkers';
  }

  String _modeLabel(String mode) {
    return switch (mode) {
      'mirror_wcf' => Platform.isLinux ? '镜像同步（FUSE）' : '镜像同步（WCF）',
      'upload_only' => '仅上传本地到云端',
      'download_only' => '仅下载云端到本地',
      _ => '全量双向同步',
    };
  }

  String _conflictStrategyLabel(String strategy) {
    return switch (strategy) {
      'local_wins' => '本地优先',
      'remote_wins' => '云端优先',
      _ => '保留两者',
    };
  }

  String _wcfDeleteModeLabel(String mode) {
    return switch (mode) {
      'wcf_delete_remote' => '同步删除云端',
      _ => '仅本地删除',
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
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
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
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
  final String? badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Row(
          children: [
            Flexible(child: Text(title)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
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
        subtitle: Text(
          path.isEmpty ? '未选择' : path,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: action,
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
            width: 96,
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
