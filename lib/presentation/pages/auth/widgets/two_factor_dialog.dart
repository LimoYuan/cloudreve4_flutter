import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../widgets/toast_helper.dart';

class TwoFactorDialog extends StatefulWidget {
  final String sessionId;
  final String email;
  final String password;
  final bool rememberMe;

  const TwoFactorDialog({
    super.key,
    required this.sessionId,
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOut,
      ),
    );
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final code = _controller.text.trim();
    if (code.length == 6 && !_isSubmitting) {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final code = _controller.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      _onVerifyFailed('请输入6位数字验证码');
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    try {
      final success = await authProvider
          .twoFactorLogin(
            otp: code,
            sessionId: widget.sessionId,
            email: widget.email,
            password: widget.password,
            rememberMe: widget.rememberMe,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('请求超时，请稍后重试'),
          );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        _onVerifyFailed(authProvider.errorMessage ?? '验证码错误');
      }
    } catch (e) {
      if (!mounted) return;
      _onVerifyFailed(_parse2FAError(e.toString()));
    }
  }

  void _onVerifyFailed(String message) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _controller.clear();
    _focusNode.requestFocus();
    _shakeController.forward(from: 0);
    ToastHelper.failure(message);
  }

  String _parse2FAError(String error) {
    final value = error.trim();
    if (value.isEmpty) return '验证码错误';

    for (final prefix in const ['Exception: ', 'Exception:']) {
      if (value.startsWith(prefix)) {
        return value.substring(prefix.length).trim();
      }
    }

    if (value.startsWith('Exception(') || value.startsWith('AppException(')) {
      final startIdx = value.indexOf('(');
      final endIdx = value.lastIndexOf(')');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        return value.substring(startIdx + 1, endIdx).trim();
      }
    }

    if (value.contains('code: 401') || value.contains('code: 403')) {
      return '两步验证会话已失效，请重新登录';
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('两步验证'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '请输入身份验证器中的6位数字验证码',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                enabled: !_isSubmitting,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('验证'),
          ),
        ],
      ),
    );
  }
}
