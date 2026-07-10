import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../data/models/user_model.dart';
import '../../../services/qr_login_service.dart';
import '../../../services/server_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/user_avatar.dart';

import 'package:cloudreve4_flutter/mkw_packager/generated/qr_login_config.dart';
class QrLoginScanPage extends StatefulWidget {
  const QrLoginScanPage({super.key});

  @override
  State<QrLoginScanPage> createState() => _QrLoginScanPageState();
}

class _QrLoginScanPageState extends State<QrLoginScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    if (raw == null) return;

    setState(() => _handling = true);
    await _controller.stop();

    try {
      final parsedPayload = QrLoginPayload.fromRaw(raw);
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final user = auth.user;
      final server = ServerService.instance.currentServer;
      if (user == null || user.token == null || server == null) {
        throw Exception('请先在手机端登录账号，再扫码授权 Windows 端登录');
      }

      final payload = parsedPayload.resolveForServer(server.baseUrl);
      await QrLoginService.instance.markScanned(payload);
      if (!mounted) return;

      if (!QrLoginService.isSameCloudreve(
        server.baseUrl,
        payload.cloudreveBaseUrl,
      )) {
        throw Exception('二维码所属站点与当前登录站点不一致');
      }

      final confirmed = await _showConfirmDialog(user);
      if (confirmed != true) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await QrLoginService.instance.confirmLogin(
        payload: payload,
        user: user,
        currentCloudreveBaseUrl: server.baseUrl,
      );

      if (!mounted) return;
      ToastHelper.success('已授权 Windows 端登录');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ToastHelper.failure(e.toString().replaceFirst('Exception: ', ''));
      setState(() => _handling = false);
      await _controller.start();
    }
  }

  Future<bool?> _showConfirmDialog(UserModel user) {
    final colorScheme = Theme.of(context).colorScheme;
    final email = (user.email == null || user.email!.trim().isEmpty)
        ? '未绑定邮箱'
        : user.email!.trim();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认登录电脑端？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                userId: user.id,
                email: user.email,
                displayName: user.nickname,
                radius: 34,
                avatarType: user.avatar,
              ),
              const SizedBox(height: 14),
              Text(
                user.nickname,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              const Text('是否允许该账号登录电脑端？', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认登录'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!mkwQrLoginEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('扫码登录电脑')),
        body: const Center(child: Text('扫码登录功能已关闭')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('扫码登录电脑')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.55),
              child: const SafeArea(
                bottom: false,
                child: Text(
                  '扫描 Windows 客户端上的登录二维码',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          if (_handling)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
