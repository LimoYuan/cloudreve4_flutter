import 'dart:typed_data';
import '../data/models/user_setting_model.dart';
import '../data/models/user_model.dart';
import 'api_service.dart';

/// 用户设置服务
class UserSettingService {
  UserSettingService._internal();
  static final UserSettingService _instance = UserSettingService._internal();
  static UserSettingService get instance => _instance;

  /// 获取当前用户设置
  /// _parseResponse 已自动提取 data 字段，返回值即 json['data']
  Future<UserSettingModel> getUserSetting() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/user/setting',
    );
    return UserSettingModel.fromJson(response);
  }

  /// 更新用户设置（仅发送非null字段）
  /// PATCH /user/setting 返回的 data 字段可能为 null，不应强转为 Map
  Future<void> updateUserSetting({
    String? nick,
    bool? groupExpires,
    String? language,
    String? preferredTheme,
    bool? versionRetentionEnabled,
    List<String>? versionRetentionExt,
    int? versionRetentionMax,
    String? currentPassword,
    String? newPassword,
    bool? twoFaEnabled,
    String? twoFaCode,
    bool? disableViewSync,
    String? shareLinksInProfile,
  }) async {
    final data = <String, dynamic>{};
    if (nick != null) data['nick'] = nick;
    if (groupExpires != null) data['group_expires'] = groupExpires;
    if (language != null) data['language'] = language;
    if (preferredTheme != null) data['preferred_theme'] = preferredTheme;
    if (versionRetentionEnabled != null) {
      data['version_retention_enabled'] = versionRetentionEnabled;
    }
    if (versionRetentionExt != null) {
      data['version_retention_ext'] = versionRetentionExt;
    }
    if (versionRetentionMax != null) {
      data['version_retention_max'] = versionRetentionMax;
    }
    if (currentPassword != null) data['current_password'] = currentPassword;
    if (newPassword != null) data['new_password'] = newPassword;
    if (twoFaEnabled != null) data['two_fa_enabled'] = twoFaEnabled;
    if (twoFaCode != null) data['two_fa_code'] = twoFaCode;
    if (disableViewSync != null) data['disable_view_sync'] = disableViewSync;
    if (shareLinksInProfile != null) {
      data['share_links_in_profile'] = shareLinksInProfile;
    }

    // PATCH 响应的 data 字段通常为 null，使用 void 避免类型转换错误
    await ApiService.instance.patch<void>(
      '/user/setting',
      data: data,
    );
  }

  /// 更新头像（传图片二进制数据，传null则重置为Gravatar）
  Future<void> updateAvatar(Uint8List? imageBytes) async {
    await ApiService.instance.put<void>(
      '/user/setting/avatar',
      data: imageBytes,
      isNoData: true,
    );
  }

  /// 获取存储用量
  /// _parseResponse 已自动提取 data 字段
  Future<UserCapacityModel> getUserCapacity() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/user/capacity',
    );
    return UserCapacityModel.fromJson(response);
  }

  /// 准备启用2FA（获取TOTP密钥）
  /// _parseResponse 自动提取 data 字段，后端 data 是 TOTP secret 字符串
  Future<String> prepare2FA() async {
    return await ApiService.instance.get<String>(
      '/user/setting/2fa',
    );
  }

  /// 启用2FA
  Future<void> enable2FA(String code) async {
    await updateUserSetting(twoFaEnabled: true, twoFaCode: code);
  }

  /// 禁用2FA
  Future<void> disable2FA(String code) async {
    await updateUserSetting(twoFaEnabled: false, twoFaCode: code);
  }

  /// 修改密码
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await updateUserSetting(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// 修改昵称
  Future<void> updateNick(String nick) async {
    await updateUserSetting(nick: nick);
  }

  /// 修改主题色偏好
  Future<void> updatePreferredTheme(String themeColor) async {
    await updateUserSetting(preferredTheme: themeColor);
  }

  /// 修改语言偏好
  Future<void> updateLanguage(String language) async {
    await updateUserSetting(language: language);
  }

  /// 获取当前用户信息（用于刷新用户资料）
  /// _parseResponse 已自动提取 data 字段
  Future<UserModel> getCurrentUser() async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/session/user',
    );
    return UserModel.fromJson(response);
  }

  /// 撤销OAuth应用授权
  Future<void> revokeOAuthGrant(String appId) async {
    await ApiService.instance.delete<void>(
      '/session/oauth/grant/$appId',
    );
  }

  /// 解绑OIDC提供商
  Future<void> unlinkOpenId(int provider) async {
    await ApiService.instance.post<void>(
      '/session/oidc/unlink',
      data: {'provider': provider},
    );
  }

  /// 删除Passkey
  Future<void> deletePasskey(String passkeyId) async {
    await ApiService.instance.delete<void>(
      '/user/authn',
      queryParameters: {'id': passkeyId},
    );
  }

  /// 获取积分变动记录
  /// _parseResponse 已自动提取 data 字段
  Future<CreditChangeList> getCreditChanges({
    int pageSize = 20,
    String? nextPageToken,
  }) async {
    final queryParams = <String, dynamic>{
      'page_size': pageSize,
      if (nextPageToken != null) 'next_page_token': nextPageToken,
    };
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/user/creditChanges',
      queryParameters: queryParams,
    );
    return CreditChangeList.fromJson(response);
  }
}
