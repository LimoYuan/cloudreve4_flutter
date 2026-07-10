import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import '../core/utils/direct_http_client.dart';

import '../data/models/user_model.dart';

import 'package:cloudreve4_flutter/mkw_packager/generated/qr_login_config.dart';
class QrLoginPayload {
  final String relayBaseUrl;
  final String cloudreveBaseUrl;
  final String sessionId;
  final String publicKey;
  final DateTime? expiresAt;
  final String? winDeviceName;

  QrLoginPayload({
    required this.relayBaseUrl,
    required this.cloudreveBaseUrl,
    required this.sessionId,
    required this.publicKey,
    this.expiresAt,
    this.winDeviceName,
  });

  factory QrLoginPayload.fromRaw(String raw) {
    final value = raw.trim();
    if (value.startsWith('mkwqrlogin://')) {
      return QrLoginPayload._fromCompactUri(value);
    }
    return QrLoginPayload._fromLegacyJson(value);
  }

  factory QrLoginPayload._fromCompactUri(String raw) {
    late final Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      throw Exception('不是有效的扫码登录二维码');
    }
    if (uri.scheme != 'mkwqrlogin') {
      throw Exception('二维码类型不正确');
    }

    final sessionId =
        uri.queryParameters['sid'] ?? uri.queryParameters['session_id'];
    final publicKey =
        uri.queryParameters['pk'] ?? uri.queryParameters['public_key'];
    if ([sessionId, publicKey].any((e) => e == null || e.isEmpty)) {
      throw Exception('二维码内容不完整');
    }

    DateTime? expiresAt;
    final rawExpiresAt =
        uri.queryParameters['exp'] ?? uri.queryParameters['expires_at'];
    if (rawExpiresAt != null && rawExpiresAt.isNotEmpty) {
      final seconds = int.tryParse(rawExpiresAt);
      expiresAt = seconds == null
          ? DateTime.tryParse(rawExpiresAt)
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }

    return QrLoginPayload(
      relayBaseUrl: '',
      cloudreveBaseUrl: '',
      sessionId: sessionId!,
      publicKey: publicKey!,
      expiresAt: expiresAt,
      winDeviceName: uri.queryParameters['device_name'],
    );
  }

  factory QrLoginPayload._fromLegacyJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw Exception('不是有效的扫码登录二维码');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['type'] != 'mkw_qr_login') {
      throw Exception('二维码类型不正确');
    }

    final relay = json['relay']?.toString();
    final cloudreve = json['cloudreve']?.toString();
    final sessionId = json['session_id']?.toString();
    final publicKey = json['public_key']?.toString();
    if ([
      relay,
      cloudreve,
      sessionId,
      publicKey,
    ].any((e) => e == null || e.isEmpty)) {
      throw Exception('二维码内容不完整');
    }

    DateTime? expiresAt;
    final rawExpiresAt = json['expires_at'];
    if (rawExpiresAt is int) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(rawExpiresAt * 1000);
    } else if (rawExpiresAt is String) {
      expiresAt = DateTime.tryParse(rawExpiresAt);
    }

    return QrLoginPayload(
      relayBaseUrl: relay!.replaceFirst(RegExp(r'/+$'), ''),
      cloudreveBaseUrl: cloudreve!,
      sessionId: sessionId!,
      publicKey: publicKey!,
      expiresAt: expiresAt,
      winDeviceName: json['device_name']?.toString(),
    );
  }

  QrLoginPayload resolveForServer(String serverBaseUrl) {
    final root = QrLoginService.cloudreveSiteBase(serverBaseUrl);
    return QrLoginPayload(
      relayBaseUrl: relayBaseUrl.isEmpty
          ? QrLoginService.relayBaseForCloudreve(root)
          : relayBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
      cloudreveBaseUrl: cloudreveBaseUrl.isEmpty ? root : cloudreveBaseUrl,
      sessionId: sessionId,
      publicKey: publicKey,
      expiresAt: expiresAt,
      winDeviceName: winDeviceName,
    );
  }
}

class QrLoginSession {
  final String relayBaseUrl;
  final String cloudreveBaseUrl;
  final String sessionId;
  final String qrPayload;
  final DateTime expiresAt;
  final SimpleKeyPair keyPair;

  QrLoginSession({
    required this.relayBaseUrl,
    required this.cloudreveBaseUrl,
    required this.sessionId,
    required this.qrPayload,
    required this.expiresAt,
    required this.keyPair,
  });
}

class QrLoginStatus {
  final String status;
  final DateTime? expiresAt;
  final String? message;

  QrLoginStatus({required this.status, this.expiresAt, this.message});

  factory QrLoginStatus.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expires_at'];
    return QrLoginStatus(
      status: json['status']?.toString() ?? 'pending',
      expiresAt: rawExpires is String ? DateTime.tryParse(rawExpires) : null,
      message: json['message']?.toString(),
    );
  }
}

