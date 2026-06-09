import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/config_service.dart';
import '../services/error_reporter.dart';
import '../services/revenuecat_service.dart';
import 'auth_provider.dart';

/// Subscription tier
enum SubscriptionTier { free, pro }

/// Daftar email yang otomatis mendapatkan akses Pro penuh (whitelist).
/// Berguna untuk akun internal / testing.
const Set<String> kProWhitelistEmails = {
  'kamenridersmg@gmail.com',
};

/// Batas penggunaan untuk tier Free.
class FreeLimits {
  FreeLimits._();

  /// Maksimal operasi split/merge per bulan untuk Free.
  static const int splitMergeMonthly = 10;

  /// Maksimal annotation untuk Free.
  static const int maxAnnotations = 50;
}

/// State langganan pengguna.
class SubscriptionState {
  final SubscriptionTier tier;

  /// Jumlah operasi split/merge yang sudah dipakai bulan ini (khusus Free).
  final int splitMergeUsed;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.splitMergeUsed = 0,
  });

  bool get isPro => tier == SubscriptionTier.pro;

  /// Sisa kuota split/merge untuk Free. Pro = tak terbatas (-1).
  int get splitMergeRemaining => isPro
      ? -1
      : (FreeLimits.splitMergeMonthly - splitMergeUsed)
          .clamp(0, FreeLimits.splitMergeMonthly);

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    int? splitMergeUsed,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      splitMergeUsed: splitMergeUsed ?? this.splitMergeUsed,
    );
  }
}

/// Fitur yang bisa di-gate.
enum ProFeature {
  split,
  merge,
  sign,
  compress,
  watermark,
  encrypt,
  ocr,
  fullAnnotations,
  cloudSync,
  adFree,
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(this._ref) : super(const SubscriptionState()) {
    _syncWithAuth();
    _ref.listen<AuthState>(authStateProvider, (_, __) => _syncWithAuth());
  }

  final Ref _ref;

  /// Sinkronkan tier berdasarkan akun yang login dan fetch dari API.
  void _syncWithAuth() {
    final auth = _ref.read(authStateProvider);
    final email = auth.email?.toLowerCase().trim();

    // Whitelist check — langsung Pro tanpa API
    if (email != null && kProWhitelistEmails.contains(email)) {
      if (state.tier != SubscriptionTier.pro) {
        state = state.copyWith(tier: SubscriptionTier.pro);
      }
      return;
    }

    // Jika authenticated, fetch subscription dari backend
    if (auth.isAuthenticated) {
      _fetchSubscription();
      _configureRevenueCat(auth.userId!);
    } else {
      // Reset ke free jika logout
      state = const SubscriptionState();
    }
  }

  /// Konfigurasi RevenueCat dengan user.id sebagai appUserId.
  Future<void> _configureRevenueCat(String userId) async {
    try {
      final config = await ConfigService.instance.fetch();
      final apiKey = config.revenueCat.apiKey;
      if (apiKey.isNotEmpty) {
        await RevenueCatService.configure(apiKey, userId);
      }
    } catch (e, st) {
      ErrorReporter.instance.reportError(e, st,
          screen: 'Subscription', action: '_configureRevenueCat');
    }
  }

  /// Fetch subscription status dari backend.
  Future<void> _fetchSubscription() async {
    try {
      final response = await ApiService.instance.get('/subscriptions');
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      final planStr = data['plan'] as String? ?? 'free';
      final tier = (planStr == 'pro' || planStr == 'enterprise')
          ? SubscriptionTier.pro
          : SubscriptionTier.free;

      state =
          SubscriptionState(tier: tier, splitMergeUsed: state.splitMergeUsed);
    } catch (e, st) {
      ErrorReporter.instance.reportError(e, st,
          screen: 'Subscription', action: '_fetchSubscription');
    }
  }

  /// Verifikasi pembelian RevenueCat ke backend setelah purchase sukses.
  /// Backend yang mengaktifkan Pro (server-side), bukan client.
  Future<bool> verifyRevenueCatPurchase({
    required String customerId,
    required String entitlementId,
    String? productId,
  }) async {
    try {
      ErrorReporter.instance.addBreadcrumb('Subscription', 'verify_revenuecat');
      final res = await ApiService.instance.post(
        '/subscriptions/verify-revenuecat',
        data: {
          'customerId': customerId,
          'entitlementId': entitlementId,
          'productId': productId,
        },
      );
      final body = res.data as Map<String, dynamic>;
      if (body['success'] == true) {
        // Re-fetch dari backend agar tier akurat (jangan trust client).
        await _fetchSubscription();
        return state.isPro;
      }
      return false;
    } catch (e, st) {
      ErrorReporter.instance.reportError(e, st,
          screen: 'Subscription',
          action: 'verifyRevenueCatPurchase',
          severity: 'high');
      return false;
    }
  }

  /// Refresh subscription dari backend (publik).
  Future<void> refresh() => _fetchSubscription();

  /// Upgrade ke plan tertentu via backend.
  Future<bool> upgrade(String plan) async {
    try {
      ErrorReporter.instance.addBreadcrumb('Subscription', 'upgrade_$plan');
      await ApiService.instance.post(
        '/subscriptions/upgrade',
        data: {'plan': plan},
      );

      state = state.copyWith(tier: SubscriptionTier.pro);
      return true;
    } catch (e, st) {
      ErrorReporter.instance.reportError(e, st,
          screen: 'Subscription', action: 'upgrade', severity: 'high');
      return false;
    }
  }

  /// Upgrade manual ke Pro (legacy, lokal).
  void upgradeToPro() {
    state = state.copyWith(tier: SubscriptionTier.pro);
  }

  /// Kembali ke Free (mis. untuk testing).
  void downgradeToFree() {
    state = state.copyWith(tier: SubscriptionTier.free);
  }

  /// Cek apakah fitur tertentu tersedia untuk user saat ini.
  bool isFeatureAvailable(ProFeature feature) {
    if (state.isPro) return true;

    // Fitur yang tersedia untuk Free (dengan batasan kuota terpisah).
    switch (feature) {
      case ProFeature.split:
      case ProFeature.merge:
        return state.splitMergeRemaining > 0;
      case ProFeature.sign:
      case ProFeature.compress:
      case ProFeature.watermark:
      case ProFeature.encrypt:
      case ProFeature.ocr:
      case ProFeature.fullAnnotations:
      case ProFeature.cloudSync:
      case ProFeature.adFree:
        return false;
    }
  }

  /// Catat penggunaan satu operasi split/merge, kirim ke backend.
  Future<void> recordSplitMergeUsage() async {
    if (state.isPro) return;

    // Optimistic local update
    state = state.copyWith(splitMergeUsed: state.splitMergeUsed + 1);

    try {
      await ApiService.instance.post(
        '/documents/log-operation',
        data: {'type': 'split_merge'},
      );
    } catch (e, st) {
      ErrorReporter.instance.reportError(e, st,
          screen: 'Subscription', action: 'recordSplitMergeUsage');
    }
  }
}

/// Provider state langganan.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});

/// Helper provider: apakah user Pro.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPro;
});
