import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/revenuecat_service.dart';

/// Subscription Screen — RevenueCat-powered upgrade flow.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = true;
  bool _processing = false;

  Future<void> _handlePurchase(AppConfig config) async {
    final auth = ref.read(authStateProvider);
    if (!auth.isAuthenticated) {
      _snack('Silakan login terlebih dahulu');
      return;
    }

    setState(() => _processing = true);
    try {
      // Package identifier — RevenueCat default: '$rc_monthly' / '$rc_annual'
      final packageId = _isYearly ? '\$rc_annual' : '\$rc_monthly';

      final result = await RevenueCatService.purchase(packageId);
      if (!result.success) {
        _snack(result.error ?? 'Pembelian dibatalkan');
        return;
      }

      // Verifikasi ke backend (server-side activation)
      final entitlement = config.revenueCat.entitlementId;
      final hasEntitlement = result.activeEntitlements.contains(entitlement);
      if (!hasEntitlement) {
        _snack('Pembelian belum terverifikasi entitlement');
        return;
      }

      final ok = await ref
          .read(subscriptionProvider.notifier)
          .verifyRevenueCatPurchase(
            customerId: result.customerId ?? auth.userId!,
            entitlementId: entitlement,
            productId: result.productId,
          );

      if (ok && mounted) {
        _snack('🎉 Selamat! Akun kamu sekarang Pro.');
      } else {
        _snack('Verifikasi gagal. Hubungi admin jika sudah membayar.');
      }
    } catch (e) {
      _snack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleRestore(AppConfig config) async {
    setState(() => _processing = true);
    try {
      final result = await RevenueCatService.getCustomerInfo();
      if (result.success &&
          result.activeEntitlements.contains(config.revenueCat.entitlementId)) {
        final ok = await ref
            .read(subscriptionProvider.notifier)
            .verifyRevenueCatPurchase(
              customerId: result.customerId ?? '',
              entitlementId: config.revenueCat.entitlementId,
            );
        _snack(ok ? 'Pembelian dipulihkan ✓' : 'Tidak ada langganan aktif');
      } else {
        _snack('Tidak ada pembelian untuk dipulihkan');
      }
    } catch (e) {
      _snack('Gagal restore: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(isProProvider);
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade ke Pro')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (config) => _buildContent(theme, isPro, config),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isPro, AppConfig config) {
    final priceLabel =
        _isYearly ? config.pricing.yearlyLabel : config.pricing.monthlyLabel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pro badge header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white),
                      SizedBox(width: 8),
                      Text('PRO',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Buka Semua Fitur',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Akses tanpa batas ke semua fitur premium',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (isPro)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Kamu sudah Pro! Semua fitur terbuka.',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else ...[
            // Monthly/Yearly toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  _toggleTab('Bulanan', !_isYearly,
                      () => setState(() => _isYearly = false)),
                  _toggleTab('Tahunan', _isYearly,
                      () => setState(() => _isYearly = true),
                      badge: 'Hemat'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(priceLabel,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],

          // Features (dari config)
          ..._buildFeatures(config),
          const SizedBox(height: 24),

          if (!isPro) ...[
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _processing ? null : () => _handlePurchase(config),
                child: _processing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Langganan Sekarang'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _processing ? null : () => _handleRestore(config),
                child: const Text('Pulihkan Pembelian'),
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Langganan diperpanjang otomatis kecuali dibatalkan. '
            'Batalkan kapan saja di pengaturan akun.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppTheme.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap,
      {String? badge}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : null,
                      fontWeight: FontWeight.w600)),
              if (badge != null && active) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeatures(AppConfig config) {
    // Mapping fitur ke label & icon
    const featureMeta = {
      'split': ['Split & Merge tanpa batas', Icons.all_inclusive],
      'sign': ['Tanda tangan digital', Icons.draw],
      'encrypt': ['Enkripsi PDF', Icons.lock],
      'compress': ['Kompresi PDF', Icons.compress],
      'watermark': ['Watermark kustom', Icons.branding_watermark],
      'ocr': ['OCR (teks dari scan)', Icons.document_scanner],
      'annotations': ['Anotasi lengkap', Icons.edit],
      'ad_free': ['Tanpa iklan', Icons.block],
    };

    final widgets = <Widget>[];
    featureMeta.forEach((key, meta) {
      final enabled = config.proFeatures[key] ?? true;
      if (!enabled) return;
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(meta[1] as IconData,
                  color: AppTheme.successColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(meta[0] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.check_circle, color: AppTheme.successColor),
          ],
        ),
      ));
    });
    return widgets;
  }
}
