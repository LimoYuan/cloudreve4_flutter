import 'package:flutter/material.dart';

import 'api_service.dart';

/// 文件服务
class FileService {
  /// 将文件系统路径转换为 cloudreve URI 格式
  /// 例如: "/" -> "cloudreve://my"
  /// "/subfolder" -> "cloudreve://my/subfolder"
  /// "/a/b" -> "cloudreve://my/a/b"
  /// "cloudreve://my/subfolder" -> "cloudreve://my/subfolder" (已包含前缀则直接返回)
  String _toCloudreveUri(String path) {
    // 如果已经是 cloudreve:// 开头的URI，直接返回
    if (path.startsWith('cloudreve://')) {
      return path;
    }

    if (path == '/' || path.isEmpty) {
      return 'cloudreve://my';
    }
    // 移除开头的 /
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'cloudreve://my/$cleanPath';
  }

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
      'uri': _toCloudreveUri(uri),
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

  /// 创建文件/文件夹
  Future<Map<String, dynamic>> createFile({
    required String uri,
    required String type,
    bool? errOnConflict,
    Map<String, dynamic>? metadata,
  }) async {
    final data = <String, dynamic>{
      'uri': _toCloudreveUri(uri),
      'type': type,
      'err_on_conflict': ?errOnConflict,
      'metadata': ?metadata,
    };

    final response = await ApiService.instance
        .post<Map<String, dynamic>>('/file/create', data: data);

    return response;
  }

  /// 删除文件
  Future<void> deleteFiles({
    required List<String> uris,
    bool unlink = false,
    bool skipSoftDelete = false,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => _toCloudreveUri(uri)).toList(),
      if (unlink) 'unlink': true,
      if (skipSoftDelete) 'skip_soft_delete': true,
    };

    await ApiService.instance.delete<void>('/file', data: data);
  }

  /// 移动/复制文件
  Future<void> moveFiles({
    required List<String> uris,
    required String dst,
    bool copy = false,
  }) async {
    final data = <String, dynamic>{
      'uris': uris.map((uri) => _toCloudreveUri(uri)).toList(),
      'dst': _toCloudreveUri(dst),
      'copy': copy,
    };

    await ApiService.instance.post<void>('/file/move', data: data);
  }

  /// 重命名文件
  Future<void> renameFile({
    required String uri,
    required String newName,
  }) async {
    final data = <String, dynamic>{
      'uri': _toCloudreveUri(uri),
      'name': newName,
    };

    await ApiService.instance.post<void>('/file/rename', data: data);
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
      'uris': uris.map((uri) => _toCloudreveUri(uri)).toList(),
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
      'uris': uris.map((uri) => _toCloudreveUri(uri)).toList(),
    };

    final response = await ApiService.instance.put<List<Map<String, dynamic>>>(
      '/file/source',
      data: data,
    );

    return response;
  }
}
