import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/share_link_service.dart';
import '../../services/storage_service.dart';
import '../pages/share/share_link_page.dart';

/// 全局剪贴板分享链接监听。
///
/// 行为和手机端保持一致：
/// - 应用进入主页后读取一次剪贴板。
/// - 从其他窗口切回应用时读取一次剪贴板。
/// - 检测到 Cloudreve 分享链接后弹出确认卡片。
/// - 用户关闭/忽略后记录该链接，下次不再重复弹出。
class ShareClipboardWatcher extends StatefulWidget {
  final Widget child;

  const ShareClipboardWatcher({
    super.key,
    required this.child,
  });

  @override
  State<ShareClipboardWatcher> createState() => _ShareClipboardWatcherState();
}

enum _ShareClipboardAction { open, ignore }

class _ShareClipboardWatcherState extends State<ShareClipboardWatcher>
    with WidgetsBindingObserver, WindowListener {
  static const String _ignoredKey = 'share_clipboard_ignored_fingerprint';
  static const String _lastOpenedKey = 'share_clipboard_last_opened_fingerprint';

  bool _checking = false;
  bool _dialogShowing = false;
  String? _lastPromptedFingerprint;
  DateTime? _lastCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isDesktop) {
      windowManager.addListener(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard(reason: 'startup');
    });
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard(reason: 'resumed');
    }
  }

  @override
  void onWindowFocus() {
    _checkClipboard(reason: 'window_focus');
  }

  Future<void> _checkClipboard({required String reason}) async {
    if (!mounted || _checking || _dialogShowing) return;

    final now = DateTime.now();
    final last = _lastCheckAt;
    if (last != null && now.difference(last) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastCheckAt = now;

    _checking = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      final candidate = ShareLinkService.instance.parseShareLink(text);
      if (candidate == null) return;

      final fingerprint = _fingerprint(candidate);
      if (fingerprint == _lastPromptedFingerprint) return;

      final ignored = await StorageService.instance.getString(_ignoredKey);
      if (ignored == fingerprint) return;

      final opened = await StorageService.instance.getString(_lastOpenedKey);
      if (opened == fingerprint) return;

      _lastPromptedFingerprint = fingerprint;
      await _showSharePrompt(candidate, fingerprint);
    } catch (_) {
      // 剪贴板在某些 Windows 状态下会被其他程序占用，静默忽略，等下次切回窗口再读。
    } finally {
      _checking = false;
    }
  }

  String _fingerprint(ShareLinkCandidate candidate) {
    return '${candidate.id}|${candidate.password ?? ''}';
  }

  Future<void> _showSharePrompt(
    ShareLinkCandidate candidate,
    String fingerprint,
  ) async {
    if (!mounted || _dialogShowing) return;

    _dialogShowing = true;
    final action = await showModalBottomSheet<_ShareClipboardAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (sheetContext) {
        return _ShareClipboardPrompt(candidate: candidate);
      },
    );
    _dialogShowing = false;

    if (!mounted) return;

    if (action == _ShareClipboardAction.open) {
      await StorageService.instance.setString(_lastOpenedKey, fingerprint);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => ShareLinkPage(candidate: candidate),
        ),
      );
      return;
    }

    // 用户点"忽略"、点外部区域关闭、按 Esc 关闭都视为忽略，避免同一链接反复弹窗。
    await StorageService.instance.setString(_ignoredKey, fingerprint);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ShareClipboardPrompt extends StatelessWidget {
  final ShareLinkCandidate candidate;

  const _ShareClipboardPrompt({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width >= 720 ? 520.0 : media.size.width - 32;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: colorScheme.surface,
              elevation: 18,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.link,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '检测到分享链接',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '剪贴板中有一个 Cloudreve 分享，是否立即读取？',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '忽略',
                          onPressed: () => Navigator.of(context).pop(_ShareClipboardAction.ignore),
                          icon: const Icon(LucideIcons.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.link2, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  candidate.url,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (candidate.password != null && candidate.password!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(LucideIcons.keyRound, size: 18, color: colorScheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  '提取码：${candidate.password}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(_ShareClipboardAction.ignore),
                          child: const Text('忽略'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(_ShareClipboardAction.open),
                          icon: const Icon(LucideIcons.folderOpen, size: 18),
                          label: const Text('读取分享'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
