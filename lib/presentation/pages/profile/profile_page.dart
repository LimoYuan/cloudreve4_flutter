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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initData();
    });
  }

  Future<void> _initData() async {
    final userSetting = context.read<UserSettingProvider>();
    userSetting.loadCapacity();

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAdmin) return;

    final adminProvider = context.read<AdminProvider>();
    if (adminProvider.groups.isNotEmpty || adminProvider.users.isNotEmpty) return;

    await adminProvider.loadAll();
    if (!mounted) return;

    // 批量检查头像更新，限制并发避免阻塞主线程
    final users = adminProvider.users;
    final baseUrl = authProvider.currentServer?.baseUrl ?? '';
    final token = authProvider.token?.accessToken ?? '';
    final needCheckIds = <String>[];
    for (final user in users) {
      final userId = user.hashId ?? user.id.toString();
      if (AvatarCacheService.instance.avatarIsExist(userId)) {
        needCheckIds.add(userId);
      }
    }
    if (needCheckIds.isNotEmpty) {
      AvatarCacheService.instance.batchCheckUpdates(
        needCheckIds,
        baseUrl: baseUrl,
        token: token,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthProvider, bool>((p) => p.isAdmin);

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
