import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/models/download_task_model.dart';
import '../data/models/upload_task_model.dart';
import '../presentation/providers/download_manager_provider.dart';
import '../presentation/providers/sync_provider.dart';
import '../presentation/providers/upload_manager_provider.dart';
import '../presentation/widgets/toast_helper.dart';
import 'qr_login_service.dart';
import 'server_service.dart';
import 'storage_service.dart';

class FloatingUploadService {
  FloatingUploadService._();

  static final FloatingUploadService instance = FloatingUploadService._();

  static const MethodChannel _channel =
      MethodChannel('cloudreve4_flutter/floating_upload');
  static const String _enabledKey = 'desktop_floating_upload_window_enabled';

  BuildContext? _context;
  bool _initialized = false;
  bool _enabled = true;

  Future<bool> isEnabled() async {
    if (!(Platform.isWindows || Platform.isLinux)) return false;
    return await StorageService.instance.getBool(_enabledKey) ?? true;
  }

  Future<void> initialize(BuildContext context) async {
    _context = context;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    _enabled = await isEnabled();
    await _invokeSetEnabled(_enabled);
    await _syncSiteIcon();
    Future.delayed(const Duration(seconds: 2), _syncSiteIcon);
    Future.delayed(const Duration(seconds: 8), _syncSiteIcon);
  }

  Future<void> _syncSiteIcon() async {
    if (!(Platform.isWindows || Platform.isLinux)) return;

    try {
      final server = ServerService.instance.currentServer;
      if (server == null) return;

      final candidates = <String>{
        QrLoginService.faviconUrlFromCloudreve(server.baseUrl),
        '${server.baseUrl.replaceAll(RegExp(r"/+$"), "")}/favicon.ico',
      };

      for (final faviconUrl in candidates) {
        final uri = Uri.tryParse(faviconUrl);
        if (uri == null) continue;

        final response = await http.get(uri).timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 ||
            response.statusCode >= 300 ||
            response.bodyBytes.isEmpty) {
          continue;
        }

        final lowerPath = uri.path.toLowerCase();
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        final extension = lowerPath.endsWith('.png') || contentType.contains('png')
            ? 'png'
            : lowerPath.endsWith('.jpg') ||
                    lowerPath.endsWith('.jpeg') ||
                    contentType.contains('jpeg')
                ? 'jpg'
                : 'ico';

        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}${Platform.pathSeparator}floating_site_icon.$extension',
        );
        await file.writeAsBytes(response.bodyBytes, flush: true);
        await _channel.invokeMethod<bool>('setSiteIconPath', file.path);
        return;
      }
    } catch (e) {
      debugPrint('FloatingUploadService._syncSiteIcon failed: $e');
    }
  }

  Future<void> refreshSiteIcon() async {
    await _syncSiteIcon();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await StorageService.instance.setBool(_enabledKey, enabled);
    await _invokeSetEnabled(enabled);
    if (enabled) await _syncSiteIcon();
  }

  Future<void> _invokeSetEnabled(bool enabled) async {
    if (!(Platform.isWindows || Platform.isLinux)) return;
    try {
      await _channel.invokeMethod<bool>('setEnabled', enabled);
    } catch (e) {
      debugPrint('FloatingUploadService.setEnabled failed: $e');
    }
  }

  Future<void> showStatus(String message, {bool error = false}) async {
    if (!_enabled || !(Platform.isWindows || Platform.isLinux)) return;
    try {
      await _channel.invokeMethod<bool>('showStatus', {
        'message': message,
        'error': error,
      });
    } catch (e) {
      debugPrint('FloatingUploadService.showStatus failed: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFilesDropped':
        await _handleFilesDropped(call.arguments);
        return true;
      default:
        return null;
    }
  }

  Future<void> _handleFilesDropped(dynamic arguments) async {
    final context = _context;
    if (context == null || !context.mounted) {
      await showStatus('上传失败：应用尚未准备好', error: true);
      return;
    }

    final paths = <String>[];
    if (arguments is List) {
      for (final item in arguments) {
        final value = item?.toString() ?? '';
        if (value.isNotEmpty) paths.add(value);
      }
    }

    if (paths.isEmpty) {
      await showStatus('没有可上传的文件', error: true);
      return;
    }

    final files = <File>[];
    var skipped = 0;
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        files.add(File(path));
      } else {
        skipped++;
      }
    }

    if (files.isEmpty) {
      await showStatus('上传失败：暂不支持拖入文件夹', error: true);
      ToastHelper.failure('悬浮窗暂不支持直接拖入文件夹');
      return;
    }

    try {
      await showStatus('已接收文件，正在上传');
      if (!context.mounted) return;
      final uploadManager = Provider.of<UploadManagerProvider>(
        context,
        listen: false,
      );
      await uploadManager.startUpload(files, 'cloudreve://my');
      uploadManager.markShouldShowDialog();

      final suffix = skipped > 0 ? '，已忽略 $skipped 个文件夹' : '';
      await showStatus('已添加 ${files.length} 个上传任务$suffix');
      ToastHelper.success('已添加 ${files.length} 个上传任务');
    } catch (e) {
      await showStatus('上传失败：$e', error: true);
      ToastHelper.failure('悬浮窗上传失败: $e');
    }
  }
}

