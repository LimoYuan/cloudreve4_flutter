import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_service.dart';
import '../core/utils/app_logger.dart';

class StorePaymentProvider {
  final String id;
  final String type;
  final String name;

  const StorePaymentProvider({
    required this.id,
    required this.type,
    required this.name,
  });

  factory StorePaymentProvider.fromJson(Map<String, dynamic> json) {
    return StorePaymentProvider(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? json['type']?.toString() ?? '支付',
    );
  }
}

class StorageProduct {
  final String id;
  final String name;
  final int size;
  final int time;
  final int price;
  final int? points;
  final String? chip;
  final List<String> description;

  const StorageProduct({
    required this.id,
    required this.name,
    required this.size,
    required this.time,
    required this.price,
    this.points,
    this.chip,
    this.description = const [],
  });

  factory StorageProduct.fromJson(Map<String, dynamic> json) {
    return StorageProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '存储扩容',
      size: _asInt(json['size']),
      time: _asInt(json['time']),
      price: _asInt(json['price']),
      points: _asNullableInt(json['points']),
      chip: json['chip']?.toString(),
      description: _asStringList(json['des'] ?? json['description']),
    );
  }
}

class StorePaymentSetting {
  final String currencyCode;
  final String currencyMark;
  final int currencyUnit;
  final List<StorePaymentProvider> providers;

  const StorePaymentSetting({
    required this.currencyCode,
    required this.currencyMark,
    required this.currencyUnit,
    required this.providers,
  });

  factory StorePaymentSetting.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return StorePaymentSetting(
      currencyCode: data['currency_code']?.toString() ??
          data['currencyCode']?.toString() ??
          'CNY',
      currencyMark: data['currency_mark']?.toString() ??
          data['currencyMark']?.toString() ??
          '¥',
      currencyUnit: _asInt(data['currency_unit'] ?? data['currencyUnit'], 100),
      providers: _asMapList(data['providers'])
          .map(StorePaymentProvider.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList(),
    );
  }

  String formatPrice(int rawPrice) {
    if (rawPrice <= 0) return '免费';
    final unit = currencyUnit <= 0 ? 100 : currencyUnit;
    final value = rawPrice / unit;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$currencyMark$text';
  }
}

class StoreConfig {
  final bool pointEnabled;
  final int sharePointGainRate;
  final int pointPrice;
  final bool shopNavEnabled;
  final StorePaymentSetting payment;
  final List<StorageProduct> storageProducts;

  const StoreConfig({
    required this.pointEnabled,
    required this.sharePointGainRate,
    required this.pointPrice,
    required this.shopNavEnabled,
    required this.payment,
    required this.storageProducts,
  });

  factory StoreConfig.fromJson(Map<String, dynamic> json) {
    // Cloudreve 的站点配置在不同版本/接口里可能是：
    // 1. data.storage_products
    // 2. data.storageProducts
    // 3. data.store.storage_products
    // 4. data.settings.storage_products
    // 所以不能只取第一层字段，要递归查找。
    final storeRoot = _findMapContainingAny(json, const [
          'storage_products',
          'storageProducts',
        ]) ??
        json;

    final productsRaw = _findValue(json, const [
          'storage_products',
          'storageProducts',
        ]) ??
        storeRoot['storage_products'] ??
        storeRoot['storageProducts'];

    final paymentRaw = _findValue(json, const ['payment']) ?? storeRoot['payment'];

    return StoreConfig(
      pointEnabled: _asBool(
        _findValue(json, const ['point_enabled', 'pointEnabled']) ??
            storeRoot['point_enabled'] ??
            storeRoot['pointEnabled'],
      ),
      sharePointGainRate: _asInt(
        _findValue(json, const ['share_point_gain_rate', 'sharePointGainRate']) ??
            storeRoot['share_point_gain_rate'] ??
            storeRoot['sharePointGainRate'],
      ),
      pointPrice: _asInt(
        _findValue(json, const ['point_price', 'pointPrice']) ??
            storeRoot['point_price'] ??
            storeRoot['pointPrice'],
      ),
      shopNavEnabled: _asBool(
        _findValue(json, const ['shop_nav_enabled', 'shopNavEnabled']) ??
            storeRoot['shop_nav_enabled'] ??
            storeRoot['shopNavEnabled'],
        true,
      ),
      payment: StorePaymentSetting.fromJson(_asMap(paymentRaw)),
      storageProducts: _asMapList(productsRaw)
          .map(StorageProduct.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList(),
    );
  }
}

class PaymentCreateResult {
  final bool paymentNeeded;
  final String? paymentUrl;
  final String? paymentId;
  final String? tradeNo;
  final String status;
  final bool qrCodePreferred;

  const PaymentCreateResult({
    required this.paymentNeeded,
    this.paymentUrl,
    this.paymentId,
    this.tradeNo,
    this.status = '',
    this.qrCodePreferred = false,
  });

  factory PaymentCreateResult.fromJson(Map<String, dynamic> json) {
    final root = _asMap(json['data']) ?? json;
    final payment = _asMap(root['payment']);
    final request = _asMap(root['request']);

    return PaymentCreateResult(
      paymentNeeded: _asBool(request?['payment_needed'] ?? request?['paymentNeeded']),
      paymentUrl: request?['url']?.toString(),
      qrCodePreferred: _asBool(
        request?['qr_code_preferred'] ?? request?['qrCodePreferred'],
      ),
      paymentId: payment?['id']?.toString(),
      tradeNo: payment?['trade_no']?.toString() ?? payment?['tradeNo']?.toString(),
      status: payment?['status']?.toString() ?? '',
    );
  }
}

class StoreService {
  StoreService._();

  static final StoreService instance = StoreService._();

