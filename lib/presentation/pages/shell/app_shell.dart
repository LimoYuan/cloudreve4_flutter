import 'package:cloudreve4_flutter/presentation/providers/admin_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/sync_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/announcement_dialog.dart';
import 'package:cloudreve4_flutter/presentation/widgets/gesture_handler_mixin.dart';
import 'package:cloudreve4_flutter/presentation/widgets/glassmorphism_container.dart';
import 'package:cloudreve4_flutter/presentation/widgets/share_clipboard_watcher.dart';
import 'package:cloudreve4_flutter/presentation/widgets/user_avatar.dart';
import 'package:cloudreve4_flutter/services/announcement_service.dart';
import 'package:cloudreve4_flutter/services/dialog_queue_service.dart';
import 'package:cloudreve4_flutter/services/floating_upload_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../router/app_router.dart';
import '../files/files_page.dart';
import '../overview/overview_page.dart';
import '../sync/sync_page.dart';
import '../tasks/tasks_page.dart';
import '../store/store_page.dart';
import '../profile/profile_page.dart';

/// 桌面端侧边栏入场动画：从左侧滑入 + 淡入
class _DesktopSidebarIntro extends StatefulWidget {
  final Widget child;

  const _DesktopSidebarIntro({required this.child});

  @override
  State<_DesktopSidebarIntro> createState() => _DesktopSidebarIntroState();
}

class _DesktopSidebarIntroState extends State<_DesktopSidebarIntro> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 40), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(-0.72, 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// NavigationRail 图标交错入场动画：缩放弹入 + 淡入
class _RailIconIntro extends StatefulWidget {
  final Widget child;
  final int order;

  const _RailIconIntro({required this.child, required this.order});

  @override
  State<_RailIconIntro> createState() => _RailIconIntroState();
}

class _RailIconIntroState extends State<_RailIconIntro> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 250 + widget.order * 58);
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _visible ? 1.0 : 0.18,
      duration: const Duration(milliseconds: 560),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ShellPageSlot extends StatefulWidget {
  final Widget child;

  const _ShellPageSlot({required this.child});

  @override
  State<_ShellPageSlot> createState() => _ShellPageSlotState();
}

class _ShellPageSlotState extends State<_ShellPageSlot>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Tab 切换过渡动画：监听 index 变化，每次切换时对内容做一次淡入 + 轻微方向性滑入。
///
/// 包裹在 IndexedStack 外层，不破坏内部 AutomaticKeepAliveClient 的状态保留机制。
class _TabSwitchTransition extends StatefulWidget {
  final int index;
  final Widget child;

  const _TabSwitchTransition({required this.index, required this.child});

  @override
  State<_TabSwitchTransition> createState() => _TabSwitchTransitionState();
}

