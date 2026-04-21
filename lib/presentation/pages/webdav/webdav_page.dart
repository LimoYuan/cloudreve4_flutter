import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/dav_account_model.dart';
import '../../../data/models/server_model.dart';
import '../../../services/webdav_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/auth_provider.dart';

/// WebDAV 页面
class WebdavPage extends StatefulWidget {
  const WebdavPage({super.key});

  @override
  State<WebdavPage> createState() => _WebdavPageState();
}

class _WebdavPageState extends State<WebdavPage> {
  List<DavAccountModel> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAccounts(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _loadAccounts(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_sync_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无 WebDAV 账户',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '点击 + 按钮添加 WebDAV 账户',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAccounts(),
      child: ListView.separated(
        itemCount: _accounts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final account = _accounts[index];
          return _buildAccountItem(context, account);
        },
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, DavAccountModel account) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_sync, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.uri,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _maskPassword(account.password),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.copy,
                  onPressed: () => _copyCredentials(context, account),
                  tooltip: '复制',
                  color: Colors.blue.shade500,
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  onPressed: () => _showEditDialog(context, account),
                  tooltip: '编辑',
                  color: Colors.orange.shade500,
                ),
                _buildActionButton(
                  icon: Icons.delete,
                  onPressed: () => _showDeleteDialog(context, account),
                  tooltip: '删除',
                  color: Colors.red.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _maskPassword(String password) {
    if (password.length <= 4) return '••••';
    return '••••${password.substring(password.length - 4)}';
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
      ),
    );
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await WebdavService().listAccounts(pageSize: 50);
      // 已经经过 api_service.dart -> _parseResponse 处理过的数据,
      // 直接不使用, 不需要 response['data'] 去取
      final accountsData = response as Map<String, dynamic>?;
      final accountsList = accountsData?['accounts'] as List<dynamic>? ?? [];
      final accounts = accountsList
          .map((a) => DavAccountModel.fromJson(a as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('刷新成功'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      messenger.showSnackBar(
        SnackBar(content: Text('刷新失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _copyCredentials(BuildContext context, DavAccountModel account) async {
    // 获取当前登录用户的邮箱 (在 async 之前获取)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.user?.email ?? account.id;

    // 缓存 messenger
    final messenger = ScaffoldMessenger.of(context);

    // 获取服务器地址
    final storageService = StorageService.instance;
    final servers = await storageService.servers;
    final lastLabel = await storageService.lastSelectedServerLabel;

    String davUrl = account.uri;
    if (lastLabel != null) {
      final currentServer = servers.firstWhere(
        (s) => s.label == lastLabel,
        orElse: () => ServerModel(label: '', baseUrl: ''),
      );
      if (currentServer.baseUrl.isNotEmpty) {
        // 去掉 baseUrl 末尾的 /api/v4
        final cleanBaseUrl = currentServer.baseUrl.replaceAll(
          RegExp(r'/api/v4/?$'),
          '',
        );
        davUrl = '$cleanBaseUrl/dav';
      }
    }

    final credentials = '地址: $davUrl\n用户: $username\n密码: ${account.password}';
    Clipboard.setData(ClipboardData(text: credentials));

    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('凭据已复制到剪贴板'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final uriController = TextEditingController();
    final proxyController = TextEditingController(text: 'false');
    final readonlyController = TextEditingController(text: 'false');

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加 WebDAV 账户'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '请输入备注名称',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uriController,
                decoration: const InputDecoration(
                  labelText: 'URI',
                  hintText: '/ or /folder',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proxyController,
                      decoration: const InputDecoration(
                        labelText: '反向代理',
                        hintText: 'true/false',
                        prefixIcon: Icon(Icons.swap_horiz),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: readonlyController,
                      decoration: const InputDecoration(
                        labelText: '只读',
                        hintText: 'true/false',
                        prefixIcon: Icon(Icons.visibility_off),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (created == true) {
      final name = nameController.text.trim();
      String uri = uriController.text.trim();
      final proxy = proxyController.text.trim().toLowerCase() == 'true';
      final readonly = readonlyController.text.trim().toLowerCase() == 'true';

      if (name.isEmpty || uri.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('请填写名称和URI'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final account = await WebdavService().createAccount(
          uri: 'cloudreve://my$uri',
          name: name,
          proxy: proxy,
          readonly: readonly,
        );

        if (!mounted) return;

        setState(() {
          _accounts.add(account);
          _isLoading = false;
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('创建成功'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        messenger.showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DavAccountModel account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: account.name);
    final uriController = TextEditingController(text: account.uri);

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑 WebDAV 账户'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '请输入备注名称',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uriController,
                decoration: const InputDecoration(
                  labelText: 'URI',
                  hintText: 'cloudreve://my',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      final name = nameController.text.trim();
      final uri = uriController.text.trim();

      if (name.isEmpty || uri.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('请填写名称和URI'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await WebdavService().updateAccount(
          id: account.id,
          name: name,
          uri: uri,
        );

        if (!mounted) return;

        setState(() {
          final index = _accounts.indexWhere((a) => a.id == account.id);
          if (index != -1) {
            _accounts[index] = account.copyWith(name: name, uri: uri);
          }
          _isLoading = false;
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('更新成功'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        messenger.showSnackBar(
          SnackBar(content: Text('更新失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    DavAccountModel account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除 WebDAV 账户 "${account.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await WebdavService().deleteAccount(account.id);

        if (!mounted) return;

        setState(() {
          _accounts.removeWhere((a) => a.id == account.id);
          _isLoading = false;
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('删除成功'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        messenger.showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

extension DavAccountModelExtension on DavAccountModel {
  DavAccountModel copyWith({
    String? name,
    String? uri,
    DateTime? createdAt,
    String? password,
    String? options,
  }) {
    return DavAccountModel(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      uri: uri ?? this.uri,
      password: password ?? this.password,
      options: options ?? this.options,
    );
  }
}
