import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/user_model.dart';
import '../../../services/user_setting_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_setting_provider.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';

/// 个人资料编辑页
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: DesktopConstrained(
        child: ListView(
        children: [
          const SizedBox(height: 24),
          _buildAvatarSection(context, user),
          const SizedBox(height: 16),
          _buildInfoTile(
            context,
            icon: Icons.badge_outlined,
            title: '昵称',
            value: user?.nickname ?? '',
            onTap: () => _showEditNickDialog(context, user),
          ),
          _buildInfoTile(
            context,
            icon: Icons.email_outlined,
            title: '邮箱',
            value: user?.email ?? '',
            onTap: null, // 邮箱不可修改
          ),
          _buildInfoTile(
            context,
            icon: Icons.group_outlined,
            title: '用户组',
            value: user?.group?.name ?? '',
            onTap: null,
          ),
          _buildInfoTile(
            context,
            icon: Icons.calendar_today_outlined,
            title: '注册时间',
            value: _formatDate(user?.createdAt),
            onTap: null,
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(BuildContext context, UserModel? user) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Stack(
        children: [
          _buildAvatar(context, user, 80),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: _isUploadingAvatar
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.camera_alt, size: 16, color: colorScheme.onPrimary),
                      onPressed: _showAvatarOptions,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserModel? user, double size) {
    final avatarUrl = user?.avatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.person, size: size * 0.5, color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  Future<void> _showAvatarOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('使用 Gravatar'),
              subtitle: const Text('根据邮箱自动生成头像'),
              onTap: () => Navigator.of(ctx).pop('gravatar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result == 'gravatar') {
      await _resetToGravatar();
    } else {
      final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
      await _pickAndUploadAvatar(source);
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
      if (image == null || !mounted) return;

      setState(() => _isUploadingAvatar = true);

      final bytes = await image.readAsBytes();
      final service = UserSettingService.instance;
      await service.updateAvatar(bytes);

      // 刷新用户信息
      await context.read<AuthProvider>().refreshUser();

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ToastHelper.success('头像已更新');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ToastHelper.failure('上传头像失败: $e');
      }
    }
  }

  Future<void> _resetToGravatar() async {
    try {
      setState(() => _isUploadingAvatar = true);
      final service = UserSettingService.instance;
      await service.updateAvatar(null);
      await context.read<AuthProvider>().refreshUser();

      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ToastHelper.success('已切换为 Gravatar');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ToastHelper.failure('操作失败: $e');
      }
    }
  }

  Future<void> _showEditNickDialog(BuildContext context, UserModel? user) async {
    final controller = TextEditingController(text: user?.nickname ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '昵称',
              hintText: '请输入新昵称',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '昵称不能为空';
              if (v.trim().length > 255) return '昵称不能超过255个字符';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newNick = controller.text.trim();
    if (newNick == user?.nickname) return;

    final success = await context.read<UserSettingProvider>().updateNick(newNick);
    if (!mounted) return;

    if (success) {
      // 同步刷新 AuthProvider 中的用户信息
      await context.read<AuthProvider>().refreshUser();
      ToastHelper.success('昵称已修改');
    } else {
      ToastHelper.failure('修改昵称失败');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
