import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/share_model.dart';
import '../../../services/share_service.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../widgets/toast_helper.dart';

/// 分享列表页面 - 响应式布局
/// 桌面端（宽度 > 800）：使用数据表格
/// 移动端：使用精美卡片流
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

  // 搜索关键字
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 响应式布局断点
  static const double _desktopBreakpoint = 800;

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ShareService().deleteShare(id: share.id);
        setState(() {
          _shares.remove(share);
        });

        if (mounted) {
          ToastHelper.success('删除成功');
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ToastHelper.failure('删除失败: $e');
        }
      }
    }
  }

  Future<void> _editShare(ShareModel share) async {
    // 从分享URL中提取分享ID
    // 完整URL: https://xx.ee.eo:475/s/mPC7/28uqhft2
    final parts = share.url.split('/');
    if (parts.length < 5) {
      if (mounted) {
        ToastHelper.error('分享链接格式错误');
      }
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
              icon: const Icon(Icons.copy),
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
                  prefixIcon: const Icon(Icons.description),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
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
                  prefixIcon: Icon(Icons.timer),
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
                  prefixIcon: Icon(Icons.download),
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
      final expireDays = expireDaysText.isEmpty
          ? null
          : int.tryParse(expireDaysText);

      final downloadsText = downloadsController.text.trim();
      final downloads = downloadsText.isEmpty
          ? null
          : int.tryParse(downloadsText);

      final expireSeconds = expireDays != null
          ? expireDays * 24 * 60 * 60
          : null;

      setState(() {
        _isLoading = true;
      });

      try {
        // 获取分享详情以获取 sourceUri
        final shareInfo = await ShareService().getShareInfo(
          id: shareId,
          password: share.password,
          ownerExtended: true,
        );
        // 构建文件 uri: sourceUri + name
        if (shareInfo.sourceUri == null) {
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            ToastHelper.error('无法获取文件信息');
          }
          return;
        }

        final uri = '${shareInfo.sourceUri}/${share.name}';

        // 调用编辑分享
        final newUrl = await ShareService().editShare(
          id: shareId,
          uri: uri,
          isPrivate: share.isPrivate,
          password: share.password,
          shareView: share.shareView,
          downloads: downloads,
          expire: expireSeconds,
        );

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          await _loadShares();
        }

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
                    icon: const Icon(Icons.copy, size: 16),
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
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ToastHelper.failure('修改失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('我的分享',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: !isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshShares,
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
    );
  }

  /// 顶部操作栏：搜索和统计
  Widget _buildHeaderBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
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
                  hintText: '搜索分享内容...',
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
            Text('共 ${_shares.length} 条分享',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  /// 根据设备类型构建主体内容
  Widget _buildBody(BuildContext context, bool isDesktop) {
    // 过滤搜索结果
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

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (filteredShares.isEmpty) {
      return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoSearchResult();
    }

    return RefreshIndicator(
      onRefresh: () => _loadShares(isLoadMore: false),
      child: isDesktop
          ? _buildDesktopLayout(filteredShares)
          : _buildMobileLayout(filteredShares),
    );
  }

  /// 桌面端布局：数据表格
  Widget _buildDesktopLayout(List<ShareModel> shares) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final contentWidth = screenWidth * 0.8;
        final horizontalPadding = (screenWidth - contentWidth) / 2;

        return SingleChildScrollView(
          controller: _scrollController,
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
                        label:
                            Text('文件名', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                            Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('浏览/下载',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                            Text('状态', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                            Text('创建时间', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label:
                            Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: shares.map((share) {
                    return DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Row(
                              children: [
                                Icon(_getShareIcon(share),
                                    size: 20, color: _getIconColor(share)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(share.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(share.isFolder ? '文件夹' : '文件')),
                        DataCell(Text('${share.visited} / ${share.downloaded ?? 0}')),
                        DataCell(_buildStatusTag(share)),
                        DataCell(Text(_formatDate(share.createdAt),
                            style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.edit_outlined,
                                tooltip: '编辑',
                                color: Colors.blue,
                                onPressed: () => _editShare(share),
                              ),
                              _buildActionButton(
                                icon: Icons.copy,
                                tooltip: '复制链接',
                                color: Colors.green,
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: share.url));
                                  if (mounted) {
                                    ToastHelper.success('链接已复制');
                                  }
                                },
                              ),
                              _buildActionButton(
                                icon: Icons.delete_outline,
                                tooltip: '删除',
                                color: Colors.red,
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
          ),
        );
      },
    );
  }

  /// 移动端布局：精美卡片流
  Widget _buildMobileLayout(List<ShareModel> shares) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: shares.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= shares.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final share = shares[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _editShare(share),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getIconColor(share).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getShareIcon(share),
                            color: _getIconColor(share), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(share.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                share.isFolder ? '文件夹' : '文件',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showMobileActionMenu(share),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoChip(Icons.visibility, '${share.visited} 次'),
                      _buildInfoChip(Icons.download, '${share.downloaded ?? 0} 次'),
                      _buildStatusTag(share),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDate(share.createdAt),
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

  /// 构建状态标签
  Widget _buildStatusTag(ShareModel share) {
    final isExpired = share.expired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isExpired ? '已过期' : '正常',
        style: TextStyle(
          color: isExpired ? Colors.red : Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  /// 获取分享图标
  IconData _getShareIcon(ShareModel share) {
    if (share.isFolder) {
      return Icons.folder;
    }

    final name = share.name;

    if (FileTypeUtils.isImage(name)) {
      return Icons.image;
    } else if (FileTypeUtils.isPdf(name)) {
      return Icons.picture_as_pdf;
    } else if (FileTypeUtils.isVideo(name)) {
      return Icons.videocam;
    } else if (FileTypeUtils.isAudio(name)) {
      return Icons.audiotrack;
    } else if (FileTypeUtils.isMarkdown(name)) {
      return Icons.description;
    } else if (FileTypeUtils.isTextCode(name)) {
      return Icons.code;
    }

    return Icons.insert_drive_file_outlined;
  }

  /// 获取图标颜色
  Color _getIconColor(ShareModel share) {
    if (share.isFolder) {
      return Colors.amber.shade600;
    }

    final name = share.name;

    if (FileTypeUtils.isImage(name)) {
      return Colors.purple.shade600;
    } else if (FileTypeUtils.isPdf(name)) {
      return Colors.red.shade600;
    } else if (FileTypeUtils.isVideo(name)) {
      return Colors.orange.shade600;
    } else if (FileTypeUtils.isAudio(name)) {
      return Colors.blue.shade600;
    } else if (FileTypeUtils.isMarkdown(name)) {
      return Colors.teal.shade600;
    } else if (FileTypeUtils.isTextCode(name)) {
      return Colors.cyan.shade700;
    }

    return Colors.grey.shade600;
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
  void _showMobileActionMenu(ShareModel share) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('修改分享设置'),
              onTap: () {
                Navigator.pop(context);
                _editShare(share);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: share.url));
                if (mounted) {
                  ToastHelper.success('链接已复制');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('取消分享',
                  style: TextStyle(color: Colors.red)),
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

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.share_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('还没有分享过文件',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
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
            onPressed: _refreshShares,
          ),
        ],
      ),
    );
  }
}