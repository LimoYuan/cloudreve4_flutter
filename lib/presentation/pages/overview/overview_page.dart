import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'widgets/storage_usage_card.dart';
import 'widgets/quick_access_grid.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/search_entry_card.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final userSetting = Provider.of<UserSettingProvider>(context, listen: false);
        userSetting.loadCapacity();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.menu),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(LucideIcons.share2),
                  title: Text('我的分享'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'webdav',
                child: ListTile(
                  leading: Icon(LucideIcons.cloud),
                  title: Text('WebDAV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'remote_download',
                child: ListTile(
                  leading: Icon(LucideIcons.download),
                  title: Text('离线下载'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'recycle_bin',
                child: ListTile(
                  leading: Icon(LucideIcons.trash2),
                  title: Text('回收站'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(LucideIcons.settings),
                  title: Text('设置'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
      ),
    );
  }

  /// 宽屏：存储+快捷入口左右并排
  Widget _buildWideLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SearchEntryCard(),
        SizedBox(height: 16),
        _WideStorageAndShortcuts(),
        SizedBox(height: 16),
        RecentActivityList(),
      ],
    );
  }

  /// 窄屏：上下堆叠
  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SearchEntryCard(),
        SizedBox(height: 16),
        StorageUsageCard(),
        SizedBox(height: 16),
        Card(child: Padding(padding: EdgeInsets.all(16), child: QuickAccessGrid())),
        SizedBox(height: 16),
        RecentActivityList(),
      ],
    );
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'share':
        Navigator.of(context).pushNamed(RouteNames.share);
      case 'webdav':
        Navigator.of(context).pushNamed(RouteNames.webdav);
      case 'remote_download':
        Navigator.of(context).pushNamed(RouteNames.remoteDownload);
      case 'recycle_bin':
        Navigator.of(context).pushNamed(RouteNames.recycleBin);
      case 'settings':
        Navigator.of(context).pushNamed(RouteNames.settings);
    }
  }
}

/// 宽屏端：左侧存储卡片 + 右侧快捷入口胶囊
class _WideStorageAndShortcuts extends StatelessWidget {
  const _WideStorageAndShortcuts();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 5, child: StorageUsageCard()),
          SizedBox(width: 16),
          Expanded(
            flex: 7,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: QuickAccessGrid(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
