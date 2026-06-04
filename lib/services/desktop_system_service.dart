import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../core/constants/storage_keys.dart';
import '../core/utils/app_logger.dart';
import 'storage_service.dart';

class DesktopSystemService {
  DesktopSystemService._();

  static final DesktopSystemService instance = DesktopSystemService._();

  static const String _windowsRunKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _windowsRunValueName = 'Cloudreve4Flutter';
  static const String _linuxDesktopFileName = 'cloudreve4_flutter.desktop';

  bool _shutdownRequested = false;

  bool get isSupportedDesktop => Platform.isWindows || Platform.isLinux;

  Future<bool> isShutdownAfterUploadsEnabled() async {
    if (!isSupportedDesktop) return false;
    return await StorageService.instance
            .getBool(StorageKeys.shutdownAfterUploadsComplete) ??
        false;
  }

  Future<void> setShutdownAfterUploadsEnabled(bool enabled) async {
    await StorageService.instance.setBool(
      StorageKeys.shutdownAfterUploadsComplete,
      enabled,
    );

    if (!enabled) {
      _shutdownRequested = false;
      await cancelScheduledShutdown();
    }
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    if (!isSupportedDesktop) return false;

    if (Platform.isWindows) {
      final registryEnabled = await _isWindowsRunEntryEnabled();
      if (registryEnabled != null) {
        await StorageService.instance.setBool(
          StorageKeys.launchAtStartupEnabled,
          registryEnabled,
        );
        return registryEnabled;
      }
    }

    if (Platform.isLinux) {
      final desktopFile = File(_linuxAutostartDesktopFilePath);
      final enabled = await desktopFile.exists();
      await StorageService.instance.setBool(
        StorageKeys.launchAtStartupEnabled,
        enabled,
      );
      return enabled;
    }

    return await StorageService.instance
            .getBool(StorageKeys.launchAtStartupEnabled) ??
        false;
  }

  Future<void> setLaunchAtStartupEnabled(bool enabled) async {
    if (!isSupportedDesktop) {
      await StorageService.instance.setBool(
        StorageKeys.launchAtStartupEnabled,
        false,
      );
      return;
    }

    if (Platform.isWindows) {
      await _setWindowsRunEntry(enabled);
    } else if (Platform.isLinux) {
      await _setLinuxAutostartEntry(enabled);
    }

    await StorageService.instance.setBool(
      StorageKeys.launchAtStartupEnabled,
      enabled,
    );
  }

  Future<void> handleUploadsFinishedIfNeeded({String? lastFileName}) async {
    if (_shutdownRequested) return;
    if (!await isShutdownAfterUploadsEnabled()) return;

    _shutdownRequested = true;
    AppLogger.i(
      'All upload tasks finished. Scheduling system shutdown. lastFile=$lastFileName',
    );

    await scheduleShutdown(delaySeconds: 60);
  }

  Future<void> scheduleShutdown({int delaySeconds = 60}) async {
    if (!isSupportedDesktop) return;

    final safeDelay = delaySeconds.clamp(0, 3600).toInt();

    if (Platform.isWindows) {
      await Process.start(
        'shutdown.exe',
        [
          '/s',
          '/t',
          safeDelay.toString(),
          '/c',
          'Cloudreve 上传任务已完成，电脑将在 $safeDelay 秒后关机。',
        ],
        runInShell: false,
      );
      return;
    }

    if (Platform.isLinux) {
      final minutes = safeDelay <= 60 ? '+1' : '+${(safeDelay / 60).ceil()}';
      await Process.start(
        'shutdown',
        ['-h', minutes, 'Cloudreve upload tasks finished'],
        runInShell: false,
      );
    }
  }

  Future<void> cancelScheduledShutdown() async {
    if (!isSupportedDesktop) return;

    try {
      if (Platform.isWindows) {
        await Process.run('shutdown.exe', ['/a'], runInShell: false);
      } else if (Platform.isLinux) {
        await Process.run('shutdown', ['-c'], runInShell: false);
      }
    } catch (e) {
      AppLogger.d('Cancel scheduled shutdown failed: $e');
    }
  }

  Future<bool?> _isWindowsRunEntryEnabled() async {
    try {
      final result = await Process.run(
        'reg',
        ['query', _windowsRunKey, '/v', _windowsRunValueName],
        runInShell: false,
      );

      if (result.exitCode != 0) return false;

      final stdout = result.stdout?.toString() ?? '';
      final exePath = _currentExecutablePath.toLowerCase();
      return stdout.toLowerCase().contains(exePath);
    } catch (e) {
      AppLogger.d('Query Windows startup registry failed: $e');
      return null;
    }
  }

  Future<void> _setWindowsRunEntry(bool enabled) async {
    if (enabled) {
      final exePath = _currentExecutablePath.replaceAll('"', r'\"');
      final result = await Process.run(
        'reg',
        [
          'add',
          _windowsRunKey,
          '/v',
          _windowsRunValueName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        throw Exception('写入开机自启动失败：${result.stderr ?? result.stdout}');
      }
      return;
    }

    await Process.run(
      'reg',
      ['delete', _windowsRunKey, '/v', _windowsRunValueName, '/f'],
      runInShell: false,
    );
  }

  Future<void> _setLinuxAutostartEntry(bool enabled) async {
    final file = File(_linuxAutostartDesktopFilePath);

    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }

    await file.parent.create(recursive: true);
    final exePath = _currentExecutablePath.replaceAll('"', r'\"');
    await file.writeAsString('''
[Desktop Entry]
Type=Application
Name=${AppConfig.appName}
Exec="$exePath"
Terminal=false
X-GNOME-Autostart-enabled=true
''');
  }

  String get _currentExecutablePath => p.normalize(Platform.resolvedExecutable);

  String get _linuxAutostartDesktopFilePath {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, '.config', 'autostart', _linuxDesktopFileName);
  }
}
