import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

/// 主题模式
enum AppThemeMode {
  light,
  dark,
  system,
}

/// 主题Provider - 管理主题模式和主题色
class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  Color _seedColor = const Color(0xFF3B82F6);

  static const Color lightScaffoldBg = Color(0xFFF8FAFC);
  static const Color darkScaffoldBg = Color(0xFF0F172A);

  AppThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get isDark => _themeMode == AppThemeMode.dark;

  /// 初始化
  Future<void> init() async {
    await Future.wait([
      loadThemeMode(),
      loadSeedColor(),
    ]);
  }

  /// 加载主题模式
  Future<void> loadThemeMode() async {
    final savedMode = await StorageService.instance.themeMode;
    if (savedMode != null) {
      switch (savedMode) {
        case 'light':
          _themeMode = AppThemeMode.light;
        case 'dark':
          _themeMode = AppThemeMode.dark;
        default:
          _themeMode = AppThemeMode.system;
      }
    }
    notifyListeners();
  }

  /// 加载主题色
  Future<void> loadSeedColor() async {
    final saved = await StorageService.instance.getString('theme_seed_color');
    if (saved != null && saved.isNotEmpty) {
      final color = _colorFromHex(saved);
      if (color != null) {
        _seedColor = color;
        notifyListeners();
      }
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    String modeString;
    switch (mode) {
      case AppThemeMode.light:
        modeString = 'light';
      case AppThemeMode.dark:
        modeString = 'dark';
      case AppThemeMode.system:
        modeString = 'system';
    }
    await StorageService.instance.setThemeMode(modeString);
  }

  /// 设置主题色
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    await StorageService.instance.setString('theme_seed_color', _colorToHex(color));
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    final newMode = isDark ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// 构建亮色主题
  ThemeData buildLightTheme() {
    return _buildTheme(Brightness.light);
  }

  /// 构建暗色主题
  ThemeData buildDarkTheme() {
    return _buildTheme(Brightness.dark);
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    final bodyColor = isLight ? Colors.black87 : Colors.white;
    final displayColor = isLight ? Colors.black87 : Colors.white;

    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    var textTheme = baseTextTheme.apply(
      bodyColor: bodyColor,
      displayColor: displayColor,
      fontFamily: _getPlatformFont(),
    );

    if (_getPlatformFont() == 'NotoSansSC') {
      textTheme = textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        bodySmall: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      );
    }

    return ThemeData(
      textTheme: textTheme,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? lightScaffoldBg : darkScaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight
            ? lightScaffoldBg.withValues(alpha: 0.85)
            : darkScaffoldBg.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        foregroundColor: isLight ? Colors.black87 : Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        color: isLight ? Colors.white : const Color(0xFF1E293B),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isLight
            ? lightScaffoldBg.withValues(alpha: 0.9)
            : darkScaffoldBg.withValues(alpha: 0.9),
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: isLight
            ? lightScaffoldBg
            : darkScaffoldBg,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
    );
  }

  /// Color → hex string (不含alpha)
  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// hex string → Color
  static Color? _colorFromHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return null;
  }

  String? _getPlatformFont() {
    if (Platform.isWindows || Platform.isLinux) return 'NotoSansSC';
    if (Platform.isMacOS) return 'PingFang SC';
    return null;
  }
}
