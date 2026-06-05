String parseLoginErrorMessage(String error) {
  if (error.startsWith('Exception(') || error.startsWith('AppException(')) {
    final startIdx = error.indexOf('(');
    final endIdx = error.lastIndexOf(')');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return error.substring(startIdx + 1, endIdx).trim();
    }
  }
  if (error.contains(':')) {
    final parts = error.split(':');
    if (parts.length > 1) {
      final msg = parts.sublist(1).join(':').trim();
      if (msg.isNotEmpty) return '登录失败: $msg';
    }
  }
  if (error.contains('"') && error.split('"').length >= 2) {
    final parts = error.split('"');
    if (parts.length >= 2) {
      final msg = parts[1].trim();
      if (msg.isNotEmpty && msg != 'login') return '登录失败: $msg';
    }
  }
  return error.isEmpty ? '登录失败: 未知原因' : '登录失败: $error';
}
