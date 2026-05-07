import 'package:animations/animations.dart';
import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/download_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/file_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/upload_manager_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/gesture_handler_mixin.dart';
import 'package:cloudreve4_flutter/presentation/widgets/glassmorphism_container.dart';
import 'package:cloudreve4_flutter/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../router/app_router.dart';
import '../files/files_page.dart';
import '../overview/overview_page.dart';
import '../tasks/tasks_page.dart';
import '../profile/profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with GestureHandlerMixin {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;

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
      child: Consumer<NavigationProvider>(
        builder: (context, navProvider, _) {
          if (isDesktop) {
            return _buildDesktopLayout(context, navProvider);
          }
          return _buildMobileLayout(context, navProvider);
        },
      ),
    );
  }

  Widget _buildPageContent(BuildContext context, int currentIndex) {
    const pages = [
      OverviewPage(),
      FilesPage(),
      TasksPage(),
      ProfilePage(),
    ];

    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation, secondaryAnimation) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey(currentIndex),
        child: pages[currentIndex],
      ),
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
              selectedIndex: navProvider.currentIndex,
              onDestinationSelected: (i) => navProvider.setIndex(i),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final displayName = user?.nickname ?? '用户';

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navProvider.currentIndex,
            onDestinationSelected: (i) => navProvider.setIndex(i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTap: () => navProvider.setIndex(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: navProvider.currentIndex == 3
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
              const NavigationRailDestination(
                icon: Icon(LucideIcons.layoutDashboard),
                selectedIcon: Icon(LucideIcons.layoutDashboard, weight: 700),
                label: Text('概览'),
              ),
              const NavigationRailDestination(
                icon: Icon(LucideIcons.folder),
                selectedIcon: Icon(LucideIcons.folder, weight: 700),
                label: Text('文件'),
              ),
              NavigationRailDestination(
                icon: Consumer2<UploadManagerProvider, DownloadManagerProvider>(
                  builder: (context, uploadManager, downloadManager, _) {
                    final activeCount = uploadManager.activeTasks.length + downloadManager.downloadingCount;
                    return Badge(
                      isLabelVisible: activeCount > 0,
                      label: Text('$activeCount'),
                      child: const Icon(LucideIcons.listChecks),
                    );
                  },
                ),
                selectedIcon: const Icon(LucideIcons.listChecks, weight: 700),
                label: const Text('任务'),
              ),
              const NavigationRailDestination(
                icon: Icon(LucideIcons.user),
                selectedIcon: Icon(LucideIcons.user, weight: 700),
                label: Text('我的'),
              ),
            ],
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                ],
              ),
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
