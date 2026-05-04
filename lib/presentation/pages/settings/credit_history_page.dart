import 'package:flutter/material.dart';
import '../../../data/models/user_setting_model.dart';
import '../../../services/user_setting_service.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/desktop_constrained.dart';

/// 积分变动历史页
class CreditHistoryPage extends StatefulWidget {
  final int currentCredit;

  const CreditHistoryPage({super.key, required this.currentCredit});

  @override
  State<CreditHistoryPage> createState() => _CreditHistoryPageState();
}

class _CreditHistoryPageState extends State<CreditHistoryPage> {
  final List<CreditChange> _changes = [];
  String? _nextToken;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool get _hasMore => _nextToken != null && _nextToken!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  Future<void> _loadChanges() async {
    try {
      final result = await UserSettingService.instance.getCreditChanges(
        nextPageToken: _nextToken,
      );
      if (mounted) {
        setState(() {
          _changes.addAll(result.changes);
          _nextToken = result.nextToken;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ToastHelper.failure('加载积分记录失败: $e');
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadChanges();
  }

  Future<void> _refresh() async {
    setState(() {
      _changes.clear();
      _nextToken = null;
      _isLoading = true;
    });
    await _loadChanges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('积分记录')),
      body: DesktopConstrained(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            '${widget.currentCredit}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('当前积分', style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )),
                        ],
                      ),
                    ),
                  ),
                  if (_changes.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('暂无积分记录', style: TextStyle(color: Colors.grey))),
                    )
                  else ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _changes.length) {
                            return _hasMore
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : TextButton(
                                              onPressed: _loadMore,
                                              child: const Text('加载更多'),
                                            ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }

                          final change = _changes[index];
                          final isPositive = change.diff > 0;

                          return ListTile(
                            leading: Icon(
                              isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                            title: Text(change.reasonLabel),
                            subtitle: Text(_formatDateTime(change.changedAt)),
                            trailing: Text(
                              '${isPositive ? "+" : ""}${change.diff}',
                              style: TextStyle(
                                color: isPositive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                        childCount: _changes.length + 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
