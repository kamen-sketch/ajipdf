import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'error_reporter.dart';

/// Konfigurasi aplikasi yang diambil dari backend (settable oleh admin).
class AppConfig {
  AppConfig({
    required this.pricing,
    required this.promo,
    required this.freeLimits,
    required this.proFeatures,
    required this.revenueCat,
  });

  final PricingConfig pricing;
  final PromoConfig promo;
  final FreeLimitsConfig freeLimits;
  final Map<String, bool> proFeatures;
  final RevenueCatConfig revenueCat;

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      pricing: PricingConfig.fromMap(
          Map<String, dynamic>.from(map['pricing'] ?? {})),
      promo: PromoConfig.fromMap(Map<String, dynamic>.from(map['promo'] ?? {})),
      freeLimits: FreeLimitsConfig.fromMap(
          Map<String, dynamic>.from(map['free_limits'] ?? {})),
      proFeatures: Map<String, bool>.from(
          (map['pro_features'] ?? {}).map((k, v) => MapEntry(k, v == true))),
      revenueCat: RevenueCatConfig.fromMap(
          Map<String, dynamic>.from(map['revenuecat'] ?? {})),
    );
  }

  factory AppConfig.defaults() => AppConfig(
        pricing: PricingConfig.defaults(),
        promo: PromoConfig.defaults(),
        freeLimits: FreeLimitsConfig.defaults(),
        proFeatures: const {},
        revenueCat: RevenueCatConfig.defaults(),
      );
}

class PricingConfig {
  PricingConfig({
    required this.monthlyLabel,
    required this.yearlyLabel,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.currency,
  });

  final String monthlyLabel;
  final String yearlyLabel;
  final int monthlyPrice;
  final int yearlyPrice;
  final String currency;

  factory PricingConfig.fromMap(Map<String, dynamic> m) => PricingConfig(
        monthlyLabel: m['monthly_label'] as String? ?? 'Rp 49.900/bulan',
        yearlyLabel: m['yearly_label'] as String? ?? 'Rp 499.000/tahun',
        monthlyPrice: (m['monthly_price'] as num?)?.toInt() ?? 49900,
        yearlyPrice: (m['yearly_price'] as num?)?.toInt() ?? 499000,
        currency: m['currency'] as String? ?? 'IDR',
      );

  factory PricingConfig.defaults() => PricingConfig.fromMap({});
}

class PromoConfig {
  PromoConfig({
    required this.enabled,
    required this.title,
    required this.message,
    required this.discountPercent,
    this.expiresAt,
  });

  final bool enabled;
  final String title;
  final String message;
  final int discountPercent;
  final DateTime? expiresAt;

  bool get isActive {
    if (!enabled) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  factory PromoConfig.fromMap(Map<String, dynamic> m) => PromoConfig(
        enabled: m['enabled'] == true,
        title: m['title'] as String? ?? '',
        message: m['message'] as String? ?? '',
        discountPercent: (m['discount_percent'] as num?)?.toInt() ?? 0,
        expiresAt: m['expires_at'] != null
            ? DateTime.tryParse(m['expires_at'].toString())
            : null,
      );

  factory PromoConfig.defaults() => PromoConfig.fromMap({});
}

class FreeLimitsConfig {
  FreeLimitsConfig({
    required this.splitMergeMonthly,
    required this.maxAnnotations,
    required this.maxFileSizeMb,
  });

  final int splitMergeMonthly;
  final int maxAnnotations;
  final int maxFileSizeMb;

  factory FreeLimitsConfig.fromMap(Map<String, dynamic> m) => FreeLimitsConfig(
        splitMergeMonthly: (m['split_merge_monthly'] as num?)?.toInt() ?? 10,
        maxAnnotations: (m['max_annotations'] as num?)?.toInt() ?? 50,
        maxFileSizeMb: (m['max_file_size_mb'] as num?)?.toInt() ?? 20,
      );

  factory FreeLimitsConfig.defaults() => FreeLimitsConfig.fromMap({});
}

class RevenueCatConfig {
  RevenueCatConfig({
    required this.apiKey,
    required this.entitlementId,
    required this.productMonthly,
    required this.productYearly,
  });

  final String apiKey;
  final String entitlementId;
  final String productMonthly;
  final String productYearly;

  factory RevenueCatConfig.fromMap(Map<String, dynamic> m) => RevenueCatConfig(
        apiKey: m['api_key'] as String? ?? '',
        entitlementId: m['entitlement_id'] as String? ?? 'pro',
        productMonthly: m['product_monthly'] as String? ?? 'ajipdf_pro_monthly',
        productYearly: m['product_yearly'] as String? ?? 'ajipdf_pro_yearly',
      );

  factory RevenueCatConfig.defaults() => RevenueCatConfig.fromMap({});
}

/// Service ambil config dari backend.
class ConfigService {
  static final ConfigService instance = ConfigService._();
  ConfigService._();

  AppConfig? _cached;
  AppConfig get current => _cached ?? AppConfig.defaults();

  Future<AppConfig> fetch() async {
    try {
      final res = await ApiService.instance.get('/config/public');
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;
      _cached = AppConfig.fromMap(data);
      return _cached!;
    } catch (e, st) {
      ErrorReporter.instance
          .reportError(e, st, screen: 'Config', action: 'fetch');
      return AppConfig.defaults();
    }
  }
}

/// Provider yang load config saat pertama dibaca.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  return ConfigService.instance.fetch();
});
