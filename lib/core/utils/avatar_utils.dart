import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloudreve4_flutter/services/storage_service.dart';
import 'package:cloudreve4_flutter/core/constants/storage_keys.dart';

/// 头像相关工具
class AvatarUtils {
  AvatarUtils._();

  /// 获取 Gravatar URL（异步，因为需要读取镜像配置）
  static Future<String> getGravatarUrl(String email, {int size = 200}) async {
    final cleanEmail = email.trim().toLowerCase();
    final hash = md5.convert(utf8.encode(cleanEmail)).toString();
    final mirror = await getGravatarMirror();
    final base = mirror ?? 'https://www.gravatar.com';
    return '$base/avatar/$hash?s=$size&d=identicon';
  }

  /// 获取服务器头像 URL
  static String getServerAvatarUrl(String baseUrl, String userId) {
    return '$baseUrl/user/avatar/$userId';
  }

  /// 获取 Gravatar 镜像配置
  static Future<String?> getGravatarMirror() async {
    final enabled = await StorageService.instance
            .getBool(StorageKeys.gravatarMirrorEnabled) ??
        true;
    if (!enabled) return null;
    return await StorageService.instance
            .getString(StorageKeys.gravatarMirrorUrl) ??
        'https://weavatar.com';
  }

  /// 设置 Gravatar 镜像启用状态
  static Future<void> setGravatarMirrorEnabled(bool enabled) async {
    await StorageService.instance
        .setBool(StorageKeys.gravatarMirrorEnabled, enabled);
  }

  /// 设置 Gravatar 镜像地址
  static Future<void> setGravatarMirrorUrl(String? url) async {
    await StorageService.instance
        .setString(StorageKeys.gravatarMirrorUrl, url);
  }
}
