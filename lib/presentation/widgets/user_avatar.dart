import 'dart:io';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/services/avatar_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 用户头像组件
/// 1. 缓存存在 → 直接 FileImage 显示
/// 2. 缓存不存在 → 默认显示首字母 fallback，异步 getAvatar，成功后更新 UI
class UserAvatar extends StatefulWidget {
  final String userId;
  final String? email;
  final String displayName;
  final double radius;
  final String? avatarType;

  const UserAvatar({
    super.key,
    required this.userId,
    this.email,
    required this.displayName,
    this.radius = 24,
    this.avatarType,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();

  /// 清除指定用户的头像缓存（头像上传/切换后调用）
  static Future<void> evictCache(String userId) async {
    await AvatarCacheService.instance.evictCache(userId);
  }

  /// 清除所有头像缓存（登出时调用）
  static Future<void> clearAllCache() async {
    await AvatarCacheService.instance.clearAllCache();
  }
}

class _UserAvatarState extends State<UserAvatar> {
  File? _avatarFile;
  bool _loadTriggered = false;

  String get _initial {
    final name = widget.displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  void initState() {
    super.initState();
    _checkCache();
    AvatarCacheService.instance.addListener(_onServiceNotify);
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.email != widget.email) {
      _avatarFile = null;
      _loadTriggered = false;
      _checkCache();
    }
  }

  @override
  void dispose() {
    AvatarCacheService.instance.removeListener(_onServiceNotify);
    super.dispose();
  }

  void _checkCache() {
    if (widget.userId.isEmpty) return;
    final file = AvatarCacheService.instance.getCachedFile(widget.userId);
    if (file != null) {
      _avatarFile = file;
    }
  }

  void _onServiceNotify() {
    final file = AvatarCacheService.instance.getCachedFile(widget.userId);
    if (file != null && _avatarFile?.path != file.path) {
      setState(() => _avatarFile = file);
    }
  }

  Future<void> _loadIfMissing() async {
    if (_loadTriggered || widget.userId.isEmpty) return;
    _loadTriggered = true;

    final auth = context.read<AuthProvider>();
    await AvatarCacheService.instance.getAvatar(
      widget.userId,
      baseUrl: auth.currentServer?.baseUrl,
      token: auth.token?.accessToken,
      email: widget.email,
    );
    // getAvatar 成功后 notifyListeners → _onServiceNotify 更新 _avatarFile
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 有缓存文件，显示图片
    if (_avatarFile != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: FileImage(_avatarFile!),
      );
    }

    // 缓存不存在，触发异步加载
    _loadIfMissing();

    // Fallback: 首字母（默认展示，避免空白）
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: widget.radius * 0.75,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
