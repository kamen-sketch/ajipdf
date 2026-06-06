import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Sisa kuota split/merge untuk Free. Pro = tak terbatas.
  int get splitMergeRemaining =>
      isPro ? -1 : (FreeLimits.splitMergeMonthly - splitMergeUsed).clamp(0, FreeLimits.splitMergeMonthly);

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

  /// Sinkronkan tier berdasarkan akun yang login.
  void _syncWithAuth() {
    final auth = _ref.read(authStateProvider);
    final email = auth.email?.toLowerCase().trim();

    if (email != null && kProWhitelistEmails.contains(email)) {
      if (state.tier != SubscriptionTier.pro) {
        state = state.copyWith(tier: SubscriptionTier.pro);
      }
    }
  }

  /// Upgrade manual ke Pro (mis. setelah pembelian berhasil).
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

  /// Catat penggunaan satu operasi split/merge (Free saja).
  void recordSplitMergeUsage() {
    if (state.isPro) return;
    state = state.copyWith(splitMergeUsed: state.splitMergeUsed + 1);
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
