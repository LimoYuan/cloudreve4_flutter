import 'package:cloudreve4_flutter/presentation/providers/auth_provider.dart';
import 'package:cloudreve4_flutter/presentation/providers/user_setting_provider.dart';
import 'package:cloudreve4_flutter/presentation/widgets/toast_helper.dart';
import 'package:cloudreve4_flutter/services/store_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  StoreConfig? _config;
  bool _isLoading = true;
  bool _isBuying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await StoreService.instance.getStoreConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('商店'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadStore,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(LucideIcons.hardDrive, size: 18),
              text: '存储扩容',
            ),
            Tab(
              icon: Icon(LucideIcons.moreHorizontal, size: 18),
              text: '更多',
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _isLoading
          ? const Center(
              key: ValueKey('store_loading'),
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : config == null
                  ? const Center(child: Text('商店配置为空'))
                  : TabBarView(
                      key: const ValueKey('store_content'),
                      controller: _tabController,
                      children: [
                        _buildStorageProducts(config),
                        _buildMore(config),
                      ],
                    ),
      ),
    );
  }

  Widget _buildError() {
    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        cacheExtent: 600,
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loadStore,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageProducts(StoreConfig config) {
    final products = config.storageProducts;

    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        cacheExtent: 800,
        padding: const EdgeInsets.all(16),
        children: [
          _buildStoreHeader(config),
          const SizedBox(height: 20),
          Text(
            '商品',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            _EmptyStoreCard(onRefresh: _loadStore)
          else
            ...products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StorageProductCard(
                  product: product,
                  payment: config.payment,
                  pointEnabled: config.pointEnabled,
                  onTap: _isBuying ? null : () => _confirmPurchase(product, config),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader(StoreConfig config) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                LucideIcons.shoppingBag,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '存储扩容',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.pointEnabled
                        ? '支持积分/余额购买，购买后容量会自动增加'
                        : '购买后容量会自动增加',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMore(StoreConfig config) {
    final providers = config.payment.providers;

    return RefreshIndicator(
      onRefresh: _loadStore,
      child: ListView(
        cacheExtent: 800,
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.coins),
              title: const Text('积分系统'),
              subtitle: Text(
                config.pointEnabled
                    ? '已启用 · 分享获得 ${config.sharePointGainRate}% · 积分价格 ${config.pointPrice}'
                    : '未启用',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.creditCard),
              title: const Text('支付方式'),
              subtitle: providers.isEmpty
                  ? const Text('当前站点未配置第三方支付，可能仅支持免费商品或积分购买')
                  : Text(providers.map((e) => e.name).join('、')),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.ticket),
              title: const Text('兑换码'),
              subtitle: const Text('后续可接入 Cloudreve 兑换码接口'),
              onTap: () => ToastHelper.info('兑换码功能稍后接入'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurchase(StorageProduct product, StoreConfig config) async {
    StorePaymentProvider? selectedProvider =
        config.payment.providers.isNotEmpty ? config.payment.providers.first : null;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final providers = config.payment.providers;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '确认购买',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _PurchaseSummary(product: product, payment: config.payment),
                    if (providers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '支付方式',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...providers.map(
                        (provider) => RadioListTile<StorePaymentProvider>(
                          value: provider,
                          groupValue: selectedProvider,
                          onChanged: (value) => setSheetState(() {
                            selectedProvider = value;
                          }),
                          title: Text(provider.name),
                          subtitle: Text(provider.type),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        config.pointEnabled
                            ? '当前没有第三方支付方式，将尝试使用积分/站内余额购买。'
                            : '当前没有第三方支付方式。免费商品可直接领取；付费商品需要站点配置支付方式。',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).hintColor,
                            ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(product.price == 0 ? '领取' : '购买'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _purchase(product, config, selectedProvider);
    }
  }

  Future<void> _purchase(
    StorageProduct product,
    StoreConfig config,
    StorePaymentProvider? provider,
  ) async {
    final auth = context.read<AuthProvider>();

    setState(() => _isBuying = true);
    try {
      final result = await StoreService.instance.createStoragePayment(
        product: product,
        quantity: 1,
        provider: provider,
        email: auth.user?.email,
      );

      if (!mounted) return;

      final url = result.paymentUrl;
      if (result.paymentNeeded && url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ToastHelper.failure('无法打开支付页面');
        } else if (mounted) {
          ToastHelper.info('请在支付页面完成付款');
        }
      } else {
        ToastHelper.success('购买成功');
        await context.read<UserSettingProvider>().loadCapacity();
        await _loadStore();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.failure('购买失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isBuying = false);
      }
    }
  }
}

class _StorageProductCard extends StatelessWidget {
  final StorageProduct product;
  final StorePaymentSetting payment;
  final bool pointEnabled;
  final VoidCallback? onTap;

  const _StorageProductCard({
    required this.product,
    required this.payment,
    required this.pointEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = payment.formatPrice(product.price);
    final points = product.points;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (product.chip != null && product.chip!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.chip!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                price,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFFF9CA8),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(product.size)} - ${_formatDuration(product.time)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (pointEnabled && points != null) ...[
                const SizedBox(height: 6),
                Text(
                  '$points 积分',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...product.description.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.check,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '永久';
    if (seconds < 86400) return '${seconds ~/ 3600 == 0 ? 1 : seconds ~/ 3600} 小时';
    final days = (seconds / 86400).round();
    if (days < 30) return '$days 天';
    if (days < 365) return '${(days / 30).round()} 个月';
    return '${(days / 365).toStringAsFixed(1)} 年';
  }
}

class _PurchaseSummary extends StatelessWidget {
  final StorageProduct product;
  final StorePaymentSetting payment;

  const _PurchaseSummary({
    required this.product,
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.hardDrive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${product.name} · ${_formatBytes(product.size)} · ${_formatDuration(product.time)}',
              ),
            ),
            Text(
              payment.formatPrice(product.price),
              style: const TextStyle(
                color: Color(0xFFFF9CA8),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '永久';
    if (seconds < 86400) return '${seconds ~/ 3600 == 0 ? 1 : seconds ~/ 3600} 小时';
    final days = (seconds / 86400).round();
    if (days < 30) return '$days 天';
    if (days < 365) return '${(days / 30).round()} 个月';
    return '${(days / 365).toStringAsFixed(1)} 年';
  }
}

class _EmptyStoreCard extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyStoreCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              LucideIcons.shoppingBag,
              size: 46,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无商品',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '请在 Cloudreve 后台配置存储扩容商品',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }
}
