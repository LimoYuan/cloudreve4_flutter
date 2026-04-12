import 'package:intl/intl.dart';

/// 日期工具类
class DateUtils {
  /// 格式化日期
  static String formatDate(DateTime? date, {String pattern = 'yyyy-MM-dd'}) {
    if (date == null) return '-';
    return DateFormat(pattern).format(date);
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime? dateTime) {
    return formatDate(dateTime, pattern: 'yyyy-MM-dd HH:mm:ss');
  }

  /// 格式化时间
  static String formatTime(DateTime? dateTime) {
    return formatDate(dateTime, pattern: 'HH:mm:ss');
  }

  /// 格式化文件大小
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes < 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// 获取相对时间描述
  static String getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else {
      return '${(difference.inDays / 365).floor()}年前';
    }
  }

  /// 判断是否为今天
  static bool isToday(DateTime? dateTime) {
    if (dateTime == null) return false;
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// 判断是否为昨天
  static bool isYesterday(DateTime? dateTime) {
    if (dateTime == null) return false;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }
}
