import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions/app_exception.dart';

/// Converts technical exceptions, HTTP payloads and SDK error strings into
/// messages that are safe to show to end users.
class UserFriendlyError {
  UserFriendlyError._();

  static String fromObject(
    Object? error, {
    String fallback = '操作失败，请稍后重试',
    String? action,
  }) {
    if (error == null) return fallback;

    if (error is AppException) {
      return fromText(
        error.message,
        code: error.code,
        fallback: fallback,
        action: action,
      );
    }

    if (error is DioException) {
      final data = error.response?.data;
      final status = error.response?.statusCode;
      final extracted = _messageFromData(data);
      final text = [
        extracted,
        error.message,
        error.error?.toString(),
        status == null ? null : 'HTTP $status',
      ].whereType<String>().join(' ');
      return fromText(text, code: status, fallback: fallback, action: action);
    }

    return fromText(error.toString(), fallback: fallback, action: action);
  }

  static String fromText(
    String? raw, {
    int? code,
    String fallback = '操作失败，请稍后重试',
    String? action,
  }) {
    final original = (raw ?? '').trim();
    if (original.isEmpty) return fallback;

    final decoded = _tryDecodePercent(original);
    final text = _stripTechnicalPrefix(decoded).trim();
    final lower = text.toLowerCase();
    final compact = lower.replaceAll(RegExp(r'\s+'), ' ');

    final serverCode = _extractServerCode(text) ?? code;
    final serverMessage = _extractServerMessage(text);
    final errorKey = _extractErrorKey(text).toLowerCase();

    if (serverCode == 40004 ||
        lower.contains('object existed') ||
        lower.contains('objectexisted') ||
        lower.contains('already exists') ||
        lower.contains('file exists') ||
        lower.contains('同名') ||
        lower.contains('已存在')) {
      if (action == 'folder') {
        return '同名文件夹已存在，请换一个名称后再试。';
      }
      if (action == 'upload') {
        return '云端已存在同名文件，请改名后重新上传，或先删除云端同名文件。';
      }
      return '同名文件或文件夹已存在，请换一个名称后再试。';
    }

    if (serverCode == 40073 || lower.contains('lock conflict')) {
      return '文件正在被占用或处理中，请稍后再试。';
    }

    if (errorKey == 'itemnotfound' ||
        lower.contains('itemnotfound') ||
        lower.contains('item not found')) {
      if (action == 'upload' || lower.contains('upload session')) {
        return '上传会话已失效，通常是网络中断、应用停留太久或云端临时会话过期。请重新选择文件后再上传。';
      }
      return '目标文件或文件夹不存在，可能已被移动或删除，请刷新后重试。';
    }

    if (serverCode == 404 || lower.contains('http 404')) {
      if (action == 'upload' || lower.contains('upload session')) {
        return '上传会话已失效，请重新选择文件后再上传。';
      }
      return '目标资源不存在，可能已被移动或删除，请刷新后重试。';
    }

    if (serverCode == 401 ||
        serverCode == 40020 ||
        lower.contains('unauthorized') ||
        lower.contains('invalid token') ||
        lower.contains('token') && lower.contains('expired') ||
        lower.contains('登录已过期') ||
        lower.contains('未授权')) {
      return '登录状态已过期，请重新登录。';
    }

    if (serverCode == 403 ||
        lower.contains('permission denied') ||
        lower.contains('forbidden') ||
        lower.contains('无权限') ||
        lower.contains('没有权限')) {
      return '当前账号没有权限执行此操作，请检查权限或联系管理员。';
    }

    if (serverCode == 507 ||
        lower.contains('insufficient storage') ||
        lower.contains('quota') ||
        lower.contains('空间不足') ||
        lower.contains('容量不足')) {
      return '云端存储空间不足，请清理空间后再试。';
    }

    if (serverCode == 413 ||
        lower.contains('payload too large') ||
        lower.contains('file too large') ||
        lower.contains('文件过大')) {
      return '文件过大，超出服务器允许的大小限制。';
    }

    if (serverCode == 429 || lower.contains('too many requests')) {
      return '请求过于频繁，请稍后再试。';
    }

    if (lower.contains('invalid credentials') ||
        lower.contains('wrong password') ||
        lower.contains('incorrect password') ||
        lower.contains('password') && lower.contains('invalid') ||
        lower.contains('账号或密码') ||
        lower.contains('密码错误')) {
      return '账号或密码不正确，请检查后重试。';
    }

    if (lower.contains('captcha') || lower.contains('turnstile') || lower.contains('验证码')) {
      return '验证码验证失败或已过期，请重新完成验证。';
    }

    if (lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('ssl') ||
        lower.contains('tls')) {
      return '网络证书校验失败，请检查代理、网络环境或服务器证书。';
    }

    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connection terminated') ||
        lower.contains('connection reset') ||
        lower.contains('connection refused') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      return '网络连接异常，请检查网络、代理或服务器地址后重试。';
    }

