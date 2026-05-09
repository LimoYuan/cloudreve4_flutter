import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models/share_model.dart';
import '../../../services/share_service.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../widgets/toast_helper.dart';

class SharesPage extends StatefulWidget {
  const SharesPage({super.key});

  @override
  State<SharesPage> createState() => _SharesPageState();
}

class _SharesPageState extends State<SharesPage> {
  List<ShareModel> _shares = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _nextPageToken;
  late ScrollController _scrollController;
  static const _sharesPageListSize = 20;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadShares();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreShares();
    }
  }

  Future<bool> _loadShares({bool isLoadMore = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ShareService().listShares(
        pageSize: _sharesPageListSize,
        nextPageToken: isLoadMore ? _nextPageToken : null,
      );

      final List<dynamic> sharesData =
          response['shares'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      final newShares = sharesData
          .map((s) => ShareModel.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _isLoading = false;
        if (isLoadMore) {
          _shares.addAll(newShares);
        } else {
          _shares = newShares;
        }
        _nextPageToken = pagination['next_token'] as String?;
        _hasMore = _nextPageToken != null;
      });
      return true;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      return false;
    }
  }

  Future<void> _loadMoreShares() async {
    if (!_hasMore || _isLoading) return;
    await _loadShares(isLoadMore: true);
  }

  Future<void> _refreshShares() async {
    final success = await _loadShares(isLoadMore: false);
    if (mounted) {
      if (success) {
        ToastHelper.success('刷新成功');
      } else {
        ToastHelper.failure('刷新失败');
      }
    }
  }

  Future<void> _deleteShare(ShareModel share) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分享'),
        content: Text('确定删除分享 "${share.name}" 吗？'),
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

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ShareService().deleteShare(id: share.id);
        setState(() => _shares.remove(share));
        if (mounted) ToastHelper.success('删除成功');
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ToastHelper.failure('删除失败: $e');
      }
    }
  }

  Future<void> _editShare(ShareModel share) async {
    final parts = share.url.split('/');
    if (parts.length < 5) {
      if (mounted) ToastHelper.error('分享链接格式错误');
      return;
    }
    final shareId = parts[4];

    final expireDaysController = TextEditingController(text: '7');
    final downloadsController = TextEditingController();

    final edited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Text('编辑分享'),
            const Spacer(),
            IconButton(
              icon: const Icon(LucideIcons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: share.url));
                Navigator.of(dialogContext).pop();
                ToastHelper.success('分享链接已复制');
              },
              tooltip: '复制分享链接',
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: '文件名',
                  prefixIcon: const Icon(LucideIcons.fileText),
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: share.name));
                      ToastHelper.success('文件名已复制');
                    },
                    tooltip: '复制文件名',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                controller: TextEditingController(text: share.name),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: expireDaysController,
                decoration: const InputDecoration(
                  labelText: '有效期（天）',
                  hintText: '留空则永久有效',
                  prefixIcon: Icon(LucideIcons.timer),
                  suffixText: '天',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: downloadsController,
                decoration: const InputDecoration(
                  labelText: '下载次数限制',
                  hintText: '留空则不限制',
                  prefixIcon: Icon(LucideIcons.download),
                  suffixText: '次',
                ),
                keyboardType: TextInputType.number,
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

    if (edited == true) {
      final expireDaysText = expireDaysController.text.trim();
      final expireDays =
          expireDaysText.isEmpty ? null : int.tryParse(expireDaysText);
      final downloadsText = downloadsController.text.trim();
      final downloads =
          downloadsText.isEmpty ? null : int.tryParse(downloadsText);
      final expireSeconds = expireDays != null ? expireDays * 24 * 60 * 60 : null;

      setState(() => _isLoading = true);

      try {
        final shareInfo = await ShareService().getShareInfo(
          id: shareId,
          password: share.password,
          ownerExtended: true,
        );
        if (shareInfo.sourceUri == null) {
          setState(() => _isLoading = false);
          if (mounted) ToastHelper.error('无法获取文件信息');
          return;
        }

        final uri = '${shareInfo.sourceUri}/${share.name}';
        final newUrl = await ShareService().editShare(
          id: shareId,
          uri: uri,
          isPrivate: share.isPrivate,
          password: share.password,
          shareView: share.shareView,
          downloads: downloads,
          expire: expireSeconds,
        );

        setState(() => _isLoading = false);
        if (mounted) await _loadShares();
        if (mounted) {
          ToastHelper.success('修改成功');
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('分享链接'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(newUrl, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('复制到剪贴板'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: newUrl));
                      Navigator.of(dialogContext).pop();
                      ToastHelper.success('已复制到剪贴板');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ToastHelper.failure('修改失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _refreshShares,
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
            hintText: '搜索分享内容...',
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
    final filteredShares = _searchQuery.isEmpty
        ? _shares
        : _shares
            .where((s) =>
                s.name.toLowerCase().contains(_searchQuery) ||
                s.url.toLowerCase().contains(_searchQuery))
            .toList();

    if (_isLoading && _shares.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadShares(isLoadMore: false),
      child: _errorMessage != null
          ? _buildErrorState()
          : filteredShares.isEmpty
              ? (_searchQuery.isEmpty ? _buildEmptyState() : _buildNoSearchResult())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 800;
                    return isDesktop
                        ? _buildDesktopLayout(filteredShares)
                        : _buildMobileLayout(filteredShares);
                  },
                ),
    );
  }

  // ─── 桌面端布局 ───

  Widget _buildDesktopLayout(List<ShareModel> shares) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('文件名', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('浏览/下载', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: shares.map((share) {
            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Row(
                      children: [
                        Icon(_getShareIcon(share), size: 18, color: _getIconColor(share, colorScheme)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(share.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(share.isFolder ? '文件夹' : '文件')),
                DataCell(Text('${share.visited} / ${share.downloaded ?? 0}')),
                DataCell(_buildStatusBadge(share)),
                DataCell(Text(_formatDate(share.createdAt), style: const TextStyle(fontSize: 12))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: LucideIcons.pencil,
                        tooltip: '编辑',
                        onPressed: () => _editShare(share),
                      ),
                      _buildActionButton(
                        icon: LucideIcons.copy,
                        tooltip: '复制链接',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: share.url));
                          if (mounted) ToastHelper.success('链接已复制');
                        },
                      ),
                      _buildActionButton(
                        icon: LucideIcons.trash2,
                        tooltip: '删除',
                        color: colorScheme.error,
                        onPressed: () => _deleteShare(share),
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
    );
  }

  // ─── 移动端布局 ───

  Widget _buildMobileLayout(List<ShareModel> shares) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: shares.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= shares.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final share = shares[index];
        final iconColor = _getIconColor(share, theme.colorScheme);
        return InkWell(
          onTap: () => _editShare(share),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getShareIcon(share), size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildStatusBadge(share),
                          const SizedBox(width: 8),
                          Text(
                            '浏览 ${share.visited} · 下载 ${share.downloaded ?? 0}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  onPressed: () => _showMobileActionMenu(share),
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

  // ─── 状态徽章 ───

  Widget _buildStatusBadge(ShareModel share) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpired = share.expired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isExpired
            ? colorScheme.error.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isExpired ? '已过期' : '正常',
        style: TextStyle(
          color: isExpired ? colorScheme.error : Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
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

  // ─── 图标与颜色 ───

  IconData _getShareIcon(ShareModel share) {
    if (share.isFolder) return LucideIcons.folder;
    final name = share.name;
    if (FileTypeUtils.isImage(name)) return LucideIcons.image;
    if (FileTypeUtils.isPdf(name)) return LucideIcons.fileText;
    if (FileTypeUtils.isVideo(name)) return LucideIcons.video;
    if (FileTypeUtils.isAudio(name)) return LucideIcons.music;
    if (FileTypeUtils.isMarkdown(name)) return LucideIcons.fileText;
    if (FileTypeUtils.isTextCode(name)) return LucideIcons.code;
    return LucideIcons.file;
  }

  Color _getIconColor(ShareModel share, ColorScheme colorScheme) {
    if (share.isFolder) return Colors.amber.shade700;
    final name = share.name;
    if (FileTypeUtils.isImage(name)) return Colors.purple.shade600;
    if (FileTypeUtils.isPdf(name)) return Colors.red.shade600;
    if (FileTypeUtils.isVideo(name)) return Colors.orange.shade600;
    if (FileTypeUtils.isAudio(name)) return Colors.blue.shade600;
    if (FileTypeUtils.isMarkdown(name)) return Colors.teal.shade600;
    if (FileTypeUtils.isTextCode(name)) return Colors.cyan.shade700;
    return colorScheme.onSurfaceVariant;
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

  void _showMobileActionMenu(ShareModel share) {
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
              leading: const Icon(LucideIcons.pencil),
              title: const Text('修改分享设置'),
              onTap: () {
                Navigator.pop(context);
                _editShare(share);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: share.url));
                if (mounted) ToastHelper.success('链接已复制');
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: colorScheme.error),
              title: Text('取消分享', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteShare(share);
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
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.share2, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text('还没有分享过文件', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResult() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.searchX, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text('没有找到 "$_searchQuery"', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
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
                  onPressed: _refreshShares,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
