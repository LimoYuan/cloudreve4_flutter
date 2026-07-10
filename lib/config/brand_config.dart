import '../core/utils/server_url_utils.dart';
import '../mkw_packager/generated/brand_config.dart' as mkw_brand;
import '../mkw_packager/generated/qr_config.dart' as mkw_qr;
import '../mkw_packager/generated/server_config.dart' as mkw_server;
import '../mkw_packager/generated/update_config.dart' as mkw_update;

/// 品牌/定制打包配置。
///
/// 接入原则：
/// - 主应用只接入一次这个配置入口。
/// - 打包工具以后只覆盖 lib/mkw_packager/generated/*.dart。
/// - 平台级配置（包名、图标、应用名）在打包阶段直接改平台文件。
class BrandConfig {
  BrandConfig._();

  /// 兼容旧方案：仍支持 --dart-define 注入。
  static const bool _envBrandedBuild = bool.fromEnvironment(
    'MKW_BRANDED_BUILD',
    defaultValue: false,
  );

  static const String _envAppName = String.fromEnvironment(
    'MKW_APP_NAME',
    defaultValue: 'Cloudreve',
  );

  static const String _envFixedServerName = String.fromEnvironment(
    'MKW_FIXED_SERVER_NAME',
    defaultValue: '',
  );

  static const String _envFixedServerBaseUrl = String.fromEnvironment(
    'MKW_FIXED_SERVER_BASE_URL',
    defaultValue: '',
  );

  static const bool _envLockServer = bool.fromEnvironment(
    'MKW_LOCK_SERVER',
    defaultValue: false,
  );

  /// 是否是定制构建。
  static bool get brandedBuild =>
      _envBrandedBuild ||
      mkw_brand.mkwBrandConfigReady ||
      mkw_server.mkwServerConfigReady ||
      mkw_update.mkwUpdateConfigReady ||
      mkw_qr.mkwQrConfigReady;

  /// App 内显示名称。
  static String get appName {
    final generatedName = mkw_brand.mkwAppName.trim();
    if (mkw_brand.mkwBrandConfigReady && generatedName.isNotEmpty) {
      return generatedName;
    }

    final envName = _envAppName.trim();
    return envName.isNotEmpty ? envName : 'Cloudreve';
  }

  /// 包名。运行时只用于记录/显示；真正包名由打包阶段修改平台文件。
  static String get packageName {
    final generated = mkw_brand.mkwPackageName.trim();
    if (mkw_brand.mkwBrandConfigReady && generated.isNotEmpty) {
      return generated;
    }
    return 'com.limo.cloudreve4_flutter';
  }

  /// 是否锁定服务器。锁定后 UI 不再显示服务器选择/管理入口。
  static bool get lockServer => hasFixedServer;

  /// 当前构建是否启用固定服务器。
  static bool get hasFixedServer {
    final generatedBase = mkw_server.mkwServerBaseUrl.trim();
    final generatedApi = mkw_server.mkwServerApiUrl.trim();

    final generatedFixed =
        mkw_server.mkwFixedServerEnabled &&
        (generatedBase.isNotEmpty || generatedApi.isNotEmpty);

    final envFixed = _envLockServer && _envFixedServerBaseUrl.trim().isNotEmpty;

    return generatedFixed || envFixed;
  }

  /// 固定服务器在 UI / 本地存储里的显示名称。
  static String get effectiveServerName {
    final generatedName = mkw_server.mkwServerName.trim();
    if (mkw_server.mkwFixedServerEnabled && generatedName.isNotEmpty) {
      return generatedName;
    }

    final envName = _envFixedServerName.trim();
    if (envName.isNotEmpty) return envName;

    return appName.trim().isNotEmpty ? appName.trim() : 'Cloudreve';
  }

  /// 规范化后的 Cloudreve V4 API 地址，确保末尾为 /api/v4。
  static String get effectiveServerBaseUrl {
    final generatedApi = mkw_server.mkwServerApiUrl.trim();
    if (mkw_server.mkwFixedServerEnabled && generatedApi.isNotEmpty) {
      return ServerUrlUtils.toApiBaseUrl(generatedApi);
    }

    final generatedBase = mkw_server.mkwServerBaseUrl.trim();
    if (mkw_server.mkwFixedServerEnabled && generatedBase.isNotEmpty) {
      return ServerUrlUtils.toApiBaseUrl(generatedBase);
    }

    return ServerUrlUtils.toApiBaseUrl(_envFixedServerBaseUrl);
  }

  /// 站点根地址，不带 /api/v4。
  static String get effectiveServerSiteUrl =>
      ServerUrlUtils.toSiteBaseUrl(effectiveServerBaseUrl);

  /// 官方 Cloudreve v4 Ping 地址。
  static String get effectiveServerPingUrl {
    final generated = mkw_server.mkwServerPingUrl.trim();
    if (mkw_server.mkwFixedServerEnabled && generated.isNotEmpty) {
      return generated;
    }
    final api = effectiveServerBaseUrl;
    return api.isEmpty ? '' : '$api/site/ping';
  }

  /// 是否允许用户自己选服务器。
  static bool get allowUserServerSelection => !hasFixedServer;

  /// 是否隐藏服务器选择/管理入口。
  static bool get hideServerSelector => hasFixedServer;

  /// 是否启用扫码登录入口。
  static bool get qrLoginEnabled => mkw_qr.mkwQrLoginEnabled;

  /// 是否启用在线更新。
  static bool get onlineUpdateEnabled => mkw_update.mkwOnlineUpdateEnabled;

  /// 是否同步官方更新。
  static bool get syncOfficialUpdate => mkw_update.mkwSyncOfficialUpdate;

  /// update.json 地址。
  static String get updateJsonUrl => mkw_update.mkwUpdateJsonUrl;
}
