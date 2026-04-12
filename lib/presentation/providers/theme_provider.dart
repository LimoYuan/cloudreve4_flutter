import 'package:flutter/foundation.dart';
import '../../services/storage_service.dart';

/// 主题模式
enum ThemeMode {
  light,
  dark,
  system,
}

/// 主题Provider
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// 初始化
  Future<void> init() async {
    await loadThemeMode();
  }

  /// 加载主题模式
  Future<void> loadThemeMode() async {
    final savedMode = await StorageService.instance.themeMode;
    if (savedMode != null) {
      switch (savedMode) {
        case 'light':
          _themeMode = ThemeMode.light;
        case 'dark':
          _themeMode = ThemeMode.dark;
        default:
          _themeMode = ThemeMode.system;
      }
    }
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
      case ThemeMode.dark:
        modeString = 'dark';
      case ThemeMode.system:
        modeString = 'system';
    }
    await StorageService.instance.setThemeMode(modeString);
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}
