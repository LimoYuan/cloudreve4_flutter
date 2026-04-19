import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';

/// API响应
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final String? error;
  final String? correlationId;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.error,
    this.correlationId,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse<T>(
      code: json['code'] as int? ?? 0,
      message: json['msg'] as String? ?? '',
      data: json['data'] as T?,
      error: json['error'] as String?,
      correlationId: json['correlation_id'] as String?,
    );
  }

  bool get isSuccess => code == 0;

  bool get isContinue => code == 203;
}

/// API服务
class ApiService {
  late Dio _dio;
  static ApiService? _instance;
  bool _isRefreshing = false;
  final List<Completer<void>> _refreshSubscribers = [];
  bool _initialized = false;

  /// 获取 token 的回调
  Future<String?> Function()? getTokenCallback;
  /// 刷新 token 的回调
  Future<void> Function()? refreshTokenCallback;
  /// 清除认证数据的回调
  Future<void> Function()? clearAuthCallback;

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.defaultBaseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        sendTimeout: const Duration(seconds: ApiConfig.sendTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(_requestInterceptor());
    _dio.interceptors.add(_responseInterceptor());
    _dio.interceptors.add(_errorInterceptor());
  }

  /// 是否正在刷新token
  bool get isRefreshing => _isRefreshing;

  /// 获取单例
  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  /// 设置认证回调
  /// 由 AuthProvider 在初始化时调用
  static void setAuthCallbacks({
    required Future<String?> Function() getToken,
    required Future<void> Function() refreshToken,
    required Future<void> Function() clearAuth,
  }) {
    final service = instance;
    service.getTokenCallback = getToken;
    service.refreshTokenCallback = refreshToken;
    service.clearAuthCallback = clearAuth;
  }

  /// 初始化API服务（设置正确的baseUrl）
  Future<void> init() async {
    if (_initialized) return;

    final baseUrl = await ApiConfig.baseUrl;
    _dio.options.baseUrl = baseUrl;
    _initialized = true;
  }

