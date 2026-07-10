import '../../../../core/utils/user_friendly_error.dart';

String parseLoginErrorMessage(String error) {
  return UserFriendlyError.fromText(
    error,
    action: 'login',
    fallback: '登录失败，请检查账号、密码、服务器地址或网络后重试。',
  );
}
