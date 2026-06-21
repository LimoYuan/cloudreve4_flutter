import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/services/avatar_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../router/app_router.dart';
import 'widgets/storage_usage_card.dart';
import 'widgets/quick_access_grid.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/search_entry_card.dart';

/// 入场动画包装：交错淡入 + 缩放 + 上滑。
/// 监听 NavigationProvider，切回概览页时自动重播。
class _OverviewEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _OverviewEntrance({required this.child, this.delayMs = 0});

  @override
  State<_OverviewEntrance> createState() => _OverviewEntranceState();
}

class _OverviewEntranceState extends State<_OverviewEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<Offset> _slide;
  int _lastTabIndex = 0;
  bool _firstBuild = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replay() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = context.watch<NavigationProvider>().currentIndex;

    if (!_firstBuild && currentTab == 0 && _lastTabIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replay();
      });
    }
    _firstBuild = false;
    _lastTabIndex = currentTab;

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  bool get _showQrScanEntry =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        final userSetting = Provider.of<UserSettingProvider>(
          context,
          listen: false,
        );
        userSetting.loadCapacity();

        // 初始化/更新当前用户头像
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final userId = auth.user?.id ?? '';
        if (userId.isNotEmpty) {
          final service = AvatarCacheService.instance;
          if (service.avatarIsExist(userId)) {
            service.avatarIsUpdated(
              userId,
              auth.currentServer?.baseUrl ?? '',
              auth.token?.accessToken ?? '',
            );
          } else {
            service.getAvatar(
              userId,
              baseUrl: auth.currentServer?.baseUrl,
              token: auth.token?.accessToken,
              email: auth.user?.email,
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('概览'),
        centerTitle: true,
        actions: _showQrScanEntry
            ? [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: '扫码登录电脑',
                  onPressed: () {
                    Navigator.of(context).pushNamed(RouteNames.qrLoginScan);
                  },
                ),
              ]
            : null,
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
      children: [
        _OverviewEntrance(delayMs: 40, child: const SearchEntryCard()),
        const SizedBox(height: 16),
        _OverviewEntrance(
          delayMs: 110,
          child: const _WideStorageAndShortcuts(),
        ),
        const SizedBox(height: 16),
        _OverviewEntrance(delayMs: 180, child: const RecentActivityList()),
      ],
    );
  }

  /// 窄屏：上下堆叠
  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OverviewEntrance(delayMs: 40, child: const SearchEntryCard()),
        const SizedBox(height: 16),
        _OverviewEntrance(delayMs: 110, child: const StorageUsageCard()),
        const SizedBox(height: 16),
        _OverviewEntrance(
          delayMs: 180,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QuickAccessGrid(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _OverviewEntrance(delayMs: 260, child: const RecentActivityList()),
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
                child: QuickAccessGrid(fillHeight: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
