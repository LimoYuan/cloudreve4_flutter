/// 字符串验证器
class StringValidator {
  /// 验证邮箱
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入邮箱';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  /// 验证密码
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 6) {
      return '密码长度至少为6位';
    }
    return null;
  }

  /// 验证必填
  static String? validateRequired(String? value, {String message = '此字段不能为空'}) {
    if (value == null || value.isEmpty) {
      return message;
    }
    return null;
  }

  /// 验证昵称
  static String? validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入昵称';
    }
    if (value.length > 50) {
      return '昵称长度不能超过50个字符';
    }
    return null;
  }
}
