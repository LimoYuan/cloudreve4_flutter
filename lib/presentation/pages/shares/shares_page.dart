import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/share_model.dart';
import '../../../services/share_service.dart';
import '../../widgets/share_list_item.dart';

/// 分享列表页面
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
  // 分享列表默认加载条数
  static const _sharesPageListSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadShares();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

      final List<dynamic> sharesData = response['shares'] as List<dynamic>? ?? [];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '刷新成功' : '刷新失败'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('分享链接格式错误'),
            backgroundColor: Colors.red,
          ),
        );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('分享链接已复制'),
                  ),
                );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('文件名已复制'),
                        ),
                      );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法获取文件信息'),
                backgroundColor: Colors.red,
              ),
            );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('修改成功'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newUrl,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 11,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: newUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板'),
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(24, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('修改失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshShares,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _shares.isEmpty) {
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
              '加载失败',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
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

    if (_shares.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无分享',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '分享文件后，可以在这里管理',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadShares(isLoadMore: false),
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _shares.length + (_isLoading && _shares.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _shares.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final share = _shares[index];
          return ShareListItem(
            share: share,
            onEdit: () => _editShare(share),
            onDelete: () => _deleteShare(share),
          );
        },
      ),
    );
  }
}
