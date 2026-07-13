import 'package:cloudreve4_flutter/config/brand_config.dart';
import 'package:cloudreve4_flutter/mkw_packager/generated/qr_login_config.dart';
import 'package:cloudreve4_flutter/mkw_packager/generated/update_config.dart' as mkw_update;
import 'package:cloudreve4_flutter/presentation/providers/navigation_provider.dart';
import 'package:cloudreve4_flutter/router/app_router.dart';
import 'package:cloudreve4_flutter/services/app_update_service.dart';
import 'package:cloudreve4_flutter/presentation/widgets/app_update_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class _QuickFunction {
  final IconData icon;
  final String label;
  final String? route;
  final void Function(BuildContext context)? onTap;

  const _QuickFunction({
    required this.icon,
    required this.label,
    this.route,
    this.onTap,
  });
}

class QuickFunctionsSection extends StatelessWidget {
  const QuickFunctionsSection({super.key});

  static List<_QuickFunction> get _functions => [
        _QuickFunction(
          icon: LucideIcons.share2,
          label: '我的分享',
          route: RouteNames.share,
        ),
        _QuickFunction(
          icon: LucideIcons.cloud,
          label: 'WebDAV',
          route: RouteNames.webdav,
        ),
        _QuickFunction(
          icon: LucideIcons.download,
          label: '离线下载',
          route: RouteNames.remoteDownload,
        ),
        _QuickFunction(
          icon: LucideIcons.trash2,
          label: '回收站',
          route: RouteNames.recycleBin,
        ),
        if (mkwQrLoginEnabled &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS))
          _QuickFunction(
            icon: Icons.qr_code_scanner,
            label: '扫码登录电脑',
            route: RouteNames.qrLoginScan,
          ),
        _QuickFunction(
          icon: LucideIcons.refreshCw,
          label: '文件同步',
          onTap: (ctx) {
            final nav = ctx.read<NavigationProvider>();
            final isDesktop = defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS;
            final isWideScreen = MediaQuery.of(ctx).size.width >= 800;
            if (isDesktop || isWideScreen) {
              nav.setIndex(4);
            } else {
              Navigator.of(ctx).pushNamed(RouteNames.syncStatus);
            }
          },
        ),
        if (mkw_update.mkwShowUpdateEntry &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.windows))
          _QuickFunction(
            icon: LucideIcons.downloadCloud,
            label: '检查更新',
            onTap: _checkUpdate,
          ),
        _QuickFunction(
          icon: LucideIcons.settings,
          label: '设置',
          route: RouteNames.settings,
        ),
      ];

  static const double _spacing = 12;
  static const double _runSpacing = 4;
  static const double _minItemWidth = 120;

  static Future<void> _checkUpdate(BuildContext context) async {
    final isDefaultPackage = BrandConfig.packageName == 'com.limo.cloudreve4_flutter';
    final canCheck = (mkw_update.mkwOnlineUpdateEnabled && mkw_update.mkwManualUpdateEnabled)
        || (!mkw_update.mkwOnlineUpdateEnabled && isDefaultPackage);
    if (!canCheck) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('正在检查更新...')),
    );

    try {
      final result = await AppUpdateService.instance.check(force: true);
      if (!context.mounted) return;

      final update = result.update;
      if (update == null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('已是最新版本：${result.current.version} (${result.current.buildNumber})'),
          ),
        );
        return;
      }

      // GitHub 兜底：downloadUrl 是 release html_url，不能走 downloadPackage
      // （mkwOnlineUpdateEnabled == false 时第一行就 throw），直接弹对话框
      // 让用户点"打开浏览器下载"跳转。
      if (update.updateSource == AppUpdateSource.github) {
        messenger.hideCurrentSnackBar();
        await AppUpdateDialog.show(
          context,
          update: update,
          currentVersion: result.current.version,
          currentBuild: result.current.buildNumber,
        );
        return;
      }

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('发现新版本，正在后台准备更新包...')),
      );

      final packagePath = await AppUpdateService.instance.downloadPackage(update);
      if (!context.mounted) return;

      messenger.hideCurrentSnackBar();
      await AppUpdateDialog.show(
        context,
        update: update,
        currentVersion: result.current.version,
        currentBuild: result.current.buildNumber,
        preDownloadedPath: packagePath,
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('检查更新失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final functions = _functions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Icon(LucideIcons.zap, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '快捷功能',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (functions.isEmpty) return const SizedBox.shrink();

            final availableWidth = constraints.maxWidth;
            int perRow = 1;
            while (perRow < functions.length) {
              final next = perRow + 1;
              final itemWidth = (availableWidth - _spacing * (next - 1)) / next;
              if (itemWidth < _minItemWidth) break;
              perRow = next;
            }
            final itemWidth =
                (availableWidth - _spacing * (perRow - 1)) / perRow;

            return Wrap(
              spacing: _spacing,
              runSpacing: _runSpacing,
              children: functions.map((fn) {
                return SizedBox(
                  width: itemWidth,
                  child: _QuickFunctionCard(
                    icon: fn.icon,
                    label: fn.label,
                    onTap: () {
                      if (fn.onTap != null) {
                        fn.onTap!(context);
                      } else if (fn.route != null) {
                        Navigator.of(context).pushNamed(fn.route!);
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickFunctionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickFunctionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickFunctionCard> createState() => _QuickFunctionCardState();
}

class _QuickFunctionCardState extends State<_QuickFunctionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: _hovered ? colorScheme.surfaceContainerHighest : null,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        onHover: (v) => setState(() => _hovered = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _hovered ? colorScheme.primary : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