    if (serverMessage != null && serverMessage.isNotEmpty) {
      final clean = _stripTechnicalPrefix(serverMessage).trim();
      if (!_looksTechnical(clean)) return clean;
    }

    if (!_looksTechnical(text)) {
      return text;
    }

    if (action == 'upload') {
      return '上传失败，请检查网络、账号权限或云端存储状态后重试。';
    }
    if (action == 'login') {
      return '登录失败，请检查账号、密码、服务器地址或网络后重试。';
    }
    if (action == 'download') {
      return '下载失败，请检查网络或文件是否仍然存在。';
    }

    // Keep this generic. Raw exception class names, JSON bodies and stack traces
    // should stay in logs instead of being shown to normal users.
    if (compact.contains('http') || compact.contains('exception')) {
      return fallback;
    }

    return fallback;
  }

  static String _stripTechnicalPrefix(String value) {
    var text = value.trim();
    final prefixes = <String>[
      'Exception:',
      'Exception: ',
      'AppException:',
      'ServerException:',
      'NetworkException:',
      'AuthException:',
      'DioException:',
      'NativeUploadException:',
    ];

    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (text.startsWith(prefix)) {
          text = text.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    final httpPrefix = RegExp(r'^HTTP\s+\d+\s*:?\s*', caseSensitive: false);
    text = text.replaceFirst(httpPrefix, '').trim();
    text = text.replaceFirst(RegExp(r'\s*\(code:\s*null\)\s*$', caseSensitive: false), '').trim();
    return text;
  }

  static String _tryDecodePercent(String value) {
    if (!value.contains('%')) return value;
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      try {
        return Uri.decodeComponent(value);
      } catch (_) {
        return value;
      }
    }
  }

  static String? _messageFromData(dynamic data) {
    if (data is Map) {
      return _extractFromMap(data);
    }
    if (data is String) return data;
    return data?.toString();
  }

  static String? _extractFromMap(Map data) {
    final direct = data['msg'] ?? data['message'] ?? data['error'] ?? data['detail'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final nested = data['error'];
    if (nested is Map) {
      final nestedMsg = nested['message'] ?? nested['msg'] ?? nested['code'];
      if (nestedMsg != null) return nestedMsg.toString();
    }

    return null;
  }

  static int? _extractServerCode(String value) {
    final codeMatch = RegExp(r'"code"\s*:\s*(\d+)').firstMatch(value);
    if (codeMatch != null) return int.tryParse(codeMatch.group(1)!);

    final parenCode = RegExp(r'\(code:\s*(\d+)\)', caseSensitive: false).firstMatch(value);
    if (parenCode != null) return int.tryParse(parenCode.group(1)!);

    final httpCode = RegExp(r'HTTP\s+(\d+)', caseSensitive: false).firstMatch(value);
    if (httpCode != null) return int.tryParse(httpCode.group(1)!);

    return null;
  }

  static String? _extractServerMessage(String value) {
    final decodedJson = _tryDecodeJsonString(value);
    if (decodedJson != null) {
      final fromMap = _extractFromMap(decodedJson);
      if (fromMap != null) return fromMap;
    }

    for (final key in const ['message', 'msg', 'detail', 'error_description']) {
      final match = RegExp('"$key"\\s*:\\s*"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"').firstMatch(value);
      if (match != null) return _unescapeJsonString(match.group(1)!);
    }

    return null;
  }

  static String _extractErrorKey(String value) {
    final decodedJson = _tryDecodeJsonString(value);
    if (decodedJson != null) {
      final error = decodedJson['error'];
      if (error is Map && error['code'] != null) return error['code'].toString();
      if (error is String) return error;
      if (decodedJson['code'] != null) return decodedJson['code'].toString();
    }

    final nestedCode = RegExp(r'"error"\s*:\s*\{[^}]*"code"\s*:\s*"([^"]+)"').firstMatch(value);
    if (nestedCode != null) return nestedCode.group(1) ?? '';

    return '';
  }

  static Map<String, dynamic>? _tryDecodeJsonString(String value) {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final jsonText = value.substring(start, end + 1);
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static String _unescapeJsonString(String value) {
    try {
      return jsonDecode('"$value"').toString();
    } catch (_) {
      return value.replaceAll(r'\"', '"');
    }
  }

  static bool _looksTechnical(String value) {
    final lower = value.toLowerCase();
    if (value.length > 120) return true;
    return lower.contains('exception') ||
        lower.contains('stacktrace') ||
        lower.contains('requestoptions') ||
        lower.contains('response body') ||
        lower.contains('nativeuploadexception') ||
        lower.contains('{"') ||
        lower.contains('"error"') ||
        lower.contains('http 4') ||
        lower.contains('http 5') ||
        lower.contains('dioexception');
  }
}
