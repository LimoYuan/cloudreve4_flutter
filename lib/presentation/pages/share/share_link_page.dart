import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../../data/models/share_model.dart';
import '../../../router/app_router.dart';
import '../../../services/share_link_service.dart';
import '../../providers/download_manager_provider.dart';
import '../../widgets/folder_picker.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/user_avatar.dart';

class ShareLinkPage extends StatefulWidget {
  final ShareLinkCandidate candidate;

  const ShareLinkPage({super.key, required this.candidate});

  @override
  State<ShareLinkPage> createState() => _ShareLinkPageState();
}

class _ShareLinkPageState extends State<ShareLinkPage> {
  final TextEditingController _passwordController = TextEditingController();
  final List<_Crumb> _crumbs = <_Crumb>[];

  late ShareContext _context;
  ShareModel? _info;
  List<ShareLinkFile> _files = const [];
  String? _currentUri;
  Object? _error;
  Object? _fileError;
  bool _loadingInfo = true;
  bool _loadingFiles = false;
  bool _busyDownload = false;
  bool _busySave = false;

  @override
  void initState() {
    super.initState();
    _context = ShareLinkService.instance.createContext(widget.candidate);
    _passwordController.text = widget.candidate.password ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInfo(password: widget.candidate.password);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────── 数据 ───────────────

  Future<void> _loadInfo({String? password}) async {
    setState(() {
      _loadingInfo = true;
      _error = null;
      _fileError = null;
      _files = const [];
      _currentUri = null;
      _crumbs.clear();
    });

    _context = ShareLinkService.instance.createContext(
      ShareLinkCandidate(
        id: widget.candidate.id,
        url: widget.candidate.url,
        password: password?.trim().isEmpty == true ? null : password?.trim(),
      ),
    );

    ShareModel info;
    try {
      info = await ShareLinkService.instance.fetchShareInfo(_context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingInfo = false;
      });
      return;
    }

    if (!mounted) return;

    // 密码鉴权：弹对话框输入密码直到 unlocked / 用户取消
    // 弹窗期间停掉背景的加载动画，避免进度条 / 刷新指示器在背后转。
    if (info.passwordProtected == true && !info.unlocked) {
      setState(() {
        _loadingInfo = false;
      });
    }
    while (info.passwordProtected == true && !info.unlocked) {
      final entered = await _promptPasswordDialog(
        retry: password != null && password.trim().isNotEmpty,
      );
      if (!mounted) return;
      if (entered == null) {
        // 用户取消 → 退出页面
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      password = entered;
      _passwordController.text = entered;
      _context = ShareLinkService.instance.createContext(
        ShareLinkCandidate(
          id: widget.candidate.id,
          url: widget.candidate.url,
          password: entered.isEmpty ? null : entered,
        ),
      );
      try {
        info = await ShareLinkService.instance.fetchShareInfo(_context);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _loadingInfo = false;
        });
        return;
      }
      if (!mounted) return;
    }

    setState(() {
      _info = info;
      _loadingInfo = false;
    });

    if (info.expired) return;

