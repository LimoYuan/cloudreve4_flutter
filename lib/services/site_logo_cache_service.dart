import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../core/utils/app_logger.dart';
import '../core/utils/direct_http_client.dart';
import '../data/models/server_model.dart';

/// 站点 logo 缓存服务（仅移动端使用）
///
/// 以 `站点名清洗_host_site_logo.png` 为文件名缓存站点 logo。
/// 无缓存时登录页走本地 app_logo.png，再异步拉取并写入缓存后刷新 UI。
class SiteLogoCacheService {
  SiteLogoCacheService._();
  static final SiteLogoCacheService instance = SiteLogoCacheService._();

  Directory? _cacheDir;
  final Set<String> _loadingSet = {};

  Future<void> _ensureInit() async {
    if (_cacheDir != null && _cacheDir!.existsSync()) return;
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/site_logo_cache');
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
  }

  /// 站点缓存文件名 key：清洗后的站点名 + host
  String _cacheKey(ServerModel server) {
    final label = server.label.trim();
    String host = '';
    try {
      host = Uri.parse(server.baseUrl).host;
    } catch (_) {}
    final raw = '${label}_$host';
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'site' : sanitized;
  }

  String _filePath(ServerModel server) =>
      '${_cacheDir!.path}/${_cacheKey(server)}_site_logo.png';

  /// 获取已缓存的 logo 文件（同步，需先 _ensureInit）
  File? getCachedFileSync(ServerModel server) {
    if (_cacheDir == null) return null;
    final file = File(_filePath(server));
    return file.existsSync() ? file : null;
  }

  /// 异步获取缓存文件（确保目录已初始化）
  Future<File?> getCachedFile(ServerModel server) async {
    await _ensureInit();
    return getCachedFileSync(server);
  }

  /// 拉取 logo 并写入缓存，返回缓存文件；失败返回 null。
  Future<File?> fetchAndCache(ServerModel server, String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) return null;
    await _ensureInit();

    final key = _cacheKey(server);
    if (_loadingSet.contains(key)) return getCachedFileSync(server);
    _loadingSet.add(key);

    try {
      final dio = Dio();
      dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
        connectionTimeout: const Duration(seconds: 8),
      );
      final response = await dio.get<List<int>>(
        logoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {'Accept': 'image/*,*/*;q=0.8'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final status = response.statusCode ?? 0;
      final data = response.data;
      if (status < 200 ||
          status >= 300 ||
          data == null ||
          data.isEmpty ||
          data.length > 1024 * 1024) {
        return null;
      }

      final file = File(_filePath(server));
      file.writeAsBytesSync(data);
      return file;
    } catch (e) {
      AppLogger.d('站点 logo 缓存失败 ($key): $e');
      return null;
    } finally {
      _loadingSet.remove(key);
    }
  }

  /// 清除指定站点的 logo 缓存（手动刷新时调用）
  Future<void> evict(ServerModel server) async {
    await _ensureInit();
    final file = File(_filePath(server));
    if (file.existsSync()) {
      await file.delete();
    }
    // 失效 Flutter 内存解码缓存，避免覆盖同路径后仍显示旧图
    await FileImage(file).evict();
  }
}
