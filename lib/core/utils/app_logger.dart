import 'package:logger/logger.dart';

/// 应用日志类
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    filter: ProductionFilter(),
  );

  /// Debug 级别日志
  static void d(String message) {
    _logger.d(message);
  }

  /// Info 级别日志
  static void i(String message) {
    _logger.i(message);
  }

  /// Warning 级别日志
  static void w(String message) {
    _logger.w(message);
  }

  /// Error 级别日志
  static void e(String message) {
    _logger.e(message);
  }

  /// Debug 级别日志（支持格式化）
  static void df(String message, List<Object> args) {
    _logger.d(message, error: args);
  }

  /// Info 级别日志（支持格式化）
  static void ifn(String message, List<Object> args) {
    _logger.i(message, error: args);
  }

  /// Warning 级别日志（支持格式化）
  static void wf(String message, List<Object> args) {
    _logger.w(message, error: args);
  }

  /// Error 级别日志（支持格式化）
  static void ef(String message, List<Object> args) {
    _logger.e(message, error: args);
  }
}

/// 日志帮助类
/// 提供一个全局的静态日志实例
class Log {
  static void d(String message) => AppLogger.d(message);
  static void i(String message) => AppLogger.i(message);
  static void w(String message) => AppLogger.w(message);
  static void e(String message) => AppLogger.e(message);
  static void df(String message, List<Object> args) => AppLogger.df(message, args);
  static void ifn(String message, List<Object> args) => AppLogger.ifn(message, args);
  static void wf(String message, List<Object> args) => AppLogger.wf(message, args);
  static void ef(String message, List<Object> args) => AppLogger.ef(message, args);
}
