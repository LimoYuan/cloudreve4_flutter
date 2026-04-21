import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// 侧边栏组件
class HomeDrawer extends StatelessWidget {
  final String currentPath;
  final VoidCallback onMyFiles;
  final VoidCallback onMyShares;
  final VoidCallback onRecycleBin;
  final VoidCallback onWebdav;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const HomeDrawer({
    super.key,
    required this.currentPath,
    required this.onMyFiles,
    required this.onMyShares,
    required this.onRecycleBin,
    required this.onWebdav,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(authProvider.user?.nickname ?? '用户'),
            accountEmail: Text(authProvider.user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              child: Text(
                (authProvider.user?.nickname ?? '').isNotEmpty
                    ? authProvider.user!.nickname[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('我的文件'),
            selected: currentPath == '/',
            onTap: () {
              onMyFiles();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('我的分享'),
            onTap: () {
              Navigator.of(context).pop();
              onMyShares();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('WebDAV'),
            onTap: () {
              Navigator.of(context).pop();
              onWebdav();
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('回收站'),
            onTap: () {
              Navigator.of(context).pop();
              onRecycleBin();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              onSettings();
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () {
              Navigator.of(context).pop();
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}
