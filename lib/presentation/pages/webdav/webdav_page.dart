import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../data/models/dav_account_model.dart';
import '../../../data/models/server_model.dart';
import '../../../services/webdav_service.dart';
import '../../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/toast_helper.dart';

class WebdavPage extends StatefulWidget {
  const WebdavPage({super.key});

  @override
  State<WebdavPage> createState() => _WebdavPageState();
}

class _WebdavPageState extends State<WebdavPage> {
  List<DavAccountModel> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => _loadAccounts(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          if (isDesktop) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showCreateDialog(context),
            label: const Text('添加账户'),
            icon: const Icon(LucideIcons.plus),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索 WebDAV 账户...',
            prefixIcon: const Icon(LucideIcons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            _searchQuery = value.toLowerCase();
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
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
    if (_errorMessage != null) return _buildErrorState();
    if (filteredAccounts.isEmpty) {
      return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoSearchResult();
    }

    return RefreshIndicator(
      onRefresh: () => _loadAccounts(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return isDesktop
              ? _buildDesktopLayout(filteredAccounts)
              : _buildMobileLayout(filteredAccounts);
        },
      ),
    );
  }

  // ─── 桌面端布局 ───

  Widget _buildDesktopLayout(List<DavAccountModel> accounts) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('名称', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('URI', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('密码', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: accounts.map((account) {
                return DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Row(
                          children: [
                            _buildAccountIcon(colorScheme, size: 18),
                            const SizedBox(width: 12),
                            Expanded(child: Text(account.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(account.uri, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_maskPassword(account.password),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    DataCell(Text(_formatDate(account.createdAt), style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            icon: LucideIcons.copy,
                            tooltip: '复制凭据',
                            onPressed: () => _copyCredentials(context, account),
                          ),
                          _buildActionButton(
                            icon: LucideIcons.pencil,
                            tooltip: '编辑',
                            onPressed: () => _showEditDialog(context, account),
                          ),
                          _buildActionButton(
                            icon: LucideIcons.trash2,
                            tooltip: '删除',
                            color: colorScheme.error,
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
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('添加账户'),
          ),
        ],
      ),
    );
  }

  // ─── 移动端布局 ───

  Widget _buildMobileLayout(List<DavAccountModel> accounts) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return InkWell(
          onTap: () => _showMobileActionMenu(account),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                _buildAccountIcon(colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.uri}  ·  ${_maskPassword(account.password)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  onPressed: () => _showMobileActionMenu(account),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 账户图标 ───

  Widget _buildAccountIcon(ColorScheme colorScheme, {double size = 18}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(LucideIcons.cloud, color: colorScheme.onPrimaryContainer, size: size),
    );
  }

  // ─── 桌面端操作按钮 ───

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    Color? color,
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

  String _maskPassword(String password) {
    if (password.length <= 4) return '••••';
    return '••••${password.substring(password.length - 4)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ─── 移动端菜单 ───

  void _showMobileActionMenu(DavAccountModel account) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('复制凭据'),
              onTap: () {
                Navigator.pop(context);
                _copyCredentials(this.context, account);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('编辑账户'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(this.context, account);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: colorScheme.error),
              title: Text('删除账户', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(this.context, account);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 空状态 / 错误状态 ───

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.cloud, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('暂无 WebDAV 账户', style: TextStyle(color: theme.hintColor)),
          const SizedBox(height: 8),
          Text('点击下方按钮添加账户',
              style: TextStyle(fontSize: 12, color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildNoSearchResult() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('没有找到 "$_searchQuery"', style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('加载失败', style: TextStyle(color: theme.hintColor)),
          const SizedBox(height: 8),
          Text(_errorMessage ?? '未知错误',
              style: TextStyle(fontSize: 12, color: theme.hintColor)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const Text('重试'),
            onPressed: _loadAccounts,
          ),
        ],
      ),
    );
  }

  // ─── 数据操作 ───

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await WebdavService().listAccounts(pageSize: 50);
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
        final cleanBaseUrl = currentServer.baseUrl.replaceAll(RegExp(r'/api/v4/?$'), '');
        davUrl = '$cleanBaseUrl/dav';
      }
    }

    final credentials = '地址: $davUrl\n用户: $username\n密码: ${account.password}';
    Clipboard.setData(ClipboardData(text: credentials));
    if (mounted) ToastHelper.success('凭据已复制到剪贴板');
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
                  prefixIcon: Icon(LucideIcons.tag),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uriController,
                decoration: const InputDecoration(
                  labelText: 'URI',
                  hintText: '/ or /folder',
                  prefixIcon: Icon(LucideIcons.link),
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
                        prefixIcon: Icon(LucideIcons.arrowLeftRight),
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
                        prefixIcon: Icon(LucideIcons.eyeOff),
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

      setState(() => _isLoading = true);
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
        setState(() => _isLoading = false);
        ToastHelper.failure('创建失败: $e');
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, DavAccountModel account) async {
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
                  prefixIcon: Icon(LucideIcons.tag),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uriController,
                decoration: const InputDecoration(
                  labelText: 'URI',
                  hintText: 'cloudreve://my',
                  prefixIcon: Icon(LucideIcons.link),
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

      setState(() => _isLoading = true);
      try {
        await WebdavService().updateAccount(id: account.id, name: name, uri: uri);
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
        setState(() => _isLoading = false);
        ToastHelper.failure('更新失败: $e');
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, DavAccountModel account) async {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      setState(() => _isLoading = true);
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
        setState(() => _isLoading = false);
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