class QrLoginTokenPayload {
  final String cloudreveBaseUrl;
  final UserModel user;
  final DateTime? authorizedAt;
  final String? mobileDevice;

  QrLoginTokenPayload({
    required this.cloudreveBaseUrl,
    required this.user,
    this.authorizedAt,
    this.mobileDevice,
  });

  factory QrLoginTokenPayload.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw Exception('扫码授权结果缺少用户信息');
    }
    final rawAuthorizedAt = json['authorized_at'];
    return QrLoginTokenPayload(
      cloudreveBaseUrl: json['cloudreve']?.toString() ?? '',
      user: UserModel.fromJson(Map<String, dynamic>.from(rawUser)),
      authorizedAt: rawAuthorizedAt is String
          ? DateTime.tryParse(rawAuthorizedAt)
          : null,
      mobileDevice: json['mobile_device']?.toString(),
    );
  }
}

class QrLoginService {
  QrLoginService._();

  static final QrLoginService instance = QrLoginService._();

  static void _ensureQrLoginRuntimeEnabled() {
    if (!mkwQrLoginEnabled) {
      throw Exception('扫码登录功能已关闭');
    }
  }

  final X25519 _keyExchange = X25519();
  final AesGcm _cipher = AesGcm.with256bits();

  static String cloudreveSiteBase(String rawBaseUrl) {
    final normalized = _ensureUrl(rawBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse(normalized);
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    var trimmedSegments = List<String>.from(segments);

    if (trimmedSegments.length >= 2 &&
        trimmedSegments[trimmedSegments.length - 2].toLowerCase() == 'api' &&
        trimmedSegments.last.toLowerCase() == 'v4') {
      trimmedSegments = trimmedSegments.sublist(0, trimmedSegments.length - 2);
    }

    final path = trimmedSegments.isEmpty ? '' : '/${trimmedSegments.join('/')}';
    return '${uri.scheme}://${uri.authority}$path'.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
  }

  static String cloudreveRootFromBaseUrl(String raw) => cloudreveSiteBase(raw);

  static String relayBaseForCloudreve(String rawBaseUrl) {
    return '${cloudreveSiteBase(rawBaseUrl)}/qr-login-relay';
  }

  static String relayBaseUrlFromCloudreve(String raw) =>
      relayBaseForCloudreve(raw);

  static String faviconUrlFromCloudreve(String rawBaseUrl) {
    return '${cloudreveSiteBase(rawBaseUrl)}/favicon.ico';
  }

  static bool isSameCloudreve(String a, String b) {
    return _normalizeForCompare(a) == _normalizeForCompare(b);
  }

  static String _normalizeForCompare(String raw) {
    final site = cloudreveSiteBase(raw);
    return site.replaceFirst(RegExp(r'/+$'), '').toLowerCase();
  }

  static String _ensureUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://$value';
  }

  Dio _dio(String relayBaseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: relayBaseUrl.replaceFirst(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
      connectionTimeout: const Duration(seconds: 10),
    );
    dio.httpClientAdapter = DirectHttpClientFactory.dioAdapter(
      connectionTimeout: const Duration(seconds: 10),
    );

    return dio;
  }

  Future<void> healthCheck(String relayBaseUrl) async {
    _ensureQrLoginRuntimeEnabled();
    final dio = _dio(relayBaseUrl);
    final response = await dio.get<Map<String, dynamic>>('/api/health');
    final data = response.data ?? const <String, dynamic>{};
    if (response.statusCode != 200 || data['ok'] != true) {
      throw Exception('扫码中转服务不可用');
    }
  }

