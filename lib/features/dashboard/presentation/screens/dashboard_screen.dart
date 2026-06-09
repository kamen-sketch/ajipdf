import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/providers/document_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/config_service.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_document_card.dart';

/// Dashboard screen - main entry point after login dengan bottom navigation berfungsi.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  bool _promoShown = false;

  @override
  void initState() {
    super.initState();
    // Cek promo dari config setelah frame pertama.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPromo());
  }

  Future<void> _maybeShowPromo() async {
    if (_promoShown) return;
    final config = await ConfigService.instance.fetch();
    final promo = config.promo;
    if (!promo.isActive || !mounted) return;
    // Jangan ganggu user Pro dengan promo upgrade.
    if (ref.read(isProProvider)) return;

    _promoShown = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(promo.title.isEmpty ? 'Promo Spesial!' : promo.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            if (promo.discountPercent > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Diskon ${promo.discountPercent}%',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 12),
            Text(promo.message,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/subscription');
            },
            child: const Text('Lihat Penawaran'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    final titles = ['PDF Enterprise Suite', 'Documents', 'Cloud', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: _buildDrawer(context, authState),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(onOpenAdd: () => _showAddOptions(context)),
          const _DocumentsTab(),
          const _CloudTab(),
          const _ProfileTab(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showAddOptions(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Cloud',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthState authState) {
    final theme = Theme.of(context);
    final isPro = ref.watch(isProProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(
                        authState.displayName?.substring(0, 1).toUpperCase() ??
                            'U',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium,
                                size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('PRO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  authState.displayName ?? 'User',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  authState.email ?? '',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (!isPro)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Upgrade to Pro'),
              onTap: () {
                Navigator.pop(context);
                context.push('/subscription');
              },
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help Center segera hadir.')),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Sign Out',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text('Tambah Dokumen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_outlined,
                    color: AppTheme.primaryColor),
                title: const Text('Buka dari Perangkat'),
                subtitle: const Text('Pilih file PDF yang sudah ada'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openFromDevice();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.successColor),
                title: const Text('Scan to PDF'),
                subtitle: const Text('Foto dokumen dan konversi ke PDF'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/scan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined,
                    color: AppTheme.infoColor),
                title: const Text('Buka dari Cloud'),
                subtitle: const Text('Google Drive, iCloud'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Integrasi cloud sedang disiapkan.')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFromDevice() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    ref.read(activeDocumentProvider.notifier).state = doc;
    if (mounted) context.push('/viewer');
  }
}

/// ---------- HOME TAB ----------
class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onOpenAdd});

  final VoidCallback onOpenAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sub = ref.watch(subscriptionProvider);
    final wallpaper = ref.watch(dashboardWallpaperProvider);
    final scheme = ref.watch(currentColorSchemeProvider);
    final auth = ref.watch(authStateProvider);

    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── GREETING CARD ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: scheme.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        (auth.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${auth.displayName ?? 'User'}!',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          const SizedBox(height: 2),
                          Text(
                            sub.isPro
                                ? '⭐ Pro — Semua fitur terbuka'
                                : 'Free • ${sub.splitMergeRemaining} kuota tersisa',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (!sub.isPro)
                      OutlinedButton(
                        onPressed: () => context.push('/subscription'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Upgrade'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Quick Actions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              QuickActionCard(
                icon: Icons.visibility_outlined,
                label: 'View PDF',
                color: AppTheme.primaryColor,
                onTap: () => _openViewer(context, ref),
              ),
              QuickActionCard(
                icon: Icons.call_split_outlined,
                label: 'Split PDF',
                color: AppTheme.secondaryColor,
                onTap: () => context.push('/editor?operation=split'),
              ),
              QuickActionCard(
                icon: Icons.merge_type_outlined,
                label: 'Merge PDF',
                color: AppTheme.accentColor,
                onTap: () => context.push('/editor?operation=merge'),
              ),
              QuickActionCard(
                icon: Icons.draw_outlined,
                label: 'Sign PDF',
                color: AppTheme.successColor,
                onTap: () => context.push('/signature'),
              ),
              QuickActionCard(
                icon: Icons.compress_outlined,
                label: 'Compress',
                color: AppTheme.warningColor,
                onTap: () => context.push('/editor?operation=compress'),
              ),
              QuickActionCard(
                icon: Icons.lock_outline,
                label: 'Lock PDF',
                color: AppTheme.errorColor,
                onTap: () => context.push('/editor?operation=encrypt'),
              ),
              QuickActionCard(
                icon: Icons.branding_watermark_outlined,
                label: 'Watermark',
                color: AppTheme.infoColor,
                onTap: () => context.push('/editor?operation=watermark'),
              ),
              QuickActionCard(
                icon: Icons.sticky_note_2_outlined,
                label: 'Annotate',
                color: const Color(0xFF6366F1),
                onTap: () => context.push('/annotations'),
              ),
              QuickActionCard(
                icon: Icons.document_scanner,
                label: 'OCR',
                color: const Color(0xFF0891B2),
                onTap: () => context.push('/ocr'),
              ),
              QuickActionCard(
                icon: Icons.rotate_90_degrees_ccw_outlined,
                label: 'Rotate/Reorder',
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/rotate-reorder'),
              ),
              QuickActionCard(
                icon: Icons.workspace_premium_outlined,
                label: sub.isPro ? 'Pro Active' : 'Go Pro',
                color: Colors.amber.shade700,
                onTap: () => context.push('/subscription'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Recent Documents',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const _RecentDocuments(),
        ],
      ),
    );

    // Wrap with wallpaper background if set (hanya native, bukan web).
    if (wallpaper != null && !kIsWeb) {
      return Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.memory(wallpaper, fit: BoxFit.cover),
            ),
          ),
          content,
        ],
      );
    }
    return content;
  }

  Future<void> _openViewer(BuildContext context, WidgetRef ref) async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    ref.read(activeDocumentProvider.notifier).state = doc;
    if (context.mounted) context.push('/viewer');
  }
}

class _RecentDocuments extends ConsumerWidget {
  const _RecentDocuments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);

    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            const Icon(Icons.folder_open_outlined,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('No documents yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Add a PDF to get started',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return RecentDocumentCard(
          title: doc.name,
          pageCount: 0,
          lastModified: doc.lastOpened,
          onTap: () {
            ref.read(activeDocumentProvider.notifier).state = doc;
            context.push('/viewer');
          },
        );
      },
    );
  }
}

