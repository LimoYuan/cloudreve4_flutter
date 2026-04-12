/// 应用常量
class AppConstants {
  // 存储键
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyAccessExpires = 'access_expires';
  static const String keyRefreshExpires = 'refresh_expires';
  static const String keyRememberMe = 'remember_me';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';

  // 文件类型
  static const int fileTypeFile = 0;
  static const int fileTypeFolder = 1;

  // 默认图标
  static const String defaultAvatar = 'assets/images/default_avatar.png';

  // 时间格式
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String timeFormat = 'HH:mm:ss';
}

/// API响应码
class ApiCode {
  static const int success = 0;
  static const int continueCode = 203;
  static const int credentialInvalid = 40020;
  static const int incorrectPassword = 40069;
  static const int lockConflict = 40073;
  static const int staleVersion = 40076;
  static const int credentialRequired = 401;
  static const int permissionDenied = 403;
  static const int notFound = 404;
  static const int internalError = 500;
}
