import 'package:dio/dio.dart';

import 'api_service.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/file_utils.dart';

/// 文件服务
class FileService {

  /// 列出文件
  Future<Map<String, dynamic>> listFiles({
    required String uri,
    int page = 0,
    int? pageSize,
    String? orderBy,
    String? orderDirection,
    String? nextPageToken,
  }) async {
    final params = <String, dynamic>{
      'uri': FileUtils.toCloudreveUri(uri),
      'page': page,
      'page_size': pageSize,
      'order_by': orderBy,
      'order_direction': orderDirection,
      'next_page_token': nextPageToken,
    };

    final response = await ApiService.instance
        .get<Map<String, dynamic>>('/file', queryParameters: params);

    return response;
  }


  /// 按 Cloudreve V4 预设分类列出文件。
  ///
  /// category 可用值：
  /// image / video / audio / document
  Future<Map<String, dynamic>> listFilesByCategory({
    required String category,
    int page = 0,
    int? pageSize,
    String? orderBy,
    String? orderDirection,
    String? nextPageToken,
  }) {
    final normalizedCategory = category.trim().toLowerCase();
    final categoryUri = 'cloudreve://my?category=$normalizedCategory';

    return listFiles(
      uri: categoryUri,
      page: page,
      pageSize: pageSize,
      orderBy: orderBy,
      orderDirection: orderDirection,
      nextPageToken: nextPageToken,
    );
  }

  /// 创建文件/文件夹
  Future<Map<String, dynamic>> createFile({
    required String uri,
    required String type,
    bool? errOnConflict,
    Map<String, dynamic>? metadata,
  }) async {
    final data = <String, dynamic>{
      'uri': FileUtils.toCloudreveUri(uri),
      'type': type,
      'err_on_conflict': ?errOnConflict,
      'metadata': ?metadata,
    };

    final response = await ApiService.instance
        .post<Map<String, dynamic>>('/file/create', data: data);

    return response;
  }

  /// 删除文件
  ///
  /// Cloudreve V4 中，正在上传或被其他应用占用的文件会带锁。
  /// 普通删除遇到 Lock conflict(code: 40073) 时，响应 data 中会返回锁 token。
  /// 文件拥有者可以调用 /file/lock 强制解锁，然后重新删除。
  Future<void> deleteFiles({
    required List<String> uris,
    bool unlink = false,
    bool skipSoftDelete = false,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => FileUtils.toCloudreveUri(uri)).toList(),
      if (unlink) 'unlink': true,
      if (skipSoftDelete) 'skip_soft_delete': true,
    };

    final response = await _deleteFilesRaw(data);
    final body = _asMap(response.data);
    final code = body?['code'];

    if (code == 0 || code == null) return;

    if (code == 40073) {
      final tokens = _extractLockTokens(body);
      if (tokens.isNotEmpty) {
        AppLogger.d('Delete files lock conflict, force unlock and retry: ${tokens.length}');
        await forceUnlock(tokens);

        final retryResponse = await _deleteFilesRaw(data);
        _ensureCloudreveSuccess(_asMap(retryResponse.data));
        return;
      }
    }

