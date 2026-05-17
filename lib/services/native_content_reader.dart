import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Android 原生文件选择结果。
///
/// uri 是 SAF / ContentResolver 的 content:// URI；上传时可用它直接分片读取。
class NativePickedFile {
  final String uri;
  final String name;
  final int size;
  final String? mimeType;

  const NativePickedFile({
    required this.uri,
    required this.name,
    required this.size,
    this.mimeType,
  });

  factory NativePickedFile.fromMap(Map<dynamic, dynamic> map) {
    return NativePickedFile(
      uri: map['uri']?.toString() ?? '',
      name: map['name']?.toString() ?? 'unknown',
      size: (map['size'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType']?.toString(),
    );
  }
}

class NativeUploadException implements Exception {
  final int? statusCode;
  final String message;
  final String? body;
  final Map<String, dynamic>? details;

  const NativeUploadException({
    required this.message,
    this.statusCode,
    this.body,
    this.details,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'NativeUploadException HTTP $statusCode: $message';
    }
    return 'NativeUploadException: $message';
  }
}

/// Android ContentResolver / native upload bridge.
class NativeContentReader {
  NativeContentReader._() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static final NativeContentReader instance = NativeContentReader._();

  static const MethodChannel _channel =
      MethodChannel('cloudreve/content_reader');

  final Map<String, void Function(int sent, int total)> _progressCallbacks = {};

  bool get isSupported => Platform.isAndroid;

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method != 'uploadProgress') return null;

    final args = call.arguments;
    if (args is! Map) return null;

    final transferId = args['transferId']?.toString();
    final sent = (args['sent'] as num?)?.toInt();
    final total = (args['total'] as num?)?.toInt();

    if (transferId == null || sent == null || total == null) return null;

    final callback = _progressCallbacks[transferId];
    callback?.call(sent, total);
    return null;
  }

  /// 使用 Android ACTION_OPEN_DOCUMENT 选择文件。
  ///
  /// 这条路径不会走 file_picker，因此不会先把大文件复制进 App 缓存目录。
  Future<List<NativePickedFile>> pickFiles({
    required String type,
    bool allowMultiple = true,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Native file picker is only supported on Android');
    }

    final result = await _channel.invokeMethod<List<dynamic>>(
      'pickFiles',
      {
        'type': type,
        'allowMultiple': allowMultiple,
      },
    );

    final rawItems = result ?? const <dynamic>[];
    return rawItems
        .whereType<Map>()
        .map((item) => NativePickedFile.fromMap(item))
        .where((item) => item.uri.isNotEmpty && item.size >= 0)
        .toList();
  }

  Future<bool> persistReadPermission(String uri) async {
    if (!isSupported) return false;

    final result = await _channel.invokeMethod<bool>(
      'persistReadPermission',
      {'uri': uri},
    );

    return result ?? false;
  }

  Future<Uint8List> readChunk({
    required String uri,
    required int offset,
    required int length,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('ContentResolver is only supported on Android');
    }

    final result = await _channel.invokeMethod<Uint8List>(
      'readChunk',
      {
        'uri': uri,
        'offset': offset,
        'length': length,
      },
    );

    if (result == null) {
      throw Exception('Android ContentResolver returned null chunk');
    }

    return result;
  }

  Future<Map<String, dynamic>> uploadChunkToUrl({
    required String uri,
    required String uploadUrl,
    required String method,
    required int offset,
    required int length,
    required Map<String, String> headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Native upload is only supported on Android');
    }

    final transferId =
        '${DateTime.now().microsecondsSinceEpoch}_${uri.hashCode}_$offset';

    if (onProgress != null) {
      _progressCallbacks[transferId] = onProgress;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'uploadChunkToUrl',
        {
          'transferId': transferId,
          'uri': uri,
          'uploadUrl': uploadUrl,
          'method': method,
          'offset': offset,
          'length': length,
          'headers': headers,
        },
      );

      return Map<String, dynamic>.from(result ?? const {});
    } on PlatformException catch (e) {
      final details = e.details is Map
          ? Map<String, dynamic>.from(e.details as Map)
          : null;

      throw NativeUploadException(
        statusCode: (details?['statusCode'] as num?)?.toInt(),
        body: details?['body']?.toString(),
        details: details,
        message: e.message ?? e.code,
      );
    } finally {
      _progressCallbacks.remove(transferId);
    }
  }
}