  /// 获取商店配置。
  ///
  /// 之前只读 /site/config/basic 的第一层 storage_products，
  /// 你的站点商品存在但页面显示空，说明不同版本/返回结构可能不完全一致。
  /// 现在改为 raw Dio 读取 + 多端点兜底 + 递归查找 storage_products。
  Future<StoreConfig> getStoreConfig() async {
    StoreConfig? fallback;

    for (final endpoint in const [
      // Cloudreve V4 Pro 商店/积分/支付配置通常在 VAS 分区。
      // /site/config/basic 只会返回基础站点配置，通常没有 storage_products。
      '/site/config/vas',
      '/site/config/payment',
      '/site/config/shop',
      '/site/config/store',

      // 兼容不同版本/定制前端。
      '/site/config/basic',
      '/site/config/explorer',
      '/site/config',
    ]) {
      final raw = await _tryGetConfig(endpoint);
      if (raw == null) continue;

      final config = StoreConfig.fromJson(raw);
      AppLogger.d(
        'StoreService config endpoint=$endpoint '
        'keys=${raw.keys.toList()} '
        'products=${config.storageProducts.length} '
        'pointEnabled=${config.pointEnabled} '
        'paymentProviders=${config.payment.providers.length}',
      );

      fallback ??= config;

      if (config.storageProducts.isNotEmpty) {
        return config;
      }
    }

    // 兜底尝试一些可能的 VAS 商品接口，避免特定版本不把商品放进 basic config。
    for (final endpoint in const [
      '/vas/products',
      '/vas/product',
      '/vas/store',
    ]) {
      final raw = await _tryGetConfig(endpoint);
      if (raw == null) continue;

      final config = StoreConfig.fromJson(raw);
      AppLogger.d(
        'StoreService VAS endpoint=$endpoint '
        'keys=${raw.keys.toList()} products=${config.storageProducts.length}',
      );

      if (config.storageProducts.isNotEmpty) {
        // VAS 商品接口可能没有 payment/point 字段，合并 basic config 的支付设置。
        final base = fallback;
        if (base != null) {
          return StoreConfig(
            pointEnabled: base.pointEnabled,
            sharePointGainRate: base.sharePointGainRate,
            pointPrice: base.pointPrice,
            shopNavEnabled: base.shopNavEnabled,
            payment: base.payment,
            storageProducts: config.storageProducts,
          );
        }
        return config;
      }
    }

    return fallback ??
        const StoreConfig(
          pointEnabled: false,
          sharePointGainRate: 0,
          pointPrice: 0,
          shopNavEnabled: true,
          payment: StorePaymentSetting(
            currencyCode: 'CNY',
            currencyMark: '¥',
            currencyUnit: 100,
            providers: [],
          ),
          storageProducts: [],
        );
  }

  Future<Map<String, dynamic>?> _tryGetConfig(String endpoint) async {
    try {
      final response = await ApiService.instance.dio.get<dynamic>(
        endpoint,
        options: Options(
          extra: {'noAuth': false},
          validateStatus: (status) => status != null && status >= 200 && status < 500,
        ),
      );

      if (response.statusCode == 404) return null;

      final root = _asMap(response.data);
      if (root == null) {
        AppLogger.d('StoreService endpoint=$endpoint non-map response: ${response.data}');
        return null;
      }

      final code = root['code'];
      if (code is int && code != 0 && code != 203) {
        AppLogger.d('StoreService endpoint=$endpoint code=$code msg=${root['msg']}');
        return null;
      }

      final data = _asMap(root['data']) ?? root;

      AppLogger.d(
        'StoreService raw endpoint=$endpoint ${_shortJson(data)}',
      );

      return data;
    } catch (e) {
      AppLogger.d('StoreService endpoint=$endpoint failed: $e');
      return null;
    }
  }

  /// 创建存储扩容订单。
  ///
  /// Cloudreve V4 官方接口：PUT /vas/payment。
  /// 存储产品 product.type 固定使用 3。
  Future<PaymentCreateResult> createStoragePayment({
    required StorageProduct product,
    required int quantity,
    StorePaymentProvider? provider,
    String? email,
    String language = 'zh-CN',
  }) async {
    final body = <String, dynamic>{
      'product': {
        'type': 3,
        'sku_id': product.id,
      },
      'quantity': quantity,
      'email': email ?? '',
      'language': language,
      if (provider != null) 'provider_id': provider.id,
    };

    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/vas/payment',
      data: body,
    );

    return PaymentCreateResult.fromJson(response);
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return value.split('\n').where((e) => e.trim().isNotEmpty).toList();
  }
  return const [];
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
  return fallback;
}

dynamic _findValue(dynamic value, List<String> keys) {
  if (value is Map) {
    for (final key in keys) {
      if (value.containsKey(key)) return value[key];
    }

    for (final child in value.values) {
      final found = _findValue(child, keys);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = _findValue(child, keys);
      if (found != null) return found;
    }
  }

  return null;
}

Map<String, dynamic>? _findMapContainingAny(dynamic value, List<String> keys) {
  if (value is Map) {
    for (final key in keys) {
      if (value.containsKey(key)) {
        return Map<String, dynamic>.from(value);
      }
    }

    for (final child in value.values) {
      final found = _findMapContainingAny(child, keys);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = _findMapContainingAny(child, keys);
      if (found != null) return found;
    }
  }

  return null;
}

String _shortJson(dynamic value) {
  try {
    final text = jsonEncode(value);
    if (text.length <= 1200) return text;
    return '${text.substring(0, 1200)}...';
  } catch (_) {
    final text = value.toString();
    if (text.length <= 1200) return text;
    return '${text.substring(0, 1200)}...';
  }
}