    if (info.isFolder) {
      final rootUri = _context.buildShareUri(trailingSlash: true);
      _crumbs.add(_Crumb(title: info.name, uri: rootUri));
      await _loadFolder(rootUri);
    }
  }

  /// 弹出密码输入对话框。返回 null 表示用户取消。
  Future<String?> _promptPasswordDialog({bool retry = false}) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _SharePasswordDialog(
        initialPassword: _passwordController.text,
        retry: retry,
      ),
    );
  }

  Future<void> _loadFolder(String uri) async {
    setState(() {
      _loadingFiles = true;
      _fileError = null;
      _currentUri = uri;
    });

    try {
      final result = await ShareLinkService.instance.listSharedFiles(
        context: _context,
        uri: uri,
      );
      if (!mounted) return;
      setState(() {
        _files = result.files;
        _loadingFiles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError = e;
        _loadingFiles = false;
      });
    }
  }

  Future<void> _refresh() async {
    final info = _info;
    if (info == null || _crumbs.isEmpty) {
      await _loadInfo(password: _passwordController.text.trim());
      return;
    }
    if (info.isFolder) {
      await _loadFolder(_crumbs.last.uri);
    } else {
      await _loadInfo(password: _passwordController.text.trim());
    }
  }

  // ─────────────── 操作 ───────────────

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.candidate.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 下载（同源/异源均直接走预签名 URL，绕过 token 鉴权）
  Future<void> _download({
    required String fileName,
    required int fileSize,
    String? candidateUri,
    bool archive = false,
  }) async {
    if (_busyDownload) return;
    setState(() => _busyDownload = true);
    try {
      final result = await ShareLinkService.instance.resolveDownloadUrl(
        context: _context,
        candidateUri: candidateUri,
        fileName: fileName,
        archive: archive,
      );

      if (!mounted) return;
      final downloadManager = context.read<DownloadManagerProvider>();
      final pseudoUri = 'share://${_context.id}/${Uri.encodeComponent(fileName)}'
          '${archive ? '?archive=1' : ''}';
      final task = await downloadManager.addDownloadTask(
        fileName: archive ? '$fileName.zip' : fileName,
        fileUri: pseudoUri,
        fileSize: fileSize,
        downloadUrl: result.url,
      );

      if (!mounted) return;
      ToastHelper.success(task == null ? '该文件已在下载队列中' : '已添加到下载队列');
    } catch (e) {
      if (!mounted) return;
      if (_isGroupForbidden(e)) {
        ToastHelper.failure(
          archive
              ? '所在用户组不允许打包下载，请联系管理员开通'
              : '所在用户组不允许下载，请联系管理员开通',
        );
      } else {
        ToastHelper.failure('下载失败：$e');
      }
    } finally {
      if (mounted) setState(() => _busyDownload = false);
    }
  }

  /// 转存（仅同源）
  Future<void> _saveToCloud({
    required String name,
    String? candidateUri,
    bool isFolder = false,
  }) async {
    if (_busySave) return;
    if (!_context.isSameOrigin) {
      await _confirmCrossOriginAndJump(
        name: name,
        candidateUri: candidateUri,
        isFolder: isFolder,
      );
      return;
    }

    final destination = await _pickDestination();
    if (destination == null || !mounted) return;
    setState(() => _busySave = true);

    try {
      final uri = candidateUri ?? _context.buildShareUri(subPath: name);
      await ShareLinkService.instance.saveSharedFiles(
        context: _context,
        uris: [uri],
        destination: destination,
      );
      if (!mounted) return;
      ToastHelper.success('已转存「$name」到 $destination');
    } catch (e) {
      if (!mounted) return;
      if (e is ServerException &&
          e.code == 40081 &&
          e.message.contains('Not supported action')) {
        ToastHelper.failure('转存为Pro版本专属功能, 您当前版本不支持, errorcode: $e');
      } else {
        ToastHelper.failure('转存失败：$e');
      }
    } finally {
      if (mounted) setState(() => _busySave = false);
    }
  }

  /// 异源场景：弹确认对话框 → 拿下载链接 → 跳离线下载页自动弹新建框
  ///
  /// 目录场景下必须走 archive 打包，否则后端无法为目录生成下载链接（40081）。
  Future<void> _confirmCrossOriginAndJump({
    required String name,
    String? candidateUri,
    bool isFolder = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFolder ? '异源文件夹转存需先打包' : '异源分享不支持直接转存',
        ),
        content: Text(
          isFolder
              ? '该分享来自其他 Cloudreve 站点，文件夹无法直接转存。\n\n'
                  '将先把「$name」打包成 zip，再通过「离线下载」由服务器拉取后保存到你的网盘。是否继续？'
              : '该分享来自其他 Cloudreve 站点，无法直接转存到当前账号。\n\n'
                  '可以使用「离线下载」由服务器下载该文件，再保存到你的网盘。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('前往离线下载'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await ShareLinkService.instance.resolveDownloadUrl(
        context: _context,
        candidateUri: candidateUri,
        fileName: name,
        archive: isFolder,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        RouteNames.remoteDownload,
        arguments: <String, dynamic>{'prefillUrl': result.url},
      );
    } catch (e) {
      if (!mounted) return;
      if (_isGroupForbidden(e)) {
        ToastHelper.failure(
          isFolder
              ? '所在用户组不允许打包下载，请联系管理员开通'
              : '所在用户组不允许下载，请联系管理员开通',
        );
      } else {
        ToastHelper.failure('获取下载链接失败：$e');
      }
    }
  }

  Future<String?> _pickDestination() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '选择转存位置',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              FolderPicker(
                currentPath: '/',
                maxVisibleItems: 7,
                onFolderSelected: (path) => Navigator.of(context).pop(path),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enterFolder(ShareLinkFile file) async {
    if (!file.isFolder) return;
    final uri = file.path.isNotEmpty
        ? file.path
        : _context.buildShareUri(
            subPath: _crumbs.length > 1
                ? '${_crumbs.skip(1).map((c) => c.title).join('/')}/${file.name}'
                : file.name,
          );
    _crumbs.add(_Crumb(title: file.name, uri: uri));
    await _loadFolder(uri);
  }

  Future<void> _jumpCrumb(int index) async {
    if (index < 0 || index >= _crumbs.length) return;
    _crumbs.removeRange(index + 1, _crumbs.length);
    await _loadFolder(_crumbs[index].uri);
  }

  Future<bool> _handleBack() async {
    if (_crumbs.length > 1) {
      _crumbs.removeLast();
      await _loadFolder(_crumbs.last.uri);
      return false;
    }
    return true;
  }

  // ─────────────── 构建 ───────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _crumbs.length <= 1,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('文件分享'),
          actions: [
            IconButton(
              tooltip: '浏览器打开',
              icon: const Icon(LucideIcons.externalLink),
              onPressed: _openInBrowser,
            ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 14),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final info = _info;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingInfo && info == null)
              const LinearProgressIndicator()
            else if (info != null)
              _buildOwnerRow(info)
            else
              _buildLoadingOwnerFallback(),
            if (info != null) ...[
              const SizedBox(height: 14),
              _buildSummaryBlock(info),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(
                text: _isExpiredError(_error)
                    ? '分享链接已过期或不存在'
                    : '分享信息读取失败：$_error',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOwnerFallback() {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.ios_share, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '分享链接',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerRow(ShareModel info) {
    final theme = Theme.of(context);
    final ownerName = info.owner?.nickname.trim().isNotEmpty == true
        ? info.owner!.nickname.trim()
        : '匿名用户';
    final ownerId = info.owner?.id ?? '';
    final showSameOriginAvatar = _context.isSameOrigin && ownerId.isNotEmpty;

    return Row(
      children: [
        showSameOriginAvatar
            ? UserAvatar(userId: ownerId, displayName: ownerName, radius: 29)
            : CircleAvatar(
                radius: 29,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  '匿',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '向您分享了 ${info.isFolder ? '一个文件夹' : '一个文件'}'
                '${_context.isSameOrigin ? '' : ' · 异源'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(
          text: info.expired ? '已过期' : '有效',
          color: info.expired ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildSummaryBlock(ShareModel info) {
    final theme = Theme.of(context);
    final sizeText = info.size != null && info.size! > 0
        ? _formatSize(info.size!)
        : null;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                info.isFolder ? LucideIcons.folder : LucideIcons.file,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScrollableFileName(
                  name: info.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  onTap: () => _showInfoDetailDialog(info),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(icon: LucideIcons.eye, text: '${info.visited} 次访问'),
              if ((info.downloaded ?? 0) > 0)
                _MetaChip(icon: LucideIcons.download, text: '${info.downloaded} 次下载'),
              if (sizeText != null) _MetaChip(icon: Icons.sd_storage_outlined, text: sizeText),
              _MetaChip(icon: LucideIcons.calendar, text: '${_formatDate(info.createdAt)} 创建'),
              if (info.expires != null)
                _MetaChip(
                  icon: LucideIcons.clock,
                  text: _expireChipText(info.expires!),
                ),
              if (info.passwordProtected == true) const _MetaChip(icon: LucideIcons.lock, text: '私密分享'),
              if (!_context.isSameOrigin) const _MetaChip(icon: LucideIcons.globe, text: '异源分享'),
            ],
          ),
        ],
      ),
    );
  }

  /// 判断错误是否为「分享链接过期」类的服务端错误。
  bool _isExpiredError(Object? error) {
    if (error is ShareException) {
      if (error.code == 404) return true;
      final msg = error.message.trim().toLowerCase();
      if (msg == 'share link expired') return true;
      if (msg.contains('share link expired')) return true;
    }
    return false;
  }

  /// 判断错误是否为「用户组无权打包/下载」(40007)。
  bool _isGroupForbidden(Object? error) {
    if (error is ShareException && error.code == 40007) return true;
    final msg = error?.toString().toLowerCase() ?? '';
    return msg.contains('group not allowed');
  }

  Widget _buildBody() {
    final info = _info;
    if (_loadingInfo && info == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (info == null) {
      if (_isExpiredError(_error)) {
        return const _EmptyState(
          icon: LucideIcons.clock,
          title: '分享已过期',
          subtitle: '这个分享链接已经失效或不存在。',
        );
      }
      return _EmptyState(
        icon: LucideIcons.link,
        title: '无法打开分享',
        subtitle: '请检查链接是否正确，或输入分享密码后重试。',
        actionText: '浏览器打开',
        onAction: _openInBrowser,
      );
    }
    if (info.expired) {
      return const _EmptyState(
        icon: LucideIcons.clock,
        title: '分享已过期',
        subtitle: '这个分享链接已经失效。',
      );
    }
    if (info.passwordProtected == true && !info.unlocked) {
      return const _EmptyState(
        icon: LucideIcons.lock,
        title: '需要分享密码',
        subtitle: '输入正确的分享密码后即可查看文件。',
      );
    }
    if (info.isFile) {
      return _buildSingleFileCard(info);
    }
    return _buildFolderList(info);
  }

  Widget _buildSingleFileCard(ShareModel info) {
    final theme = Theme.of(context);
    final sizeText = info.size != null && info.size! > 0
        ? _formatSize(info.size!)
        : null;
    final iconData = _ShareFileTile._iconForFile(info.name);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, size: 26, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScrollableFileName(
                        name: info.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        onTap: () => _showInfoDetailDialog(info),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (sizeText != null)
                            _MetaChip(icon: Icons.sd_storage_outlined, text: sizeText),
                          _MetaChip(
                            icon: LucideIcons.calendar,
                            text: _formatDate(info.createdAt),
                          ),
                          _MetaChip(
                            icon: LucideIcons.eye,
                            text: '${info.visited}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildActionButtons(
              name: info.name,
              fileSize: info.size ?? 0,
              archive: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderList(ShareModel info) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '文件列表',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 目录可整体打包下载
        _buildActionButtons(
          name: info.name,
          fileSize: info.size ?? 0,
          archive: true,
          candidateUri: _crumbs.isNotEmpty ? _crumbs.last.uri : null,
        ),
        if (_crumbs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCrumbs(),
        ],
        const SizedBox(height: 12),
        if (_loadingFiles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_fileError != null)
          _ErrorBox(
            text: '文件列表读取失败：$_fileError',
            actionText: '重试',
            onAction: _currentUri == null ? null : () => _loadFolder(_currentUri!),
          )
        else if (_files.isEmpty)
          const _EmptyState(
            icon: LucideIcons.folderOpen,
            title: '文件夹为空',
            subtitle: '这个分享目录下没有文件。',
          )
        else
          ..._files.map(
            (file) => _ShareFileTile(
              file: file,
              onTap: file.isFolder ? () => _enterFolder(file) : null,
              onDownload: file.isFile
                  ? () => _download(
                        fileName: file.name,
                        fileSize: file.size,
                        candidateUri: file.path.isNotEmpty ? file.path : null,
                      )
                  : null,
              // 转存按钮：同源直接转，异源也显示但点了走异源确认流程
              onSave: () => _saveToCloud(
                name: file.name,
                candidateUri: file.path.isNotEmpty ? file.path : null,
                isFolder: file.isFolder,
              ),
              showCrossOriginHint: !_context.isSameOrigin,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons({
    required String name,
    required int fileSize,
    String? candidateUri,
    bool archive = false,
  }) {
    final saveBtn = FilledButton.tonalIcon(
      onPressed: _busySave
          ? null
          : () => _saveToCloud(
                name: name,
                candidateUri: candidateUri,
                isFolder: archive,
              ),
      icon: _busySave
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.drive_folder_upload_outlined, size: 16),
      label: const Text('转存'),
    );
    final downloadBtn = FilledButton.icon(
      onPressed: _busyDownload
          ? null
          : () => _download(
                fileName: name,
                fileSize: fileSize,
                candidateUri: candidateUri,
                archive: archive,
              ),
      icon: _busyDownload
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.download, size: 16),
      label: const Text('下载'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        if (narrow) {
          // 窄屏：一左一右，两端对齐
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [saveBtn, downloadBtn],
          );
        }
        // 宽屏：内容宽度 + 整体靠右
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            saveBtn,
            const SizedBox(width: 10),
            downloadBtn,
          ],
        );
      },
    );
  }

  Widget _buildCrumbs() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_crumbs.length, (index) {
            final item = _crumbs[index];
            final isLast = index == _crumbs.length - 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: isLast ? null : () => _jumpCrumb(index),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                        color: isLast ? theme.colorScheme.primary : theme.hintColor,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _showInfoDetailDialog(ShareModel info) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ShareInfoDetailDialog(
        info: info,
        context_: _context,
        candidateUrl: widget.candidate.url,
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  /// 友好的过期提示：今天前 → "已过期"；今天后 → "N 天后过期" 或具体日期
  static String _expireChipText(DateTime value) {
    final now = DateTime.now();
    final diff = value.toLocal().difference(now);
    if (diff.isNegative) return '已过期';
    if (diff.inDays <= 0) return '今天过期';
    if (diff.inDays <= 30) return '${diff.inDays} 天后过期';
    return '${_formatDate(value)} 过期';
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final text = unitIndex == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$text ${units[unitIndex]}';
  }
}

class _Crumb {
  final String title;
  final String uri;
  const _Crumb({required this.title, required this.uri});
}

class _ShareFileTile extends StatelessWidget {
  final ShareLinkFile file;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onSave;
  final bool showCrossOriginHint;

  const _ShareFileTile({
    required this.file,
    this.onTap,
    this.onDownload,
    this.onSave,
    this.showCrossOriginHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = file.isFolder ? LucideIcons.folder : _iconForFile(file.name);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: file.isFolder
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: file.isFolder
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          file.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            file.isFolder ? '文件夹' : _ShareLinkPageState._formatSize(file.size),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: file.isFolder
            ? const Icon(Icons.chevron_right)
            : Wrap(
                spacing: 2,
                children: [
                  if (onSave != null)
                    IconButton(
                      tooltip: showCrossOriginHint ? '通过离线下载转存' : '转存',
                      icon: const Icon(Icons.drive_folder_upload_outlined),
                      onPressed: onSave,
                    ),
                  if (onDownload != null)
                    IconButton(
                      tooltip: '下载',
                      icon: const Icon(LucideIcons.download),
                      onPressed: onDownload,
                    ),
                ],
              ),
      ),
    );
  }

  static IconData _iconForFile(String name) {
    final lower = name.toLowerCase();
    if (RegExp(r'\.(png|jpg|jpeg|gif|webp|bmp|heic)$').hasMatch(lower)) {
      return LucideIcons.image;
    }
    if (RegExp(r'\.(mp4|mkv|mov|avi|webm|flv)$').hasMatch(lower)) {
      return LucideIcons.video;
    }
    if (RegExp(r'\.(mp3|wav|flac|aac|ogg|m4a)$').hasMatch(lower)) {
      return LucideIcons.music;
    }
    if (RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(lower)) {
      return LucideIcons.archive;
    }
    if (RegExp(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|md)$').hasMatch(lower)) {
      return LucideIcons.fileText;
    }
    return LucideIcons.file;
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.hintColor),
          const SizedBox(width: 5),
          Text(text, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  const _ErrorBox({required this.text, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionText!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}

/// 可横向滚动的文件名：长文件名不换行，鼠标滚轮或手势拖动查看；点击触发回调。
class _ScrollableFileName extends StatefulWidget {
  final String name;
  final TextStyle? style;
  final VoidCallback? onTap;

  const _ScrollableFileName({
    required this.name,
    this.style,
    this.onTap,
  });

  @override
  State<_ScrollableFileName> createState() => _ScrollableFileNameState();
}

class _ScrollableFileNameState extends State<_ScrollableFileName> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;
    final delta = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    final target = (_controller.offset + delta).clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Text(
              widget.name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }
}

/// 磨砂玻璃风格的分享详情对话框。点击文件名/info 行后展开，展示所有接口字段。
class _ShareInfoDetailDialog extends StatelessWidget {
  final ShareModel info;
  // 用尾部下划线避免与 BuildContext 同名
  final ShareContext context_;
  final String candidateUrl;

  const _ShareInfoDetailDialog({
    required this.info,
    required this.context_,
    required this.candidateUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final maxWidth = (size.width - 10).clamp(0.0, 520.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: size.height * 0.8),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        info.isFolder ? LucideIcons.folder : LucideIcons.fileText,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '分享详情',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildRows(context, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  List<Widget> _buildRows(BuildContext context, ThemeData theme) {
    final rows = <Widget>[
      _DetailRow(label: '名称', value: info.name, selectable: true),
      _DetailRow(label: '类型', value: info.isFolder ? '文件夹' : '文件'),
      _DetailRow(label: '分享 ID', value: info.id, selectable: true, mono: true),
      _DetailRow(
        label: '大小',
        value: info.size != null && info.size! > 0
            ? '${_ShareLinkPageState._formatSize(info.size!)} (${info.size} 字节)'
            : '—',
      ),
      _DetailRow(label: '访问次数', value: '${info.visited}'),
      if (info.downloaded != null)
        _DetailRow(label: '下载次数', value: '${info.downloaded}'),
      if (info.price != null && info.price! > 0)
        _DetailRow(label: '价格', value: '${info.price}'),
      _DetailRow(label: '创建时间', value: _formatDateTime(info.createdAt)),
      _DetailRow(
        label: '过期时间',
        value: info.expires == null ? '永久有效' : _formatDateTime(info.expires!),
      ),
      _DetailRow(
        label: '状态',
        value: info.expired
            ? '已过期'
            : (info.passwordProtected == true && !info.unlocked ? '需密码' : '可用'),
        valueColor: info.expired
            ? theme.colorScheme.error
            : (info.passwordProtected == true && !info.unlocked
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary),
      ),
      _DetailRow(label: '密码保护', value: (info.passwordProtected ?? false) ? '是' : '否'),
      _DetailRow(label: '已解锁', value: info.unlocked ? '是' : '否'),
      if (info.password != null && info.password!.isNotEmpty)
        _DetailRow(label: '分享密码', value: info.password!, selectable: true, mono: true),
      if (info.isPrivate != null)
        _DetailRow(label: '私密分享', value: info.isPrivate! ? '是' : '否'),
      if (info.shareView != null)
        _DetailRow(label: '允许预览', value: info.shareView! ? '是' : '否'),
      if (info.showReadme != null)
        _DetailRow(label: '显示 README', value: info.showReadme! ? '是' : '否'),
      _DetailRow(
        label: '同源',
        value: context_.isSameOrigin ? '是（同站点分享）' : '否（异源分享）',
      ),
      _DetailRow(label: '分享链接', value: candidateUrl, selectable: true, mono: true),
      if (info.url.isNotEmpty && info.url != candidateUrl)
        _DetailRow(label: '服务端 URL', value: info.url, selectable: true, mono: true),
      if (info.sourceUri != null && info.sourceUri!.isNotEmpty)
        _DetailRow(label: '源 URI', value: info.sourceUri!, selectable: true, mono: true),
      if (info.owner != null) ...[
        const SizedBox(height: 4),
        _SectionTitle(text: '分享者'),
        _DetailRow(label: '昵称', value: info.owner!.nickname),
        _DetailRow(label: '用户 ID', value: info.owner!.id, selectable: true, mono: true),
        if ((info.owner!.email ?? '').isNotEmpty)
          _DetailRow(label: '邮箱', value: info.owner!.email!, selectable: true),
        _DetailRow(label: '注册时间', value: _formatDateTime(info.owner!.createdAt)),
        if (info.owner!.group != null)
          _DetailRow(label: '用户组', value: info.owner!.group!.name),
      ],
    ];
    return rows;
  }

  static String _formatDateTime(DateTime value) {
    final l = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SharePasswordDialog extends StatefulWidget {
  final String initialPassword;
  final bool retry;

  const _SharePasswordDialog({
    required this.initialPassword,
    this.retry = false,
  });

  @override
  State<_SharePasswordDialog> createState() => _SharePasswordDialogState();
}

class _SharePasswordDialogState extends State<_SharePasswordDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final maxWidth = (size.width - 10).clamp(0.0, 420.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.lock,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '请输入分享密码',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '取消',
                          icon: const Icon(Icons.close),
                          onPressed: _cancel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.retry
                          ? '密码错误，请重新输入'
                          : '该分享受密码保护，输入正确密码后才能查看',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.retry
                            ? theme.colorScheme.error
                            : theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      obscureText: _obscure,
                      autofocus: true,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '分享密码',
                        prefixIcon: const Icon(LucideIcons.key, size: 18),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? '显示密码' : '隐藏密码',
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _cancel,
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('确认'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;
  final bool mono;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
    this.mono = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: valueColor ?? theme.colorScheme.onSurface,
      fontFamily: mono ? 'monospace' : null,
      fontWeight: FontWeight.w500,
    );
    final valueWidget = selectable
        ? SelectableText(value, style: valueStyle)
        : Text(value, style: valueStyle);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: valueWidget),
                if (selectable)
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        LucideIcons.copy,
                        size: 14,
                        color: theme.hintColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