  /// 请求拦截器
  Interceptor _requestInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 从回调获取 Token
        if (getTokenCallback != null) {
          final token = await getTokenCallback!();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
    );
  }

  /// 响应拦截器
  Interceptor _responseInterceptor() {
    return InterceptorsWrapper(
      onResponse: (response, handler) {
        debugPrint(
          'API Response: ${response.statusCode} - ${response.requestOptions.uri}',
        );

        // 检查 JSON 响应中的 code 字段
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          final code = data['code'] as int?;
          debugPrint('_responseInterceptor -> JSON code: $code');
          if (code == 401) {
            // HTTP 200 但 JSON code 是 401，需要处理未授权
            final isNoAuth = response.requestOptions.extra['noAuth'] as bool? ?? false;
            debugPrint('_responseInterceptor -> isNoAuth: $isNoAuth');
            if (!isNoAuth) {
              // 直接在响应拦截器中处理 401
              debugPrint('_responseInterceptor -> 触发 401 处理');
              // 异步处理，不阻塞响应
              _handle401InResponse(response.requestOptions);
            }
          }
        }
        return handler.next(response);
      },
    );
  }

  /// 在响应拦截器中处理 401 错误
  Future<void> _handle401InResponse(RequestOptions requestOptions) async {
    final path = requestOptions.path;
    if (path.contains('/session/token/refresh')) {
      return;
    }

    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      debugPrint('_handle401InResponse -> 开始刷新 token');
      if (refreshTokenCallback != null) {
        await refreshTokenCallback!();
      }
      debugPrint('_handle401InResponse -> token 刷新完成');
    } catch (e) {
      debugPrint('_handle401InResponse -> 刷新失败: $e');
      if (clearAuthCallback != null) {
        await clearAuthCallback!();
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// 错误拦截器
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        debugPrint("_errorInterceptor -> 获取files列表: response");
        debugPrint('API Error: ${error.requestOptions.uri} - ${error.message}');

        // 检查是否是 401 错误（HTTP 401 或 JSON code: 401）
        bool is401Error = error.response?.statusCode == 401;
        if (!is401Error && error.response?.data is Map<String, dynamic>) {
          final data = error.response!.data as Map<String, dynamic>;
          is401Error = data['code'] == 401;
        }

        if (is401Error) {
          final isNoAuth =
              error.requestOptions.extra['noAuth'] as bool? ?? false;
          if (!isNoAuth) {
            // 不是noAuth请求，需要刷新token
            final response = await _handle401Error(error, handler);
            if (response != null) {
              return handler.resolve(response);
            }
          }
        }

        // 处理错误
        if (error.response == null) {
          // 网络错误
          throw NetworkException(
            '网络连接失败，请检查网络设置',
            code: error.response?.statusCode,
          );
        }

        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        debugPrint('Error Response Data: $responseData');

        if (responseData is Map<String, dynamic>) {
          final response = ApiResponse.fromJson(responseData);
          throw ServerException(response.message, code: response.code);
        }

        throw ServerException(
          responseData?.toString() ?? '请求失败',
          code: statusCode,
        );
      },
    );
  }

  /// 处理401错误，尝试刷新token
  Future<Response?> _handle401Error(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // 检查是否需要跳过token检查（如刷新token请求本身）
    final path = error.requestOptions.path;
    if (path.contains('/session/token/refresh')) {
      // 刷新token的请求也失败了，直接返回错误
      return null;
    }

    // 如果正在刷新token，等待刷新完成后再重试
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshSubscribers.add(completer);

      // 等待刷新完成
      await completer.future;

      // 刷新完成后，移除旧的 Authorization header，让拦截器重新添加新 token
      error.requestOptions.headers.remove('Authorization');

      // 重试请求（拦截器会自动添加新 token）
      return await _dio.fetch(error.requestOptions);
    }

    // 开始刷新token
    _isRefreshing = true;

    try {
      // 调用回调刷新 token
      if (refreshTokenCallback != null) {
        await refreshTokenCallback!();
      }

      _isRefreshing = false;

      // 通知所有等待的请求可以重试了
      for (final subscriber in _refreshSubscribers) {
        if (!subscriber.isCompleted) {
          subscriber.complete();
        }
      }
      _refreshSubscribers.clear();

      // 重试当前请求：移除旧 header，让拦截器重新添加新 token
      error.requestOptions.headers.remove('Authorization');
      return await _dio.fetch(error.requestOptions);
    } catch (e) {
      debugPrint('Refresh token failed: $e');
      _isRefreshing = false;

      // 刷新失败，清除认证数据
      if (clearAuthCallback != null) {
        await clearAuthCallback!();
      }

      // 通知所有等待的请求
      for (final subscriber in _refreshSubscribers) {
        if (!subscriber.isCompleted) {
          subscriber.completeError(e);
        }
      }
      _refreshSubscribers.clear();

      // 返回null，让原始错误继续传播
      return null;
    }
  }

  /// GET请求
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
  }) async {
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: {'noAuth': noAuth}),
    );
    debugPrint("获取files列表: $response");
    return _parseResponse<T>(response);
  }

  /// POST请求
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
    Map<String, dynamic>? headers,
  }) async {
    debugPrint('API POST Request: $path');
    debugPrint('Request Data: $data');

    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(extra: {'noAuth': noAuth}, headers: headers),
    );

    debugPrint('Response Data: ${response.data}');

    return _parseResponse<T>(response);
  }

  /// POST请求（带上传进度）
  Future<T> postWithProgress<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
    Map<String, dynamic>? headers,
    ProgressCallback? onSendProgress,
  }) async {
    debugPrint('API POST Request with progress: $path');

    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(extra: {'noAuth': noAuth}, headers: headers),
      onSendProgress: onSendProgress,
    );

    debugPrint('Response Data: ${response.data}');

    return _parseResponse<T>(response);
  }

  /// PUT请求
  Future<T> put<T>(String path, {dynamic data, bool noAuth = false}) async {
    final response = await _dio.put<T>(
      path,
      data: data,
      options: Options(extra: {'noAuth': noAuth}),
    );
    return _parseResponse<T>(response);
  }

  /// PATCH请求
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
  }) async {
    final response = await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(extra: {'noAuth': noAuth}),
    );
    return _parseResponse<T>(response);
  }

  /// DELETE请求
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
  }) async {
    final response = await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(extra: {'noAuth': noAuth}),
    );
    return _parseResponse<T>(response);
  }

  /// 解析响应
  T _parseResponse<T>(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final apiResponse = ApiResponse<T>.fromJson(data);
      if (!apiResponse.isSuccess && !apiResponse.isContinue) {
        throw ServerException(apiResponse.message, code: apiResponse.code);
      }
      return apiResponse.data as T;

    }
    return data as T;
  }
}
