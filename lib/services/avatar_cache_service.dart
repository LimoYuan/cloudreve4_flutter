import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloudreve4_flutter/core/utils/app_logger.dart';
import 'package:cloudreve4_flutter/core/utils/avatar_utils.dart';

/// 头像缓存服务
/// 通过 Dio 下载头像，保存为本地文件 {userId}_avatar.webp
/// 服务器头像 200 优先，否则使用 Gravatar (identicon 兜底)
class AvatarCacheService extends ChangeNotifier {
  static AvatarCacheService? _instance;
  static AvatarCacheService get instance {
    _instance ??= AvatarCacheService._();
    return _instance!;
  }
  AvatarCacheService._();

  Directory? _cacheDir;
  final Map<String, String> _pathCache = {};
  final Map<String, int> _sizeCache = {};
  final Set<String> _loadingSet = {};

  /// 初始化缓存目录
  Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/avatar_cache');
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
    _scanExistingFiles();
  }

  void _scanExistingFiles() {
    if (_cacheDir == null) return;
    for (final entity in _cacheDir!.listSync()) {
      if (entity is File && entity.path.endsWith('_avatar.webp')) {
        final name = entity.uri.pathSegments.last;
        final userId = name.replaceAll('_avatar.webp', '');
        _pathCache[userId] = entity.path;
        try {
          _sizeCache[userId] = entity.lengthSync();
        } catch (_) {}
      }
    }
  }

  String _filePath(String userId) => '${_cacheDir!.path}/${userId}_avatar.webp';

  /// 头像缓存文件是否存在（同步）
  bool avatarIsExist(String userId) {
    if (userId.isEmpty) return false;
    final cached = _pathCache[userId];
    if (cached != null && File(cached).existsSync()) return true;
    return File(_filePath(userId)).existsSync();
  }

  /// 检查服务器头像是否有更新（HEAD 请求比对 Content-Length）
  /// 返回 true 表示已更新并重新缓存，false 表示无需更新或检查失败
  Future<bool> avatarIsUpdated(String userId, String baseUrl, String token) async {
    if (userId.isEmpty) return false;
    if (!avatarIsExist(userId)) {
      // 本地无缓存，直接走 getAvatar
      return await getAvatar(userId, baseUrl: baseUrl, token: token);
    }

    try {
      final url = AvatarUtils.getServerAvatarUrl(baseUrl, userId);
      // 使用独立 Dio 实例，避免 ApiService 拦截器干扰
      final dio = Dio();
      final response = await dio.head<void>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (s) => s != null && s < 500,
          followRedirects: false,
        ),
      );

      // 非 200（包括 302 指向 Gravatar）视为无自定义头像，无需比对更新
      if (response.statusCode != 200) return false;

      final remoteSize = response.headers.value('content-length');
      if (remoteSize == null) return false;
      final remoteBytes = int.tryParse(remoteSize) ?? -1;

      final localBytes = _sizeCache[userId] ??
          (File(_filePath(userId)).existsSync()
              ? File(_filePath(userId)).lengthSync()
              : -1);

      AppLogger.d('头像更新检查 ($userId): 本地=$localBytes, 远程=$remoteBytes');

      if (remoteBytes != localBytes) {
        // 大小不一致，重新获取
        return await getAvatar(userId, baseUrl: baseUrl, token: token);
      }
      return false;
    } catch (e) {
      AppLogger.d('头像更新检查失败 ($userId): $e');
      return false;
    }
  }

  /// 获取头像：并发请求服务器头像 + Gravatar，服务器 200 优先，否则用 Gravatar
  /// 返回 true 表示成功获取并缓存，false 表示全部失败
  Future<bool> getAvatar(String userId,
      {String? baseUrl, String? token, String? email}) async {
    if (userId.isEmpty || _cacheDir == null) return false;

    // 防止同一 userId 并发
    if (_loadingSet.contains(userId)) return false;
    _loadingSet.add(userId);

    try {
      final futures = <Future<_AvatarResult>>[];

      // 1. 服务器头像
      if (baseUrl != null && baseUrl.isNotEmpty && token != null && token.isNotEmpty) {
        futures.add(_fetchServerAvatar(userId, baseUrl, token));
      }

      // 2. Gravatar (identicon 兜底)
      if (email != null && email.isNotEmpty) {
        futures.add(_fetchGravatar(userId, email));
      }

      if (futures.isEmpty) return false;

      // 并发请求
      final results = await Future.wait(futures);
      final serverResult = results.whereType<_ServerAvatarResult>().firstOrNull;
      final gravatarResult = results.whereType<_GravatarResult>().firstOrNull;

      // 服务器头像 200 优先
      if (serverResult != null && serverResult.statusCode == 200 && serverResult.bytes != null) {
        _saveFile(userId, serverResult.bytes!);
        AppLogger.d('头像获取成功 (服务器, $userId), 大小=${serverResult.bytes!.length}');
        notifyListeners();
        return true;
      }

      // 服务器 404/302 或失败，用 Gravatar
      if (gravatarResult != null && gravatarResult.bytes != null) {
        _saveFile(userId, gravatarResult.bytes!);
        AppLogger.d('头像获取成功 (Gravatar, $userId), 大小=${gravatarResult.bytes!.length}');
        notifyListeners();
        return true;
      }

      AppLogger.d('头像获取失败 ($userId): 服务器状态=${serverResult?.statusCode}, Gravatar=${gravatarResult != null ? '失败' : '未请求'}');
      return false;
    } finally {
      _loadingSet.remove(userId);
    }
  }

  Future<_AvatarResult> _fetchServerAvatar(String userId, String baseUrl, String token) async {
    try {
      final url = AvatarUtils.getServerAvatarUrl(baseUrl, userId);
      // 使用独立 Dio 实例，避免 ApiService 拦截器干扰
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (s) => s != null && s < 500,
          // 不跟随重定向：302 指向官方 Gravatar，跟随会绕过镜像加速
          followRedirects: false,
        ),
      );
      return _ServerAvatarResult(response.statusCode ?? 0, response.data);
    } catch (e) {
      AppLogger.d('请求服务器头像异常 ($userId): $e');
      return _ServerAvatarResult(0, null);
    }
  }

  Future<_AvatarResult> _fetchGravatar(String userId, String email) async {
    try {
      final url = await AvatarUtils.getGravatarUrl(email, size: 400);
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        return _GravatarResult(response.data!);
      }
      return _GravatarResult(null);
    } catch (e) {
      AppLogger.d('请求Gravatar头像异常 ($userId): $e');
      return _GravatarResult(null);
    }
  }

  void _saveFile(String userId, List<int> bytes) {
    if (_cacheDir == null) return;
    final path = _filePath(userId);
    final file = File(path);
    file.writeAsBytesSync(bytes);
    _pathCache[userId] = path;
    _sizeCache[userId] = bytes.length;
  }

  /// 获取已缓存的头像文件（同步，快速）
  File? getCachedFile(String userId) {
    if (_cacheDir == null || userId.isEmpty) return null;
    final cached = _pathCache[userId];
    if (cached != null && File(cached).existsSync()) {
      return File(cached);
    }
    final path = _filePath(userId);
    if (File(path).existsSync()) {
      _pathCache[userId] = path;
      return File(path);
    }
    _pathCache.remove(userId);
    _sizeCache.remove(userId);
    return null;
  }

  /// 批量检查头像是否需要更新（限制并发，避免密集 IO/网络阻塞主线程）
  Future<void> batchCheckUpdates(
    List<String> userIds, {
    required String baseUrl,
    required String token,
    int concurrency = 3,
  }) async {
    var index = 0;
    final completer = Completer<void>();
    var activeCount = 0;
    var completedCount = 0;
    final total = userIds.length;

    void scheduleNext() {
      while (activeCount < concurrency && index < total) {
        final userId = userIds[index++];
        activeCount++;
        avatarIsUpdated(userId, baseUrl, token).whenComplete(() {
          activeCount--;
          completedCount++;
          if (completedCount >= total && !completer.isCompleted) {
            completer.complete();
          } else {
            scheduleNext();
          }
        });
      }
      if (completedCount >= total && !completer.isCompleted) {
        completer.complete();
      }
    }

    scheduleNext();
    await completer.future;
  }

  /// 清除指定用户的头像缓存（头像上传/切换后调用）
  Future<void> evictCache(String userId) async {
    _pathCache.remove(userId);
    _sizeCache.remove(userId);
    final path = _filePath(userId);
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    notifyListeners();
  }

  /// 清除所有头像缓存（登出时调用）
  Future<void> clearAllCache() async {
    _pathCache.clear();
    _sizeCache.clear();
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      await _cacheDir!.delete(recursive: true);
      _cacheDir!.createSync(recursive: true);
    }
    notifyListeners();
  }
}

/// 请求结果基类
abstract class _AvatarResult {}

class _ServerAvatarResult extends _AvatarResult {
  final int statusCode;
  final List<int>? bytes;
  _ServerAvatarResult(this.statusCode, this.bytes);
}

class _GravatarResult extends _AvatarResult {
  final List<int>? bytes;
  _GravatarResult(this.bytes);
}
