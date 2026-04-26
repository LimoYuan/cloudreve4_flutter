import '../data/models/dav_account_model.dart';
import 'api_service.dart';
import '../core/utils/app_logger.dart';

/// WebDAV 服务
class WebdavService {
  /// 列出所有 WebDAV 账户
  Future<Map<String, dynamic>> listAccounts({
    required int pageSize,
    String? nextPageToken,
  }) async {
    final params = <String, dynamic>{
      'page_size': pageSize,
      ...nextPageToken != null ? {'next_page_token': nextPageToken} : {},
    };

    return await ApiService.instance
        .get<Map<String, dynamic>>('/devices/dav', queryParameters: params);
  }

  /// 创建 WebDAV 账户
  Future<DavAccountModel> createAccount({
    required String uri,
    required String name,
    bool? readonly,
    bool? proxy,
    bool? disableSysFiles,
  }) async {
    final data = <String, dynamic>{
      'uri': uri,
      'name': name,
      ...readonly != null ? {'readonly': readonly} : {},
      ...proxy != null ? {'proxy': proxy} : {},
      ...disableSysFiles != null ? {'disable_sys_files': disableSysFiles} : {},
    };

    final response = await ApiService.instance
        .put<Map<String, dynamic>>('/devices/dav', data: data);
    // 已经经过 api_service.dart -> _parseResponse 处理过的数据, 
    // 直接不使用, 不需要 response['data'] 去取
    return DavAccountModel.fromJson(response);
  }

  /// 更新 WebDAV 账户
  Future<DavAccountModel> updateAccount({
    required String id,
    String? uri,
    String? name,
    bool? readonly,
    bool? proxy,
    bool? disableSysFiles,
  }) async {
    final data = <String, dynamic>{
      ...uri != null ? {'uri': uri} : {},
      ...name != null ? {'name': name} : {},
      ...readonly != null ? {'readonly': readonly} : {},
      ...proxy != null ? {'proxy': proxy} : {},
      ...disableSysFiles != null ? {'disable_sys_files': disableSysFiles} : {},
    };

    final response = await ApiService.instance
        .patch<Map<String, dynamic>>('/devices/dav/$id', data: data);
    AppLogger.d('更新 WebDAV 账户成功: $response');
    // 已经经过 api_service.dart -> _parseResponse 处理过的数据, 
    // 直接不使用, 不需要 response['data'] 去取
    return DavAccountModel.fromJson(response);
  }

  /// 删除 WebDAV 账户
  Future<void> deleteAccount(String id) async {
    await ApiService.instance.delete<void>('/devices/dav/$id', data: {});
  }
}
