import '../core/utils/server_url_utils.dart';

/// 品牌/定制打包配置。
///
/// 默认构建保持原项目行为；定制打包器会通过 --dart-define 注入这些值：
/// - MKW_BRANDED_BUILD=true
/// - MKW_APP_NAME=应用名称
/// - MKW_LOCK_SERVER=true
/// - MKW_FIXED_SERVER_NAME=服务器显示名
/// - MKW_FIXED_SERVER_BASE_URL=https://example.com
class BrandConfig {
  BrandConfig._();

  /// 是否是定制构建。
  static const bool brandedBuild = bool.fromEnvironment(
    'MKW_BRANDED_BUILD',
    defaultValue: false,
  );

  /// App 内显示名称。
  static const String appName = String.fromEnvironment(
    'MKW_APP_NAME',
    defaultValue: 'Cloudreve',
  );

  /// 固定服务器显示名称。
  static const String fixedServerName = String.fromEnvironment(
    'MKW_FIXED_SERVER_NAME',
    defaultValue: '',
  );

  /// 固定服务器地址。可以传站点根地址，也可以传 /api/v4 地址。
  static const String fixedServerBaseUrl = String.fromEnvironment(
    'MKW_FIXED_SERVER_BASE_URL',
    defaultValue: '',
  );

  /// 是否锁定服务器。锁定后 UI 不再显示服务器选择/管理入口。
  static const bool lockServer = bool.fromEnvironment(
    'MKW_LOCK_SERVER',
    defaultValue: false,
  );

  /// 当前构建是否启用固定服务器。
  static bool get hasFixedServer =>
      lockServer && fixedServerBaseUrl.trim().isNotEmpty;

  /// 固定服务器在 UI / 本地存储里的显示名称。
  static String get effectiveServerName {
    final name = fixedServerName.trim();
    if (name.isNotEmpty) return name;
    return appName.trim().isNotEmpty ? appName.trim() : 'Cloudreve';
  }

  /// 规范化后的 Cloudreve V4 API 地址，确保末尾为 /api/v4。
  static String get effectiveServerBaseUrl =>
      ServerUrlUtils.toApiBaseUrl(fixedServerBaseUrl);
}
