import 'package:cloudreve4_flutter/presentation/providers/admin_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/profile_info_card.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/quick_functions_section.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/admin_section.dart';
import 'package:cloudreve4_flutter/services/avatar_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// "我的"页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final userSetting = context.read<UserSettingProvider>();
      userSetting.loadCapacity();

      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAdmin) {
        final adminProvider = context.read<AdminProvider>();
        if (adminProvider.groups.isEmpty && adminProvider.users.isEmpty) {
          adminProvider.loadAll().then((_) {
            if (!mounted) return;
            // 加载完用户列表后，检查管理员用户的头像是否需要更新
            final users = adminProvider.users;
            final baseUrl = authProvider.currentServer?.baseUrl ?? '';
            final token = authProvider.token?.accessToken ?? '';
            for (final user in users) {
              final userId = user.hashId ?? user.id.toString();
              if (AvatarCacheService.instance.avatarIsExist(userId)) {
                AvatarCacheService.instance.avatarIsUpdated(userId, baseUrl, token);
              }
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileInfoCard(),
            const SizedBox(height: 16),
            const QuickFunctionsSection(),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              const AdminSection(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