class _TabSwitchTransitionState extends State<_TabSwitchTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _TabSwitchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      final delta = widget.index - _lastIndex;
      _lastIndex = widget.index;
      _slide = Tween<Offset>(
        begin: Offset(delta >= 0 ? 0.04 : -0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with GestureHandlerMixin, TickerProviderStateMixin {
  final Set<int> _visitedPageIndexes = <int>{0};
  late AnimationController _syncSpinController;
  String? _lastUserId;
  bool _cachedShowSyncTab = false;

  /// 同步 tab 在桌面平台显示，Android 平板（宽屏）也显示
  static bool _shouldShowSyncTab(double screenWidth) {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    return screenWidth >= 800;
  }

  /// 根据平台返回页面列表（控制 IndexedStack 和 index 映射）
  List<Widget> _pages(bool showSyncTab) => showSyncTab
      ? [const OverviewPage(), const FilesPage(), const TasksPage(), const StorePage(), const SyncPage(), const ProfilePage()]
      : [const OverviewPage(), const FilesPage(), const TasksPage(), const StorePage(), const ProfilePage()];

  @override
  void initState() {
    super.initState();
    _syncSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPostLoginAnnouncement();
      _lastUserId = context.read<AuthProvider>().user?.id;
    });
  }

  @override
  void dispose() {
    _syncSpinController.dispose();
    super.dispose();
  }

  /// 切换 tab 时刷新对应页面数据
  void _handleTabSelected(int index) {
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    nav.setIndex(index);

    final userSetting = Provider.of<UserSettingProvider>(context, listen: false);
    if (index == 0) {
      // 概览页
      userSetting.loadCapacity();
    } else if (index == _pages(_cachedShowSyncTab).length - 1) {
      // "我的"页面
      userSetting.loadCapacity();
    }
  }

  /// 检测用户身份变化（账号切换后重置所有 Provider 状态）
  void _checkUserChange() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.id;
    if (_lastUserId != null && currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      // 必须延迟到 build 完成后执行，否则在 build 阶段触发 notifyListeners 导致死循环
      Future.microtask(() {
        if (mounted) _resetProvidersOnUserChange();
      });
    } else if (_lastUserId == null && currentUserId != null) {
      _lastUserId = currentUserId;
    }
  }

  /// 用户切换后重置所有用户相关 Provider
  void _resetProvidersOnUserChange() {
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);
    final userSetting = Provider.of<UserSettingProvider>(context, listen: false);
    final admin = Provider.of<AdminProvider>(context, listen: false);
    final sync = Provider.of<SyncProvider>(context, listen: false);

    fileManager.clearFiles();
    userSetting.clear();
    admin.clear();

    if (sync.engineInitialized) {
      sync.resetSync();
    }

    // 重置导航到概览页并刷新数据
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    nav.setIndex(0);
    userSetting.loadCapacity();
  }

  Future<void> _showPostLoginAnnouncement() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;

    try {
      final service = AnnouncementService.instance;
      final announcement = await service.getChangedSiteNotice();
      if (!mounted || announcement == null) return;

      await DialogQueueService.instance.enqueue<void>(() async {
        if (!mounted) return;

        await AnnouncementDialog.show(
          context,
          title: announcement.title,
          html: announcement.html,
          baseUrl: announcement.baseUrl,
        );

        await service.markDismissed(announcement);
      });
    } catch (_) {
      // 公告检查失败不能影响主界面
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    _cachedShowSyncTab = _shouldShowSyncTab(screenWidth);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final navProvider = Provider.of<NavigationProvider>(context, listen: false);
          final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

          if (navProvider.currentIndex == 1 && fileManager.currentPath != '/') {
            await fileManager.goBack();
          } else if (navProvider.currentIndex != 0 && navProvider.currentIndex != 1) {
            navProvider.setIndex(0);
          } else {
            await checkExitApp(context);
          }
        }
      },
      child: FloatingUploadBridge(
        child: ShareClipboardWatcher(
          child: Consumer2<AuthProvider, NavigationProvider>(
            builder: (context, auth, navProvider, _) {
              _checkUserChange();
              if (isDesktop) {
                return _buildDesktopLayout(context, navProvider);
              }
              return _buildMobileLayout(context, navProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent(BuildContext context, int currentIndex) {
    _visitedPageIndexes.add(currentIndex);
    final pages = _pages(_cachedShowSyncTab);

    return RepaintBoundary(
      child: _TabSwitchTransition(
        index: currentIndex,
        child: IndexedStack(
          index: currentIndex,
          children: List.generate(pages.length, (index) {
            if (!_visitedPageIndexes.contains(index)) {
              return const SizedBox.shrink();
            }
            return _ShellPageSlot(child: pages[index]);
          }),
        ),
      ),
    );
  }

  Widget _buildSyncIcon({required bool isSelected, required double size}) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) {
        final hasWorkers = sync.activeWorkerCount > 0;

        // 只在状态切换时启停动画，避免每次 rebuild 重启造成抖动
        if (hasWorkers && !_syncSpinController.isAnimating) {
          _syncSpinController.repeat();
        } else if (!hasWorkers && _syncSpinController.isAnimating) {
          _syncSpinController.stop();
          _syncSpinController.value = 0;
        }

        final icon = Icon(
          LucideIcons.refreshCw,
          size: size,
          weight: isSelected ? 700 : 400,
        );

        if (hasWorkers) {
          return ListenableBuilder(
            listenable: _syncSpinController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _syncSpinController.value * 2 * 3.14159265,
                child: child,
              );
            },
            child: icon,
          );
        }
        return icon;
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, NavigationProvider navProvider) {
    return Scaffold(
      body: _buildPageContent(context, navProvider.currentIndex),
      bottomNavigationBar: GlassmorphismContainer(
        borderRadius: 0,
        child: Consumer2<UploadManagerProvider, DownloadManagerProvider>(
          builder: (context, uploadManager, downloadManager, _) {
            final activeCount = uploadManager.activeTasks.length + downloadManager.downloadingCount;

            return NavigationBar(
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: navProvider.currentIndex,
              onDestinationSelected: _handleTabSelected,
              destinations: [
                const NavigationDestination(
                  icon: Icon(LucideIcons.layoutDashboard),
                  selectedIcon: Icon(LucideIcons.layoutDashboard, weight: 700),
                  label: '概览',
                ),
                const NavigationDestination(
                  icon: Icon(LucideIcons.folder),
                  selectedIcon: Icon(LucideIcons.folder, weight: 700),
                  label: '文件',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount'),
                    child: const Icon(LucideIcons.listChecks),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: activeCount > 0,
                    label: Text('$activeCount'),
                    child: const Icon(LucideIcons.listChecks, weight: 700),
                  ),
                  label: '任务',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: '商店',
                ),
                if (_cachedShowSyncTab)
                  NavigationDestination(
                    icon: Consumer<SyncProvider>(
                      builder: (context, sync, _) {
                        final count = sync.activeWorkerCount;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: _buildSyncIcon(isSelected: false, size: 24),
                        );
                      },
                    ),
                    selectedIcon: Consumer<SyncProvider>(
                      builder: (context, sync, _) {
                        final count = sync.activeWorkerCount;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: _buildSyncIcon(isSelected: true, size: 24),
                        );
                      },
                    ),
                    label: '同步',
                  ),
                const NavigationDestination(
                  icon: Icon(LucideIcons.user),
                  selectedIcon: Icon(LucideIcons.user, weight: 700),
                  label: '我的',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, NavigationProvider navProvider) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final displayName = user?.nickname ?? '用户';

    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebarIntro(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return NavigationRail(
              selectedIndex: navProvider.currentIndex,
              onDestinationSelected: _handleTabSelected,
              labelType: NavigationRailLabelType.none,
              leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTap: () => navProvider.setIndex(_pages(_cachedShowSyncTab).length - 1),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: navProvider.currentIndex == _pages(_cachedShowSyncTab).length - 1
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2.5,
                          )
                        : null,
                  ),
                  child: UserAvatar(
                    userId: user?.id ?? '',
                    email: user?.email,
                    displayName: displayName,
                    radius: 20,
                  ),
                ),
              ),
            ),
            destinations: [
              NavigationRailDestination(
                icon: _RailIconIntro(order: 0, child: const Icon(LucideIcons.layoutDashboard)),
                selectedIcon: _RailIconIntro(order: 0, child: const Icon(LucideIcons.layoutDashboard, weight: 700)),
                label: const Text('概览'),
              ),
              NavigationRailDestination(
                icon: _RailIconIntro(order: 1, child: const Icon(LucideIcons.folder)),
                selectedIcon: _RailIconIntro(order: 1, child: const Icon(LucideIcons.folder, weight: 700)),
                label: const Text('文件'),
              ),
              NavigationRailDestination(
                icon: _RailIconIntro(
                  order: 2,
                  child: Consumer2<UploadManagerProvider, DownloadManagerProvider>(
                    builder: (context, uploadManager, downloadManager, _) {
                      final activeCount = uploadManager.activeTasks.length + downloadManager.downloadingCount;
                      return Badge(
                        isLabelVisible: activeCount > 0,
                        label: Text('$activeCount'),
                        child: const Icon(LucideIcons.listChecks),
                      );
                    },
                  ),
                ),
                selectedIcon: _RailIconIntro(order: 2, child: const Icon(LucideIcons.listChecks, weight: 700)),
                label: const Text('任务'),
              ),
              NavigationRailDestination(
                icon: _RailIconIntro(order: 3, child: const Icon(Icons.storefront_outlined)),
                selectedIcon: _RailIconIntro(order: 3, child: const Icon(Icons.storefront)),
                label: const Text('商店'),
              ),
              if (_cachedShowSyncTab)
                NavigationRailDestination(
                  icon: _RailIconIntro(
                    order: 4,
                    child: Consumer<SyncProvider>(
                      builder: (context, sync, _) {
                        final count = sync.activeWorkerCount;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: _buildSyncIcon(isSelected: false, size: 24),
                        );
                      },
                    ),
                  ),
                  selectedIcon: _RailIconIntro(
                    order: 4,
                    child: Consumer<SyncProvider>(
                      builder: (context, sync, _) {
                        final count = sync.activeWorkerCount;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: _buildSyncIcon(isSelected: true, size: 24),
                        );
                      },
                    ),
                  ),
                  label: const Text('同步'),
                ),
              NavigationRailDestination(
                icon: _RailIconIntro(order: _cachedShowSyncTab ? 5 : 4, child: const Icon(LucideIcons.user)),
                selectedIcon: _RailIconIntro(order: _cachedShowSyncTab ? 5 : 4, child: const Icon(LucideIcons.user, weight: 700)),
                label: const Text('我的'),
              ),
            ],
            trailing: Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final items = [
                    const Divider(indent: 12, endIndent: 12),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.share2,
                      label: '我的分享',
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.share),
                    ),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.cloud,
                      label: 'WebDAV',
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.webdav),
                    ),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.download,
                      label: '离线下载',
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.remoteDownload),
                    ),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.trash2,
                      label: '回收站',
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.recycleBin),
                    ),
                    const Divider(indent: 12, endIndent: 12),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.settings,
                      label: '设置',
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.settings),
                    ),
                    _buildSecondaryNavItem(
                      context,
                      icon: LucideIcons.logOut,
                      label: '退出登录',
                      onTap: () => _handleLogout(context),
                    ),
                    const SizedBox(height: 12),
                  ];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: items,
                  );
                },
              ),
            ),
              );
              },
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildPageContent(context, navProvider.currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Icon(icon, size: 22, color: theme.hintColor),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fileManager = Provider.of<FileManagerProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      fileManager.clearFiles();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
      }
    }
  }
}
