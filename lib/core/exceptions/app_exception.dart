/// 应用异常基类
class AppException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  AppException(this.message, {this.code, this.data});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// 网络异常
class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.data});
}

/// 认证异常
class AuthException extends AppException {
  AuthException(super.message, {super.code, super.data});
}

/// 服务器异常
class ServerException extends AppException {
  ServerException(super.message, {super.code, super.data});
}

/// Token过期异常
class TokenExpiredException extends AuthException {
  TokenExpiredException()
      : super('Token已过期，请重新登录', code: 401);
}

/// 未授权异常
class UnauthorizedException extends AuthException {
  UnauthorizedException() : super('未授权，请先登录', code: 403);
}

/// 文件不存在异常
class FileNotFoundException extends AppException {
  FileNotFoundException() : super('文件不存在', code: 404);
}

/// 存储空间不足异常
class StorageSpaceException extends AppException {
  StorageSpaceException() : super('存储空间不足', code: 507);
}
