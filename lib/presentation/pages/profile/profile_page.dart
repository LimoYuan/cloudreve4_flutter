import 'package:cloudreve4_flutter/presentation/providers/admin_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/profile_info_card.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/quick_functions_section.dart';
import 'package:cloudreve4_flutter/presentation/pages/profile/widgets/admin_section.dart';
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
          adminProvider.loadAll();
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
