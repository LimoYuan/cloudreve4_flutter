import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../core/exceptions/app_exception.dart';
import '../data/models/user_model.dart';
import 'storage_service.dart';

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

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
      sendTimeout: const Duration(seconds: ApiConfig.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

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

  /// 请求拦截器
  Interceptor _requestInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加Token
        final token = await StorageService.instance.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    );
  }

  /// 响应拦截器
  Interceptor _responseInterceptor() {
    return InterceptorsWrapper(
      onResponse: (response, handler) {
        debugPrint('API Response: ${response.statusCode} - ${response.requestOptions.uri}');
        return handler.next(response);
      },
    );
  }

  /// 错误拦截器
  Interceptor _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        debugPrint('API Error: ${error.requestOptions.uri} - ${error.message}');

        // 处理401未授权错误，尝试刷新token
        if (error.response?.statusCode == 401) {
          final isNoAuth = error.requestOptions.extra['noAuth'] as bool? ?? false;
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

    // 如果正在刷新token，将请求加入队列
    if (_isRefreshing) {
      return await _retryAfterRefresh();
    }

    // 开始刷新token
    _isRefreshing = true;

    try {
      // 获取新的token
      final refreshToken = await StorageService.instance.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        // 没有refresh token，无法刷新
        return null;
      }

      // 创建一个新的Dio实例来避免循环调用
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        sendTimeout: const Duration(seconds: ApiConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
        },
      ));

      final response = await refreshDio.post<Map<String, dynamic>>(
        '/session/token/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final tokenModel = TokenModel.fromJson(data);

      // 保存新的token
      await StorageService.instance.setAccessToken(tokenModel.accessToken);
      await StorageService.instance.setRefreshToken(tokenModel.refreshToken);

      // 设置新token到Dio
      _dio.options.headers['Authorization'] = 'Bearer ${tokenModel.accessToken}';

      // 重试原始请求
      final options = error.requestOptions;
      options.headers['Authorization'] = 'Bearer ${tokenModel.accessToken}';

      _isRefreshing = false;

      // 重试当前请求
      final retryResponse = await _dio.fetch(options);
      return retryResponse;
    } catch (e) {
      debugPrint('Refresh token failed: $e');
      _isRefreshing = false;

      // 返回null，让原始错误继续传播
      return null;
    }
  }

  /// 等待token刷新后重试请求
  Future<Response?> _retryAfterRefresh() async {
    // 等待刷新完成（简单轮询）
    int count = 0;
    const maxCount = 50; // 最多等待5秒
    while (_isRefreshing && count < maxCount) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 刷新完成或超时，返回null让原始错误继续传播
    return null;
  }

  /// 设置Token
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 清除Token
  void clearToken() {
    _dio.options.headers.remove('Authorization');
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
      options: Options(
        extra: {'noAuth': noAuth},
      ),
    );
    return _parseResponse<T>(response);
  }

  /// POST请求
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool noAuth = false,
  }) async {
    debugPrint('API POST Request: $path');
    debugPrint('Request Data: $data');

    final response = await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        extra: {'noAuth': noAuth},
      ),
    );

    debugPrint('Response Data: ${response.data}');

    return _parseResponse<T>(response);
  }

  /// PUT请求
  Future<T> put<T>(
    String path, {
    dynamic data,
    bool noAuth = false,
  }) async {
    final response = await _dio.put<T>(
      path,
      data: data,
      options: Options(
        extra: {'noAuth': noAuth},
      ),
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
      options: Options(
        extra: {'noAuth': noAuth},
      ),
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
      options: Options(
        extra: {'noAuth': noAuth},
      ),
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
