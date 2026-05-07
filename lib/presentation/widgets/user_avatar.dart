import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudreve4_flutter/config/api_config.dart';
import 'package:cloudreve4_flutter/core/utils/avatar_utils.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 用户头像组件
/// 优先加载服务器头像，失败后尝试 Gravatar，再失败显示首字母
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
}

class _UserAvatarState extends State<UserAvatar> {
  String? _serverAvatarUrl;
  String? _gravatarUrl;
  bool _serverAvatarFailed = false;
  bool _gravatarFailed = false;

  @override
  void initState() {
    super.initState();
    _initUrls();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.email != widget.email) {
      _serverAvatarFailed = false;
      _gravatarFailed = false;
      _initUrls();
    }
  }

  Future<void> _initUrls() async {
    final baseUrl = await ApiConfig.baseUrl;
    _serverAvatarUrl = AvatarUtils.getServerAvatarUrl(baseUrl, widget.userId);

    if (widget.email != null && widget.email!.isNotEmpty) {
      _gravatarUrl = await AvatarUtils.getGravatarUrl(widget.email!, size: (widget.radius * 4).toInt());
    }

    if (mounted) setState(() {});
  }

  String get _initial {
    final name = widget.displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 1. 尝试服务器头像
    if (!_serverAvatarFailed && _serverAvatarUrl != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: CachedNetworkImageProvider(
          _serverAvatarUrl!,
          headers: {
            'Authorization': 'Bearer ${context.read<AuthProvider>().token?.accessToken ?? ''}',
          },
        ),
        onBackgroundImageError: (_, _) {
          if (!_serverAvatarFailed) {
            setState(() => _serverAvatarFailed = true);
          }
        },
        child: _serverAvatarFailed ? _buildFallback(colorScheme) : null,
      );
    }

    // 2. 尝试 Gravatar
    if (!_gravatarFailed && _gravatarUrl != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: CachedNetworkImageProvider(_gravatarUrl!),
        onBackgroundImageError: (_, _) {
          if (!_gravatarFailed) {
            setState(() => _gravatarFailed = true);
          }
        },
        child: _gravatarFailed ? _buildFallback(colorScheme) : null,
      );
    }

    // 3. Fallback: 首字母
    return _buildFallback(colorScheme);
  }

  Widget _buildFallback(ColorScheme colorScheme) {
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
