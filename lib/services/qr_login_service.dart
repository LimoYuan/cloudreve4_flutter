import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../data/models/user_model.dart';

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

  QrLoginStatus({
    required this.status,
    this.expiresAt,
    this.message,
  });

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
      authorizedAt: rawAuthorizedAt is String ? DateTime.tryParse(rawAuthorizedAt) : null,
      mobileDevice: json['mobile_device']?.toString(),
    );
  }
}

class QrLoginService {
  QrLoginService._();

  static final QrLoginService instance = QrLoginService._();

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
    return '${uri.scheme}://${uri.authority}$path';
  }

  static String relayBaseForCloudreve(String rawBaseUrl) {
    return '${cloudreveSiteBase(rawBaseUrl)}/qr-login-relay';
  }

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
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
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
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
    return dio;
  }

  Future<void> healthCheck(String relayBaseUrl) async {
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
    if (sessionId == null || sessionId.isEmpty || qrPayload == null || qrPayload.isEmpty) {
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
          : (DateTime.tryParse(expiresAtRaw) ?? DateTime.now().add(const Duration(seconds: 120))),
      keyPair: keyPair,
    );
  }

  Future<QrLoginStatus> getStatus(QrLoginSession session) async {
    final dio = _dio(session.relayBaseUrl);
    final response = await dio.get<Map<String, dynamic>>('/api/session/${session.sessionId}/status');
    return QrLoginStatus.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<QrLoginTokenPayload> getResult(QrLoginSession session) async {
    final dio = _dio(session.relayBaseUrl);
    final response = await dio.get<Map<String, dynamic>>('/api/session/${session.sessionId}/result');
    final data = response.data ?? const <String, dynamic>{};

    final encryptedPayload = data['encrypted_payload']?.toString();
    final mobilePublicKey = data['mobile_public_key']?.toString();
    final nonceText = data['nonce']?.toString();
    final macText = data['mac']?.toString();

    if ([encryptedPayload, mobilePublicKey, nonceText, macText].any((e) => e == null || e.isEmpty)) {
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

  String _defaultDeviceName() {
    try {
      return '${Platform.operatingSystem} ${Platform.localHostname}'.trim();
    } catch (_) {
      return 'Desktop';
    }
  }
}
