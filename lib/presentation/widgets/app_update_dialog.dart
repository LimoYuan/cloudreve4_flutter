import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo update;
  final String currentVersion;
  final String currentBuild;
  final String? preDownloadedPath;

  const AppUpdateDialog({
    super.key,
    required this.update,
    required this.currentVersion,
    required this.currentBuild,
    this.preDownloadedPath,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo update,
    required String currentVersion,
    required String currentBuild,
    String? preDownloadedPath,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.force,
      builder: (_) => AppUpdateDialog(
        update: update,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
        preDownloadedPath: preDownloadedPath,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _downloading = false;
  int _received = 0;
  int _total = 0;
  String? _status;
  String? _localPackagePath;

  @override
  void initState() {
    super.initState();
    _localPackagePath = widget.preDownloadedPath;
    if (_localPackagePath != null && _localPackagePath!.isNotEmpty) {
      _status = '更新包已下载';
    }
  }


  bool get _isWindows => Platform.isWindows;
  bool get _isAndroid => Platform.isAndroid;

  String get _packageName {
    if (_isWindows) return 'Windows 更新包';
    if (_isAndroid) return 'Android 安装包';
    return '更新包';
  }

  String get _downloadStatus => '正在下载$_packageName...';

  String get _openStatus {
    if (_isWindows) return '正在打开 Windows 更新文件...';
    if (_isAndroid) return '正在打开系统安装器...';
    return '正在打开更新文件...';
  }

  String get _doneStatus {
    if (_isWindows) return '已打开 Windows 更新文件。请按提示安装，安装完成后重新启动应用。';
    if (_isAndroid) return '已打开系统安装器，请确认安装。';
    return '已打开更新文件。';
  }

  double get _progress {
    if (_total <= 0) return 0;
    return (_received / _total).clamp(0.0, 1.0);
  }

  Future<bool?> _confirmWindowsInstallNow() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !widget.update.force,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('更新包已下载'),
          content: Text(
            widget.update.force
                ? '需要关闭当前应用并打开更新程序。'
                : '是否现在关闭当前应用并打开更新程序？\n\n选择“关闭后自动更新”，则你稍后退出当前应用时会自动打开更新程序。',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            if (!widget.update.force)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('关闭后自动更新'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('现在关闭并更新'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _downloadAndOpen() async {
    if (_downloading) return;

    // GitHub 兜底：downloadUrl 是 release html_url，不能走 downloadPackage
    // （mkwOnlineUpdateEnabled == false 时第一行就 throw）。
    // 直接打开浏览器跳转 release 页面，让用户手动下载。
    if (widget.update.updateSource == AppUpdateSource.github) {
      setState(() {
        _downloading = true;
        _status = '正在打开浏览器...';
      });
      try {
        final uri = Uri.parse(widget.update.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _status = '打开失败：无法打开下载页面 ${widget.update.downloadUrl}';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _status = '打开失败：$e';
        });
      }
      return;
    }

    setState(() {
      _downloading = true;
      _received = 0;
      _total = 0;
      _status = _downloadStatus;
    });

    try {
      final service = AppUpdateService.instance;
      final path = await service.downloadPackage(
        widget.update,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _received = progress.received;
            _total = progress.total;
            _status = '$_downloadStatus ${progress.percent}%';
          });
        },
      );

      _localPackagePath = path;

      if (_isWindows) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _status = '更新包已下载';
        });

        final closeNow = await _confirmWindowsInstallNow();
        if (closeNow == null) return;

        await service.scheduleWindowsPackageInstall(
          path,
          closeCurrentAppNow: closeNow,
        );

        if (!mounted) return;
        setState(() {
          _status = closeNow
              ? '正在关闭当前应用并打开更新程序...'
              : '已安排：关闭当前应用后会自动打开更新程序。';
        });
        return;
      }

      if (_isAndroid) {
        final canInstall = await service.canRequestPackageInstalls();
        if (!canInstall) {
          if (!mounted) return;
          setState(() {
            _status = '请先允许本应用安装未知来源应用，然后返回点击“继续安装”。';
            _downloading = false;
          });
          await service.openInstallPermissionSettings();
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _status = _openStatus;
      });

      await service.openDownloadedPackage(path);
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = _doneStatus;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _status = '更新失败：$e';
      });
    }
  }

  Future<void> _continueOpen() async {
    final path = _localPackagePath;
    if (path == null || path.isEmpty) {
      await _downloadAndOpen();
      return;
    }

    setState(() {
      _downloading = true;
      _status = _isAndroid ? '正在检查安装权限...' : _openStatus;
    });

    try {
      final service = AppUpdateService.instance;
      if (_isAndroid) {
        final canInstall = await service.canRequestPackageInstalls();
        if (!canInstall) {
          setState(() {
            _downloading = false;
            _status = '请先允许本应用安装未知来源应用。';
          });
          await service.openInstallPermissionSettings();
          return;
        }
      }

      await service.openDownloadedPackage(path);
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = _doneStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = '打开失败：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changes = widget.update.changelog;
    final isGithub = widget.update.updateSource == AppUpdateSource.github;
    final actionText = isGithub
        ? '打开浏览器下载'
        : (_isWindows ? '现在更新' : '现在安装');
    final downloadButtonText = isGithub
        ? '打开浏览器下载'
        : (_localPackagePath == null
            ? (_isWindows ? '下载更新' : '下载并安装')
            : actionText);

    return PopScope(
      canPop: !widget.update.force,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              widget.update.force
                  ? LucideIcons.alertTriangle
                  : LucideIcons.downloadCloud,
              color: widget.update.force
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.update.title)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '当前版本：${widget.currentVersion} (${widget.currentBuild})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '最新版本：${widget.update.version} (${widget.update.build})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.update.fileSize != null &&
                    widget.update.fileSize!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$_packageName大小：${widget.update.fileSize}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
                if (widget.update.force) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '这是强制更新版本，需要更新后继续使用。',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '更新内容',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...changes.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_downloading || _status != null) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _total > 0 ? _progress : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _status?.startsWith('更新失败') == true ||
                              _status?.startsWith('打开失败') == true ||
                              _status?.startsWith('安装失败') == true
                          ? theme.colorScheme.error
                          : theme.hintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!widget.update.force)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_downloading ? '后台下载' : '稍后'),
            ),
          FilledButton(
            onPressed: _downloading ? null : (_localPackagePath == null ? _downloadAndOpen : _continueOpen),
            child: Text(downloadButtonText),
          ),
        ],
      ),
    );
  }
}
