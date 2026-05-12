import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

/// Toast 封装组件
class ToastHelper {
  ToastHelper._();

  /// 显示成功提示
  static void success(String message) {
    _showToast(
      message,
      backgroundColor: const Color(0xFFE8F5E9),
      textColor: const Color(0xFF2E7D32),
    );
  }

  /// 显示失败提示
  static void failure(String message) {
    _showToast(
      message,
      backgroundColor: const Color(0xFFFFEBEE),
      textColor: const Color(0xFFC62828),
    );
  }

  /// 显示错误提示
  static void error(String message) {
    _showToast(
      message,
      backgroundColor: const Color(0xFFFFF3E0),
      textColor: const Color(0xFFEF6C00),
      duration: const Duration(seconds: 3),
    );
  }

  /// 显示警告提示
  static void warning(String message) {
    _showToast(
      message,
      backgroundColor: const Color(0xFFFFF8E1),
      textColor: const Color(0xFFFF8F00),
    );
  }

  /// 显示信息提示
  static void info(String message) {
    _showToast(
      message,
      backgroundColor: const Color(0xFFE3F2FD),
      textColor: const Color(0xFF1565C0),
    );
  }

  static void _showToast(
    String message, {
    required Color backgroundColor,
    required Color textColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    showToastWidget(
      _buildToast(message: message, backgroundColor: backgroundColor, textColor: textColor),
      duration: duration,
      position: ToastPosition.bottom,
    );
  }

  static Widget _buildToast({
    required String message,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: theme.textTheme.bodyMedium?.fontFamily,
          ),
        ),
      );
    });
  }

  /// 显示自定义图标提示
  static void showWithIcon({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color textColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    showToastWidget(
      _buildIconToast(
        message: message,
        icon: icon,
        iconColor: iconColor,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
      duration: duration,
      position: ToastPosition.bottom,
    );
  }

  static Widget _buildIconToast({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
