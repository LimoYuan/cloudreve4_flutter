import 'package:cloudreve4_flutter/core/utils/app_logger.dart';

import 'api_service.dart';
import '../data/models/remote_download_task_model.dart';

/// 离线下载服务
class RemoteDownloadService {
  /// 创建离线下载任务
  Future<List<RemoteDownloadTaskModel>> createDownload({
    required String dst,
    List<String>? src,
    String? srcFile,
  }) async {
    final data = <String, dynamic>{
      'dst': dst,
      if (src != null && src.isNotEmpty) 'src': src,
      if (srcFile != null && srcFile.isNotEmpty) 'src_file': srcFile,
    };

    final response = await ApiService.instance
        .post('/workflow/download', data: data);

    AppLogger.i("RemoteDownloadService --> $response");

    List<RemoteDownloadTaskModel> result = response.map<RemoteDownloadTaskModel>((item) =>
      RemoteDownloadTaskModel.fromJson(item as Map<String, dynamic>)
    ).toList();

    return result;
  }

  /// 列出任务
  /// [category] 任务分类：downloading（下载中）、downloaded（已完成）、general（全部）
  Future<Map<String, dynamic>> listTasks({
    required String category,
    int pageSize = 20,
    String? nextPageToken,
  }) async {
    final params = <String, dynamic>{
      'page_size': pageSize,
      'category': category,
      if (nextPageToken != null) 'next_page_token': nextPageToken,
    };

    return await ApiService.instance
        .get<Map<String, dynamic>>('/workflow', queryParameters: params);
  }

  /// 获取任务进度
  Future<Map<String, dynamic>> getProgress({required String taskId}) async {
    return await ApiService.instance
        .get<Map<String, dynamic>>('/workflow/progress/$taskId');
  }

  /// 选择种子文件
  Future<void> selectFiles({
    required String taskId,
    required List<Map<String, dynamic>> files,
  }) async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/workflow/download/$taskId',
      data: {'files': files},
    );
  }

  /// 取消任务
  Future<void> cancelTask({required String taskId}) async {
    await ApiService.instance.delete<Map<String, dynamic>>(
      '/workflow/download/$taskId',
    );
  }
}