/// ---------- DOCUMENTS TAB ----------
class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 72, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text('Belum ada dokumen',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Gunakan tombol Add PDF untuk membuka dokumen',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return RecentDocumentCard(
          title: doc.name,
          pageCount: 0,
          lastModified: doc.lastOpened,
          onTap: () {
            ref.read(activeDocumentProvider.notifier).state = doc;
            context.push('/viewer');
          },
        );
      },
    );
  }
}

/// ---------- CLOUD TAB ----------
class _CloudTab extends StatelessWidget {
  const _CloudTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        // Cloud providers
        Text('Cloud Providers',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildCloudProviderCard(
          context,
          icon: Icons.drive_file_rename_outline,
          name: 'Google Drive',
          description: 'Connect your Google Drive account',
          color: const Color(0xFF4285F4),
          onConnect: () => _showConnectInfo(context, 'Google Drive'),
        ),
        const SizedBox(height: 8),
        _buildCloudProviderCard(
          context,
          icon: Icons.cloud,
          name: 'iCloud',
          description: 'Connect your iCloud account (iOS only)',
          color: const Color(0xFF007AFF),
          onConnect: () => _showConnectInfo(context, 'iCloud'),
        ),
        const SizedBox(height: 24),
        Text('Sync Settings',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
                title: const Text('Manual Sync'),
                subtitle: const Text('Sync all documents now'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Cloud sync requires provider connection.')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Sync Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cloud sync will be fully available once you connect a provider. OAuth credentials need to be configured.',
                  style: TextStyle(color: AppTheme.infoColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCloudProviderCard(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String description,
    required Color color,
    required VoidCallback onConnect,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: OutlinedButton(
          onPressed: onConnect,
          child: const Text('Connect'),
        ),
      ),
    );
  }

  void _showConnectInfo(BuildContext context, String provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect $provider'),
        content: Text(
          '$provider integration requires configuring OAuth credentials. '
          'Go to Settings to connect your $provider account.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}

/// ---------- PROFILE TAB ----------
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final sub = ref.watch(subscriptionProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              auth.displayName?.substring(0, 1).toUpperCase() ?? 'U',
              style:
                  theme.textTheme.displaySmall?.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(auth.displayName ?? 'User',
              style: theme.textTheme.headlineSmall),
        ),
        Center(
          child: Text(auth.email ?? '',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: sub.isPro ? Colors.amber : AppTheme.textHint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sub.isPro ? 'PRO MEMBER' : 'FREE PLAN',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Subscription'),
                subtitle: Text(sub.isPro ? 'Pro - semua fitur' : 'Free Plan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/subscription'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                title: const Text('Sign Out',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
