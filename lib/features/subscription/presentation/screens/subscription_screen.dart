import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/subscription_provider.dart';

/// Subscription Screen for managing Pro subscription
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = true;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = ref.watch(isProProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pro badge
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unlock All Features',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get unlimited access to all premium features',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Pricing toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isYearly = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isYearly ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Monthly',
                          style: TextStyle(
                            color: !_isYearly ? Colors.white : null,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isYearly = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isYearly ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Yearly',
                              style: TextStyle(
                                color: _isYearly ? Colors.white : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isYearly) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-17%',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Price display
            Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _isYearly ? '\$4.99' : '\$4.99',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: _isYearly ? '/month' : '/month',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isYearly)
              Center(
                child: Text(
                  'Billed \$59.88 annually',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            
            // Features list
            _buildFeatureItem(
              icon: Icons.all_inclusive,
              title: 'Unlimited Split & Merge',
              subtitle: 'No monthly limits on document operations',
            ),
            _buildFeatureItem(
              icon: Icons.draw,
              title: 'Digital Signature',
              subtitle: 'Sign documents with custom signatures',
            ),
            _buildFeatureItem(
              icon: Icons.lock,
              title: 'PDF Encryption',
              subtitle: 'Protect documents with passwords',
            ),
            _buildFeatureItem(
              icon: Icons.compress,
              title: 'PDF Compression',
              subtitle: 'Reduce file size for easy sharing',
            ),
            _buildFeatureItem(
              icon: Icons.branding_watermark,
              title: 'Watermarks',
              subtitle: 'Add custom watermarks to documents',
            ),
            _buildFeatureItem(
              icon: Icons.document_scanner,
              title: 'OCR',
              subtitle: 'Convert scanned documents to searchable text',
            ),
            _buildFeatureItem(
              icon: Icons.edit,
              title: 'Full Annotations',
              subtitle: 'All annotation types without limits',
            ),
            _buildFeatureItem(
              icon: Icons.block,
              title: 'Ad-Free Experience',
              subtitle: 'No interruptions while you work',
            ),
            const SizedBox(height: 32),
            
            // Subscribe button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isPro
                    ? null
                    : () {
                        ref.read(subscriptionProvider.notifier).upgradeToPro();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Selamat! Akun kamu sekarang Pro. Semua fitur terbuka.'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      },
                child: Text(isPro ? 'Pro Sudah Aktif' : 'Subscribe Now'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Restore purchases
            Center(
              child: TextButton(
                onPressed: () {
                  ref.read(subscriptionProvider.notifier).upgradeToPro();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pembelian dipulihkan.')),
                  );
                },
                child: const Text('Restore Purchases'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Terms
            Text(
              'Subscriptions auto-renew unless cancelled. Cancel anytime in your account settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.successColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppTheme.successColor),
        ],
      ),
    );
  }
}
