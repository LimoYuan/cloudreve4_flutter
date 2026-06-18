import '../services/storage_service.dart';
import 'brand_config.dart';

/// API配置
class ApiConfig {
  static const int connectTimeout = 5;
  static const int receiveTimeout = 60;
  static const int sendTimeout = 60;

  /// API基础URL（需要根据实际后端地址配置）
  static const String defaultBaseUrl = 'https://demo.cloudreve.org/api/v4';

  /// 获取API基础URL（优先使用自定义地址，否则使用默认地址）
  static Future<String> get baseUrl async {
    if (BrandConfig.hasFixedServer) {
      return BrandConfig.effectiveServerBaseUrl;
    }

    final customUrl = await StorageService.instance.customBaseUrl;
    return customUrl ?? defaultBaseUrl;
  }
}
