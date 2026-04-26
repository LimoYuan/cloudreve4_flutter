import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/dav_account_model.dart';
import '../../../data/models/server_model.dart';
import '../../../services/webdav_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';

/// WebDAV 页面 - 响应式布局
/// 桌面端（宽度 > 800）：使用数据表格
/// 移动端：使用精美卡片流
class WebdavPage extends StatefulWidget {
  const WebdavPage({super.key});

  @override
  State<WebdavPage> createState() => _WebdavPageState();
}

class _WebdavPageState extends State<WebdavPage> {
  List<DavAccountModel> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 搜索关键字
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 响应式布局断点
  static const double _desktopBreakpoint = 800;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('WebDAV',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: !isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAccounts(),
            tooltip: '刷新',
          ),
          if (isDesktop) const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderBar(isDesktop),
          Expanded(child: _buildBody(context, isDesktop)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        label: const Text('添加账户'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  /// 顶部操作栏：搜索和统计
  Widget _buildHeaderBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '搜索 WebDAV 账户...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (value) {
                  _searchQuery = value.toLowerCase();
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (isDesktop)
            Text('共 ${_accounts.length} 个账户',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  /// 根据设备类型构建主体内容
  Widget _buildBody(BuildContext context, bool isDesktop) {
    // 过滤搜索结果
    final filteredAccounts = _searchQuery.isEmpty
        ? _accounts
        : _accounts
            .where((a) =>
                a.name.toLowerCase().contains(_searchQuery) ||
                a.uri.toLowerCase().contains(_searchQuery))
            .toList();

    if (_isLoading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (filteredAccounts.isEmpty) {
      return _searchQuery.isEmpty
          ? _buildEmptyState()
          : _buildNoSearchResult();
    }

    return RefreshIndicator(
      onRefresh: () => _loadAccounts(),
      child: isDesktop
          ? _buildDesktopLayout(filteredAccounts)
          : _buildMobileLayout(filteredAccounts),
    );
  }

  /// 桌面端布局：数据表格
  Widget _buildDesktopLayout(List<DavAccountModel> accounts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final contentWidth = screenWidth * 0.8;
        final horizontalPadding = (screenWidth - contentWidth) / 2;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
          child: SizedBox(
            width: contentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(
                        label: Text('名称',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('URI',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('密码',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('创建时间',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('操作',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: accounts.map((account) {
                    return DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Row(
                              children: [
                                _buildAccountIcon(size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(account.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(account.uri,
                            style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_maskPassword(account.password),
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12))),
                        DataCell(Text(_formatDate(account.createdAt),
                            style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.copy,
                                tooltip: '复制凭据',
                                color: Colors.blue,
                                onPressed: () => _copyCredentials(context, account),
                              ),
                              _buildActionButton(
                                icon: Icons.edit_outlined,
                                tooltip: '编辑',
                                color: Colors.orange,
                                onPressed: () => _showEditDialog(context, account),
                              ),
                              _buildActionButton(
                                icon: Icons.delete_outline,
                                tooltip: '删除',
                                color: Colors.red,
                                onPressed: () => _showDeleteDialog(context, account),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 移动端布局：精美卡片流
  Widget _buildMobileLayout(List<DavAccountModel> accounts) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showMobileActionMenu(account),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildAccountIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('WebDAV 账户',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showMobileActionMenu(account),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(Icons.link, account.uri),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoChip(Icons.lock,
                            _maskPassword(account.password)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDate(account.createdAt),
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建账户图标
  Widget _buildAccountIcon({double size = 20}) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF34A853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.cloud_sync, color: Colors.white, size: size - 2),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(32, 32),
      ),
    );
  }

  /// 遮罩密码
  String _maskPassword(String password) {
    if (password.length <= 4) return '••••';
    return '••••${password.substring(password.length - 4)}';
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// 移动端快捷菜单
  void _showMobileActionMenu(DavAccountModel account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制凭据'),
              onTap: () {
                Navigator.pop(context);
                _copyCredentials(context, account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑账户'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除账户',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, account);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_sync_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('暂无 WebDAV 账户',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('点击下方按钮添加账户',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// 无搜索结果
  Widget _buildNoSearchResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '没有找到 "$_searchQuery"',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '未知错误',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            onPressed: _loadAccounts,
          ),
        ],
      ),
    );
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await WebdavService().listAccounts(pageSize: 50);
      final accountsData = response as Map<String, dynamic>?;
      final accountsList =
          accountsData?['accounts'] as List<dynamic>? ?? [];
      final accounts = accountsList
          .map((a) => DavAccountModel.fromJson(a as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });

      ToastHelper.success('刷新成功');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      ToastHelper.failure('刷新失败: $e');
    }
  }

  void _copyCredentials(BuildContext context, DavAccountModel account) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.user?.email ?? account.id;

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
      ToastHelper.success('凭据已复制到剪贴板');
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
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
        ToastHelper.error('请填写名称和URI');
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

        ToastHelper.success('创建成功');
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ToastHelper.failure('创建失败: $e');
      }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DavAccountModel account,
  ) async {
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
        ToastHelper.error('请填写名称和URI');
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

        ToastHelper.success('更新成功');
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ToastHelper.failure('更新失败: $e');
      }
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    DavAccountModel account,
  ) async {
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

        ToastHelper.success('删除成功');
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ToastHelper.failure('删除失败: $e');
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
