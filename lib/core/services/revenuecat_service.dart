import 'revenuecat_service_stub.dart'
    if (dart.library.html) 'revenuecat_service_web.dart';

/// Hasil purchase RevenueCat.
class PurchaseResult {
  PurchaseResult({
    required this.success,
    this.customerId,
    this.activeEntitlements = const [],
    this.productId,
    this.error,
  });

  final bool success;
  final String? customerId;
  final List<String> activeEntitlements;
  final String? productId;
  final String? error;
}

/// Service RevenueCat lintas platform.
abstract class RevenueCatService {
  /// Konfigurasi SDK dengan apiKey dan appUserId (= user.id kita).
  static Future<bool> configure(String apiKey, String appUserId) {
    return rcConfigureImpl(apiKey, appUserId);
  }

  /// Beli paket. [packageId] mis. '$rc_monthly' atau identifier offering.
  static Future<PurchaseResult> purchase(String packageId) {
    return rcPurchaseImpl(packageId);
  }

  /// Restore: cek entitlement aktif.
  static Future<PurchaseResult> getCustomerInfo() {
    return rcGetCustomerInfoImpl();
  }
}
