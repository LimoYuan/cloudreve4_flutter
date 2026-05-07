import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:flutter/material.dart';
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
        final userSetting = Provider.of<UserSettingProvider>(
            context, listen: false);
        userSetting.loadCapacity();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery
        .of(context)
        .size
        .width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
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
        Card(child: Padding(
            padding: EdgeInsets.all(16), child: QuickAccessGrid())),
        SizedBox(height: 16),
        RecentActivityList(),
      ],
    );
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