  Future<QrLoginSession> createSession({
    required String cloudreveBaseUrl,
    String? deviceName,
  }) async {
    _ensureQrLoginRuntimeEnabled();
    final relayBaseUrl = relayBaseForCloudreve(cloudreveBaseUrl);
    final cloudreve = cloudreveSiteBase(cloudreveBaseUrl);
    final keyPair = await _keyExchange.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyText = base64Encode(publicKey.bytes);

    final dio = _dio(relayBaseUrl);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/session/create',
      data: {
        'cloudreve': cloudreve,
        'device_name': deviceName ?? _defaultDeviceName(),
        'public_key': publicKeyText,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final sessionId = data['session_id']?.toString();
    final qrPayload = data['qr_payload']?.toString();
    if (sessionId == null ||
        sessionId.isEmpty ||
        qrPayload == null ||
        qrPayload.isEmpty) {
      throw Exception('扫码中转服务返回数据异常');
    }

    final expiresAtRaw = data['expires_at']?.toString();
    return QrLoginSession(
      relayBaseUrl: relayBaseUrl,
      cloudreveBaseUrl: cloudreve,
      sessionId: sessionId,
      qrPayload: qrPayload,
      expiresAt: expiresAtRaw == null
          ? DateTime.now().add(const Duration(seconds: 120))
          : (DateTime.tryParse(expiresAtRaw) ??
                DateTime.now().add(const Duration(seconds: 120))),
      keyPair: keyPair,
    );
  }

  Future<QrLoginStatus> getStatus(QrLoginSession session) async {
    _ensureQrLoginRuntimeEnabled();
    final dio = _dio(session.relayBaseUrl);
    final response = await dio.get<Map<String, dynamic>>(
      '/api/session/${session.sessionId}/status',
    );
    return QrLoginStatus.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<QrLoginTokenPayload> getResult(QrLoginSession session) async {
    _ensureQrLoginRuntimeEnabled();
    final dio = _dio(session.relayBaseUrl);
    final response = await dio.get<Map<String, dynamic>>(
      '/api/session/${session.sessionId}/result',
    );
    final data = response.data ?? const <String, dynamic>{};

    final encryptedPayload = data['encrypted_payload']?.toString();
    final mobilePublicKey = data['mobile_public_key']?.toString();
    final nonceText = data['nonce']?.toString();
    final macText = data['mac']?.toString();

    if ([
      encryptedPayload,
      mobilePublicKey,
      nonceText,
      macText,
    ].any((e) => e == null || e.isEmpty)) {
      throw Exception('扫码授权结果不完整');
    }

    final remotePublicKey = SimplePublicKey(
      base64Decode(mobilePublicKey!),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: session.keyPair,
      remotePublicKey: remotePublicKey,
    );

    final clearBytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(encryptedPayload!),
        nonce: base64Decode(nonceText!),
        mac: Mac(base64Decode(macText!)),
      ),
      secretKey: sharedSecret,
    );

    final decoded = jsonDecode(utf8.decode(clearBytes));
    if (decoded is! Map) {
      throw Exception('扫码授权内容格式错误');
    }
    return QrLoginTokenPayload.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> markScanned(QrLoginPayload payload) async {
    _ensureQrLoginRuntimeEnabled();
    try {
      // Keep this lightweight: it helps verify that mobile actually touched the
      // same relay/session that desktop is polling, without printing user token.
      // ignore: avoid_print
      print(
        '[QR][mobile] markScanned sid=${payload.sessionId} relay=${payload.relayBaseUrl}',
      );
      final response = await _dio(payload.relayBaseUrl)
          .post<Map<String, dynamic>>(
            '/api/session/${payload.sessionId}/scan',
            data: {'device_name': _deviceName()},
          );
      // ignore: avoid_print
      print(
        '[QR][mobile] markScanned response=${response.statusCode} data=${response.data}',
      );
    } catch (e) {
      // 标记已扫码失败不影响后续确认流程，但要打印出来，避免误判为“电脑没反应”。
      // ignore: avoid_print
      print('[QR][mobile] markScanned failed: $e');
    }
  }

  Future<void> confirmLogin({
    required QrLoginPayload payload,
    required UserModel user,
    required String currentCloudreveBaseUrl,
  }) async {
    _ensureQrLoginRuntimeEnabled();
    if (!isSameCloudreve(currentCloudreveBaseUrl, payload.cloudreveBaseUrl)) {
      throw Exception('二维码所属站点与当前手机端登录站点不一致');
    }
    if (user.token == null || user.token!.isRefreshTokenExpired) {
      throw Exception('当前手机端登录凭证已过期，请重新登录后再扫码');
    }

    final keyPair = await _keyExchange.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final winPublicKey = SimplePublicKey(
      base64Decode(payload.publicKey),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: winPublicKey,
    );

    final clearPayload = utf8.encode(
      jsonEncode({
        'cloudreve': currentCloudreveBaseUrl,
        'user': user.toJson(),
        'mobile_device': _deviceName(),
        'authorized_at': DateTime.now().toIso8601String(),
      }),
    );
    final box = await _cipher.encrypt(clearPayload, secretKey: sharedSecret);

    // ignore: avoid_print
    print(
      '[QR][mobile] confirmLogin sid=${payload.sessionId} relay=${payload.relayBaseUrl} cloudreve=${payload.cloudreveBaseUrl}',
    );

    final response = await _dio(payload.relayBaseUrl)
        .post<Map<String, dynamic>>(
          '/api/session/${payload.sessionId}/confirm',
          data: {
            'device_name': _deviceName(),
            'mobile_public_key': base64Encode(publicKey.bytes),
            'encrypted_payload': base64Encode(box.cipherText),
            'nonce': base64Encode(box.nonce),
            'mac': base64Encode(box.mac.bytes),
          },
        );

    final data = response.data ?? const <String, dynamic>{};
    // ignore: avoid_print
    print(
      '[QR][mobile] confirmLogin response=${response.statusCode} data=$data',
    );
    if (response.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['message']?.toString() ?? '授权失败');
    }
  }

  String _defaultDeviceName() {
    try {
      return '${Platform.operatingSystem} ${Platform.localHostname}'.trim();
    } catch (_) {
      return 'Desktop';
    }
  }

  String _deviceName() {
    try {
      return 'Android ${Platform.localHostname}'.trim();
    } catch (_) {
      return 'Android 手机端';
    }
  }
}

