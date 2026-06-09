import 'auth_service.dart';

/// Cloudreve V4 验证码类型解析结果。
///
/// Cloudreve 官方配置接口 `/site/config/basic` 会返回 `captcha_type`，
/// 并按类型返回对应的站点 Key，例如 `captcha_ReCaptchaKey`、
/// `turnstile_site_id` 等。图形验证码仍通过 `/site/captcha` 获取
/// `image + ticket`。
class CloudreveCaptchaInfo {
  final bool enabled;
  final String type;
  final Map<String, dynamic> siteConfig;
  final String? image;
  final String? ticket;
  final String? recaptchaSiteKey;
  final String? turnstileSiteKey;
  final String? capInstanceUrl;
  final String? capSiteKey;
  final String? capAssetServer;

  const CloudreveCaptchaInfo({
    required this.enabled,
    required this.type,
    required this.siteConfig,
    this.image,
    this.ticket,
    this.recaptchaSiteKey,
    this.turnstileSiteKey,
    this.capInstanceUrl,
    this.capSiteKey,
    this.capAssetServer,
  });

  bool get isImage => enabled && type == 'normal';
  bool get isWeb =>
      enabled && (type == 'recaptcha' || type == 'turnstile' || type == 'cap');
}

class MobileCaptchaService {
  MobileCaptchaService._internal();

  static final MobileCaptchaService _instance =
      MobileCaptchaService._internal();

  static MobileCaptchaService get instance => _instance;

  Future<CloudreveCaptchaInfo> load({
    required List<String> enabledKeys,
    bool defaultEnabled = true,
  }) async {
    Map<String, dynamic> config = <String, dynamic>{};

    try {
      config = await AuthService.instance.getBasicSiteConfig().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      // 配置读取失败时回退到图形验证码；图形验证码有独立官方接口。
    }

    final enabled = _readBoolFromConfig(
      config,
      enabledKeys,
      defaultValue: defaultEnabled,
    );

    if (!enabled) {
      return CloudreveCaptchaInfo(
        enabled: false,
        type: 'none',
        siteConfig: config,
      );
    }

    final type = _normalizeCaptchaType(
      _findFirstString(config, const [
        'captcha_type',
        'captchaType',
        'captchaProvider',
        'captcha_provider',
      ]),
    );

    if (type == 'recaptcha') {
      return CloudreveCaptchaInfo(
        enabled: true,
        type: type,
        siteConfig: config,
        recaptchaSiteKey: _findFirstString(config, const [
          'captcha_ReCaptchaKey',
          'captcha_recaptcha_key',
          'captcha_recaptcha_site_key',
          'recaptcha_site_key',
          'recaptchaSiteKey',
          'site_key',
          'siteKey',
        ]),
      );
    }

    if (type == 'turnstile') {
      return CloudreveCaptchaInfo(
        enabled: true,
        type: type,
        siteConfig: config,
        turnstileSiteKey: _findFirstString(config, const [
          'turnstile_site_id',
          'turnstile_site_key',
          'turnstileSiteKey',
          'captcha_turnstile_site_key',
          'captcha_TurnstileSiteKey',
          'site_key',
          'siteKey',
        ]),
      );
    }

    if (type == 'cap') {
      return CloudreveCaptchaInfo(
        enabled: true,
        type: type,
        siteConfig: config,
        capInstanceUrl: _findFirstString(config, const [
          'captcha_cap_instance_url',
          'cap_instance_url',
          'capInstanceUrl',
          'captcha_CapInstanceUrl',
          'instance_url',
          'instanceUrl',
        ]),
        capSiteKey: _findFirstString(config, const [
          'captcha_cap_site_key',
          'cap_site_key',
          'capSiteKey',
          'captcha_CapSiteKey',
          'site_key',
          'siteKey',
        ]),
        capAssetServer: _findFirstString(config, const [
          'captcha_cap_asset_server',
          'cap_asset_server',
          'capAssetServer',
          'captcha_CapAssetServer',
          'asset_server',
          'assetServer',
        ]),
      );
    }

    final captcha = await AuthService.instance.getCaptcha();
    return CloudreveCaptchaInfo(
      enabled: true,
      type: 'normal',
      siteConfig: config,
      image: captcha['image'],
      ticket: captcha['ticket'],
    );
  }

  bool _readBoolFromConfig(
    Map<String, dynamic> source,
    List<String> keys, {
    required bool defaultValue,
  }) {
    for (final key in keys) {
      final value = _findValue(source, key);
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }
    return defaultValue;
  }

  String _normalizeCaptchaType(String? rawType) {
    final value = (rawType ?? '').trim().toLowerCase();
    if (value.isEmpty) return 'normal';

    if (value == 'normal' ||
        value == 'image' ||
        value == 'graphic' ||
        value == 'graphics' ||
        value == 'captcha' ||
        value == '图形') {
      return 'normal';
    }

    if (value == 'recaptcha' ||
        value == 'recaptcha_v2' ||
        value == 'recaptchav2' ||
        value == 'google' ||
        value == 'google_recaptcha' ||
        value == 'google-recaptcha') {
      return 'recaptcha';
    }

    if (value == 'turnstile' ||
        value == 'cloudflare_turnstile' ||
        value == 'cloudflare-turnstile' ||
        value == 'cloudflare') {
      return 'turnstile';
    }

    if (value == 'cap') {
      return 'cap';
    }

    // 未识别时回退到图形验证码，避免阻断登录页。
    return 'normal';
  }

  dynamic _findValue(dynamic value, String key) {
    if (value is Map) {
      if (value.containsKey(key)) return value[key];
      for (final child in value.values) {
        final found = _findValue(child, key);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findValue(child, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _findFirstString(dynamic value, List<String> keys) {
    for (final key in keys) {
      final raw = _findValue(value, key);
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
