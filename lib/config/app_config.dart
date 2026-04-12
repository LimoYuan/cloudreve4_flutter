/// 应用配置
class AppConfig {
  /// 应用名称
  static const String appName = 'Cloudreve';

  /// 应用版本
  static const String version = '1.0.0';

  /// 构建号
  static const int buildNumber = 1;

  /// 是否为调试模式
  static const bool debugMode = bool.fromEnvironment('dart.vm.product');

  /// 默认分页大小
  static const int defaultPageSize = 50;

  /// 最大分页大小
  static const int maxPageSize = 200;

  /// 上传并发数
  static const int uploadConcurrency = 3;

  /// 下载并发数
  static const int downloadConcurrency = 3;
}
