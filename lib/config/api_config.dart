/// API配置
class ApiConfig {
  static const int connectTimeout = 5;
  static const int receiveTimeout = 60;
  static const int sendTimeout = 60;

  /// API基础URL（需要根据实际后端地址配置）
  static String get baseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://demo.cloudreve.org/api/v4',
  );
}