class FloatingUploadBridge extends StatefulWidget {
  final Widget child;

  const FloatingUploadBridge({
    super.key,
    required this.child,
  });

  @override
  State<FloatingUploadBridge> createState() => _FloatingUploadBridgeState();
}

class _FloatingUploadBridgeState extends State<FloatingUploadBridge> {
  UploadManagerProvider? _uploadManager;
  DownloadManagerProvider? _downloadManager;
  SyncProvider? _syncProvider;

  final Map<String, UploadStatus> _uploadStatuses = <String, UploadStatus>{};
  final Map<String, DownloadStatus> _downloadStatuses = <String, DownloadStatus>{};

  bool _syncHadActiveWork = false;
  bool _syncWasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FloatingUploadService.instance.initialize(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachProviders();
  }

  void _attachProviders() {
    final upload = context.read<UploadManagerProvider>();
    if (_uploadManager != upload) {
      _uploadManager?.removeListener(_onUploadChanged);
      _uploadManager = upload;
      _snapshotUploadStatuses(upload);
      upload.addListener(_onUploadChanged);
    }

    final download = context.read<DownloadManagerProvider>();
    if (_downloadManager != download) {
      _downloadManager?.removeListener(_onDownloadChanged);
      _downloadManager = download;
      _snapshotDownloadStatuses(download);
      download.addListener(_onDownloadChanged);
    }

    final sync = context.read<SyncProvider>();
    if (_syncProvider != sync) {
      _syncProvider?.removeListener(_onSyncChanged);
      _syncProvider = sync;
      _syncHadActiveWork = sync.isActive || sync.activeWorkerCount > 0;
      _syncWasError = sync.hasError;
      sync.addListener(_onSyncChanged);
    }
  }

  void _snapshotUploadStatuses(UploadManagerProvider upload) {
    _uploadStatuses
      ..clear()
      ..addEntries(upload.allTasks.map((task) => MapEntry(task.id, task.status)));
  }

  void _snapshotDownloadStatuses(DownloadManagerProvider download) {
    _downloadStatuses
      ..clear()
      ..addEntries(download.tasks.map((task) => MapEntry(task.id, task.status)));
  }

  void _onUploadChanged() {
    final upload = _uploadManager;
    if (upload == null) return;

    for (final task in upload.allTasks) {
      final previous = _uploadStatuses[task.id];
      if (previous != task.status) {
        if (task.status == UploadStatus.completed) {
          FloatingUploadService.instance.showStatus('上传成功：${task.fileName}');
        } else if (task.status == UploadStatus.failed) {
          FloatingUploadService.instance.showStatus(
            '上传失败：${task.fileName}',
            error: true,
          );
        }
      }
      _uploadStatuses[task.id] = task.status;
    }
  }

  void _onDownloadChanged() {
    final download = _downloadManager;
    if (download == null) return;

    for (final task in download.tasks) {
      final previous = _downloadStatuses[task.id];
      if (previous != task.status) {
        if (task.status == DownloadStatus.completed) {
          FloatingUploadService.instance.showStatus('下载成功：${task.fileName}');
        } else if (task.status == DownloadStatus.failed) {
          FloatingUploadService.instance.showStatus(
            '下载失败：${task.fileName}',
            error: true,
          );
        }
      }
      _downloadStatuses[task.id] = task.status;
    }
  }

  void _onSyncChanged() {
    final sync = _syncProvider;
    if (sync == null) return;

    final hasWorkNow = sync.isActive || sync.activeWorkerCount > 0;
    if (sync.hasError && !_syncWasError) {
      FloatingUploadService.instance.showStatus('同步失败', error: true);
    } else if (_syncHadActiveWork && !hasWorkNow && !sync.hasError) {
      FloatingUploadService.instance.showStatus('同步完成');
    }

    _syncHadActiveWork = hasWorkNow;
    _syncWasError = sync.hasError;
  }

  @override
  void dispose() {
    _uploadManager?.removeListener(_onUploadChanged);
    _downloadManager?.removeListener(_onDownloadChanged);
    _syncProvider?.removeListener(_onSyncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
