import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用日志类
class AppLogger {
  AppLogger._();
  static Logger? _logger;
  /// 初始化日志，必须在 main 中 await
  static Future<void> init() async {
    if (_logger != null) return;

    // 1. 获取日志存储路径 (Windows: $HOME/AppData/Roaming/com.limo/cloudreve4_flutter/logs)
    final appDir = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(appDir.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final logFile = File(p.join(logDir.path, 'log.txt'));

    // 2. 配置多路输出：同时输出到控制台和文件
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80, // 稍微长一点方便文件阅读
        colors: true,   // 控制台显示颜色
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      // 使用 MultiOutput 组合多个输出端
      output: MultiOutput([
        ConsoleOutput(), // 输出到控制台
        CustomFileOutput(
          file: logFile,
        ),
      ]),
      // 生产模式下也允许打印（如果你需要的话，也可以设为 DevelopmentFilter）
      filter: ProductionFilter(),
    );
  }

  // 使用 getter 确保 logger 已初始化，防止空指针
  static Logger get _instance {
    // 如果还没执行 init()，先给一个默认的控制台 Logger，防止报错
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
    return _logger!;
  }

  /// Debug 级别日志
  static void d(String message) => _instance.d(message);

  /// Info 级别日志
  static void i(String message) =>  _instance.i(message);

  /// Warning 级别日志
  static void w(String message) =>  _instance.w(message);

  /// Error 级别日志
  static void e(String message) =>  _instance.e(message);

  /// Debug 级别日志（支持格式化）
  static void df(String message, List<Object> args) =>  _instance.d(message, error: args);

  /// Info 级别日志（支持格式化）
  static void ifn(String message, List<Object> args) => _instance.i(message, error: args);

  /// Warning 级别日志（支持格式化）
  static void wf(String message, List<Object> args) => _instance.w(message, error: args);

  /// Error 级别日志（支持格式化）
  static void ef(String message, List<Object> args) => _instance.e(message, error: args);
}

/// 定义一个简单的自定义 FileOutput，防止 Logger 自带版本不支持追加
class CustomFileOutput extends LogOutput {
  final File file;
  CustomFileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      // 过滤掉 ANSI 颜色代码，防止 log.txt 乱码
      final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
      file.writeAsStringSync('$cleanLine\n', mode: FileMode.writeOnlyAppend);
    }
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
