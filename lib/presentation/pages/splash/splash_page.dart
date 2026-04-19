import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../router/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/server_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/auth_provider.dart';

/// 启动页
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 先初始化服务器服务，获取正确的 baseUrl
    await ServerService.instance.init();

    // 根据服务器服务中的 baseUrl 设置 API 服务
    final currentServer = ServerService.instance.currentServer;
    if (currentServer != null) {
      await _setApiBaseUrl(currentServer.baseUrl);
    }

    // 初始化 API 服务
    await ApiService.instance.init();

    // 使用 AuthProvider 检查登录状态
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 初始化 AuthProvider（会自动检查登录状态）
    await authProvider.init();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(RouteNames.home);
    } else {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
    }
  }

  /// 设置 API baseUrl
  Future<void> _setApiBaseUrl(String baseUrl) async {
    final storageService = StorageService.instance;
    await storageService.setCustomBaseUrl(baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              '正在加载...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
