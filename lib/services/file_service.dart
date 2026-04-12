import 'api_service.dart';

/// 文件服务
class FileService {
  /// 列出文件
  Future<Map<String, dynamic>> listFiles({
    required String uri,
    int? page,
    int? pageSize,
    String? orderBy,
    String? orderDirection,
    String? nextPageToken,
  }) async {
    final params = <String, dynamic>{
      'uri': uri,
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
    required int type, // 0:文件, 1:文件夹
    String? name,
    Map<String, String>? metadata,
  }) async {
    final data = <String, dynamic>{
      'uri': uri,
      'type': type,
      if (name != null) 'name': name,
      if (metadata != null) 'metadata': metadata,
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
      'uris': uris,
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
      'uris': uris,
      'dst': dst,
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
      'uri': uri,
      'name': newName,
    };

    await ApiService.instance.post<void>('/file/rename', data: data);
  }
}
