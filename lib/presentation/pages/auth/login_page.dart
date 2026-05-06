import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/validators/string_validator.dart';
import '../../../data/models/server_model.dart';
import '../../providers/auth_provider.dart';
import '../../../services/server_service.dart';
import '../../../router/app_router.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../../widgets/toast_helper.dart';

/// 登录页
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 初始化API服务
    _loadRememberedInfo();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 加载记住我的信息
  Future<void> _loadRememberedInfo() async {
    final server = ServerService.instance.currentServer;
    if (server != null) {
      setState(() {
        if (server.email != null) {
          _emailController.text = server.email!;
        }
        if (server.password != null && server.rememberMe) {
          _passwordController.text = server.password!;
        }
        _rememberMe = server.rememberMe;
      });
    }
  }

  /// 显示服务器选择器
  Future<void> _showServerSelector() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ServerSelectorSheet(),
    );

    // 服务器选择后重新加载信息
    await _loadRememberedInfo();
  }

  /// 显示服务器管理对话框
  Future<void> _showServerManagement() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ServerManagementSheet(),
    );

    // 服务器管理后重新加载信息
    await _loadRememberedInfo();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await authProvider.passwordLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (success && mounted) {
        _focusNode.unfocus();
        ToastHelper.success('登录成功');

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          navigator.pushReplacementNamed(RouteNames.home);
        }
      } else if (mounted) {
        final errorMessage = authProvider.errorMessage;
        if (errorMessage != null && errorMessage.isNotEmpty) {
          final errorMsg = _parseErrorMessage(errorMessage);
          ToastHelper.failure(errorMsg);
        } else {
          ToastHelper.failure('登录失败');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final errorMsg = _parseErrorMessage(e.toString());
        ToastHelper.failure(errorMsg);
      }
    }
  }

  String _parseErrorMessage(String error) {
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
        if (msg.isNotEmpty) {
          return '登录失败: $msg';
        }
      }
    }
    if (error.contains('"') && error.split('"').length >= 2) {
      final parts = error.split('"');
      if (parts.length >= 2) {
        final msg = parts[1].trim();
        if (msg.isNotEmpty && msg != 'login') {
          return '登录失败: $msg';
        }
      }
    }
    return error.isEmpty ? '登录失败: 未知原因' : '登录失败: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo或应用名称
                  Center(child: _buildLogo()),

                  const SizedBox(height: 48),

                  // 标题
                  Center(
                    child: Text(
                      'Cloudreve V4.0',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 服务器选择器
                  _ServerSelector(
                    onTap: _showServerSelector,
                    onManage: _showServerManagement,
                  ),

                  const SizedBox(height: 16),

                  // 邮箱输入框
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: StringValidator.validateEmail,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入邮箱地址',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onFieldSubmitted: (_) {
                      _focusNode.requestFocus();
                    },
                  ),

                  const SizedBox(height: 16),

                  // 密码输入框
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _focusNode,
                    obscureText: _obscurePassword,
                    validator: StringValidator.validatePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    onFieldSubmitted: (_) {
                      _login();
                    },
                  ),

                  const SizedBox(height: 16),

                  // 记住我
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('记住我'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 链接按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: const Text('忘记密码？'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text('注册账号'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 登录按钮
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ClipOval(
      child: Image.asset(
        'assets/images/app_logo.png',
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// 服务器选择器组件
class _ServerSelector extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onManage;

  const _ServerSelector({
    required this.onTap,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final currentServer = ServerService.instance.currentServer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.dns, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentServer?.label ?? '选择服务器',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (currentServer != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      currentServer.baseUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onManage,
              tooltip: '管理服务器',
            ),
          ],
        ),
      ),
    );
  }
}

/// 服务器选择器BottomSheet
class ServerSelectorSheet extends StatelessWidget {
  const ServerSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final currentServer = ServerService.instance.currentServer;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择服务器',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = servers[index];
                final isSelected = currentServer?.label == server.label;

                return _ServerListItem(
                  server: server,
                  isSelected: isSelected,
                  onTap: () async {
                    await ServerService.instance.selectServer(server.label);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 服务器列表项
class _ServerListItem extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServerListItem({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Radio<String>(
        value: server.label,
        groupValue: ServerService.instance.currentServer?.label,
        onChanged: (_) => onTap(),
      ),
      title: Text(
        server.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      tileColor: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      onTap: onTap,
    );
  }
}

/// 服务器管理BottomSheet
class ServerManagementSheet extends StatefulWidget {
  const ServerManagementSheet({super.key});

  @override
  State<ServerManagementSheet> createState() => _ServerManagementSheetState();
}

class _ServerManagementSheetState extends State<ServerManagementSheet> {
  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '管理服务器',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = servers[index];
                return _ServerManagementItem(
                  server: server,
                  onEdit: () => _showEditServerDialog(context, server),
                  onDelete: () => _showDeleteConfirmDialog(context, server),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddServerDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('添加服务器'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    final labelController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                hintText: '例如: 我的服务器',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://example.com/api/v4',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.addServer(
          ServerModel(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) {
          ToastHelper.success('服务器已添加');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.failure('添加失败: $e');
        }
      }
    }
  }

  Future<void> _showEditServerDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final labelController = TextEditingController(text: server.label);
    final urlController = TextEditingController(text: server.baseUrl);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.updateServer(
          server.label,
          server.copyWith(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) {
          ToastHelper.success('服务器已更新');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.failure('更新失败: $e');
        }
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器 "${server.label}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.deleteServer(server.label);
        setState(() {});
        if (context.mounted) {
          ToastHelper.success('服务器已删除');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.failure('删除失败: $e');
        }
      }
    }
  }
}

/// 服务器管理列表项
class _ServerManagementItem extends StatelessWidget {
  final ServerModel server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServerManagementItem({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        server.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: '删除',
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
