import 'package:flutter/material.dart';
import '../../../router/app_router.dart';
import '../../../services/storage_service.dart';

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
    // 初始化存储
    await StorageService.instance.init();

    // 检查登录状态
    final storage = StorageService.instance;
    final accessToken = await storage.accessToken;
    final isLoggedIn = accessToken != null && accessToken.isNotEmpty;

    if (isLoggedIn && mounted) {
      Navigator.of(context).pushReplacementNamed(RouteNames.home);
    } else if (mounted) {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
    }
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
