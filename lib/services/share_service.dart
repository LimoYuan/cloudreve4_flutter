
import 'package:flutter/material.dart';

import 'api_service.dart';
import '../data/models/share_model.dart';

/// 分享服务
class ShareService {
  /// 将文件系统路径转换为 cloudreve URI 格式
  String _toCloudreveUri(String path) {
    if (path.startsWith('cloudreve://')) {
      return path;
    }

    if (path == '/' || path.isEmpty) {
      return 'cloudreve://my';
    }
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return 'cloudreve://my/$cleanPath';
  }

  /// 创建分享链接
  Future<String> createShare({
    required String uri,
    bool? isPrivate,
    bool? shareView,
    int? expire,
    int? price,
    String? password,
    bool? showReadme,
  }) async {
    final data = <String, dynamic>{
      'permissions': {
        'anonymous': 'BQ==',
        'everyone': 'AQ==',
      },
      'uri': _toCloudreveUri(uri),
      'is_private': ?isPrivate,
      'share_view': ?shareView,
      'expire': ?expire,
      'price': ?price,
      'password': ?password,
      'show_readme': ?showReadme,
    };
    // 当请求的接口为创建分享时, 逻辑上不适合走到 _parseResponse -> ApiResponse.fromJson 直接返回结果即可
    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/share',
      data: data,
      isShare: true,
    );
    return response['data'] as String;
  }

  /// 获取我的分享列表
  Future<Map<String, dynamic>> listShares({
    required int pageSize,
    String? orderBy,
    String? orderDirection,
    String? nextPageToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page_size': pageSize,
      'order_by': ?orderBy,
      'order_direction': ?orderDirection,
      'next_page_token': ?nextPageToken,
    };
    // 请求方法为get, claude 写成post, fixed
    return await ApiService.instance.get<Map<String, dynamic>>(
      '/share',
      queryParameters: queryParams,
    );
  }

  /// 获取分享详情
  Future<ShareModel> getShareInfo({
    required String id,
    String? password,
    bool? countViews,
    bool? ownerExtended,
  }) async {
    final queryParams = <String, dynamic>{};
    if (password != null) queryParams['password'] = password;
    if (countViews != null) queryParams['count_views'] = countViews.toString();
    if (ownerExtended != null) queryParams['owner_extended'] = ownerExtended.toString();
    // 获取分享详情是 GET 请求
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/share/info/$id',
      queryParameters: queryParams,
    );
    // 获取分享详情返回的 response 已经经过 _parseResponse -> ApiResponse.fromJson 处理, 不需要再通过 ['data'] 获取数据
    // return ShareModel.fromJson(response['data'] as Map<String, dynamic>);
    return ShareModel.fromJson(response);
  }

  /// 编辑分享
  Future<String> editShare({
    required String id,
    required String uri,
    bool? isPrivate,
    String? password,
    bool? shareView,
    int? downloads,
    int? expire,
  }) async {
    final data = <String, dynamic>{
      'uri': uri,
      'is_private': ?isPrivate,
      'share_view': ?shareView,
      'downloads': ?downloads,
      'expire': ?expire,
    };
    if (password != null && password.isNotEmpty) {
      data['password'] = password;
    }

    debugPrint('editShare response ---> : response');
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/share/$id',
      data: data,
      isShare: true,
    );
    return response['data'] as String;
  }

  /// 删除分享
  Future<void> deleteShare({
    required String id,
  }) async {
    await ApiService.instance.delete<void>('/share/$id');
  }
}