    _ensureCloudreveSuccess(body);
  }

  Future<Response<dynamic>> _deleteFilesRaw(Map<String, dynamic> data) {
    return ApiService.instance.dio.delete<dynamic>(
      '/file',
      data: data,
      options: Options(contentType: 'application/json'),
    );
  }

  /// 强制解锁文件锁。
  Future<void> forceUnlock(List<String> tokens) async {
    if (tokens.isEmpty) return;

    final response = await ApiService.instance.dio.delete<dynamic>(
      '/file/lock',
      data: {'tokens': tokens},
      options: Options(contentType: 'application/json'),
    );

    _ensureCloudreveSuccess(_asMap(response.data));
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  List<String> _extractLockTokens(Map<String, dynamic>? data) {
    final raw = data?['data'];
    if (raw is! List) return const [];

    final tokens = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final token = item['token']?.toString();
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }
    return tokens;
  }

  void _ensureCloudreveSuccess(Map<String, dynamic>? data) {
    if (data == null) return;

    final code = data['code'];
    if (code == null || code == 0) return;

    final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '操作失败';
    throw Exception('$msg (code: $code)');
  }

  /// 移动/复制文件
  Future<void> moveFiles({
    required List<String> uris,
    required String dst,
    bool copy = false,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => FileUtils.toCloudreveUri(uri)).toList(),
      'dst': FileUtils.toCloudreveUri(dst),
      'copy': copy,
    };

    await ApiService.instance.post<void>('/file/move', data: data);
  }

  /// 重命名文件（返回更新后的文件对象）
  Future<Map<String, dynamic>> renameFile({
    required String uri,
    required String newName,
  }) async {
    final data = <String, dynamic>{
      'uri': FileUtils.toCloudreveUri(uri),
      'new_name': newName,
    };

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/file/rename',
      data: data,
    );
    return response;
  }

  /// 获取下载链接
  Future<Map<String, dynamic>> getDownloadUrls({
    required List<String> uris,
    bool download = true,
    bool? redirect,
    String? entity,
    bool? usePrimarySiteUrl,
    bool? skipError,
    bool? archive,
    bool? noCache,
    String? contextHint,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => FileUtils.toCloudreveUri(uri)).toList(),
      'download': download,
      'redirect': ?redirect,
      'entity': ?entity,
      'use_primary_site_url': ?usePrimarySiteUrl,
      'skip_error': ?skipError,
      'archive': ?archive,
      'no_cache': ?noCache,
    };

    final headers = <String, dynamic>{};
    if (contextHint != null) {
      headers['X-Cr-Context-Hint'] = contextHint;
    }

    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/file/url',
      data: data,
      headers: headers,
    );

    return response;
  }

  /// 创建直接链接（分享链接）
  Future<List<Map<String, dynamic>>> createDirectLinks({
    required List<String> uris,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => FileUtils.toCloudreveUri(uri)).toList(),
    };

    final response = await ApiService.instance.put<List<Map<String, dynamic>>>(
      '/file/source',
      data: data,
    );

    return response;
  }

  /// 恢复文件（从回收站）
  Future<void> restoreFiles({
    required List<String> uris,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => FileUtils.toCloudreveUri(uri)).toList(),
    };

    await ApiService.instance.post<void>('/file/restore', data: data);
  }

  /// 列出回收站文件
  Future<Map<String, dynamic>> listTrashFiles({
    int page = 0,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{
      'uri': 'cloudreve://trash',
      'page': page,
      'page_size': pageSize,
    };

    final response = await ApiService.instance
        .get<Map<String, dynamic>>('/file', queryParameters: params);

    return response;
  }

  /// 搜索文件
  Future<Map<String, dynamic>> searchFiles({
    String uri = '/',
    required String name,
    bool caseFolding = false,
    int page = 0,
    int? pageSize,
  }) async {
    // 构造搜索 URI: cloudreve://my?name=xxx
    final cloudreveUri = '${FileUtils.toCloudreveUri(uri)}?name=$name';

    final params = <String, dynamic>{
      'uri': cloudreveUri,
      'page': page,
      'case_folding': caseFolding,
      'page_size': pageSize,
    };

    final response = await ApiService.instance
        .get<Map<String, dynamic>>('/file', queryParameters: params);

    AppLogger.d('Search files ---------> : $response');
    return response;
  }

  /// 获取文件/文件夹详细信息
  Future<Map<String, dynamic>> getFileInfo({
    String? uri,
    String? id,
    bool extended = false,
    bool folderSummary = false,
  }) async {
    final params = <String, dynamic>{
      if (uri != null) 'uri': FileUtils.toCloudreveUri(uri),
      'id': ?id,
      'extended': extended,
      'folder_summary': folderSummary,
    };

    final response = await ApiService.instance
        .get<Map<String, dynamic>>('/file/info', queryParameters: params);
    AppLogger.d("getFileInfo --> $response");
    return response;
  }

  /// 设为当前版本
  Future<void> setFileVersion({
    required String uri,
    required String version,
  }) async {
    final data = <String, dynamic>{
      'uri': FileUtils.toCloudreveUri(uri),
      'version': version,
    };

    await ApiService.instance.post<void>('/file/version/current', data: data);
  }

  /// 删除版本
  Future<void> deleteFileVersion({
    required String uri,
    required String version,
  }) async {
    final data = <String, dynamic>{
      'uri': FileUtils.toCloudreveUri(uri),
      'version': version,
    };

    await ApiService.instance.delete<void>('/file/version', data: data);
  }
}
