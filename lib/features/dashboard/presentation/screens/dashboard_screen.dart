import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/providers/document_provider.dart';
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
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Add PDF'),
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
            leading: Icon(Icons.logout, color: AppTheme.errorColor),
            title:
                Text('Sign Out', style: TextStyle(color: AppTheme.errorColor)),
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
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Open from Device'),
                subtitle: const Text('Pilih file PDF dari perangkat'),
                onTap: () async {
                  Navigator.pop(context);
                  await _openFromDevice();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Open from Cloud'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Integrasi cloud sedang disiapkan.')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primaryColor),
                title: const Text('Scan Document'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanner segera hadir.')),
                  );
                },
              ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back!',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            sub.isPro
                ? 'Akun Pro aktif - semua fitur terbuka'
                : 'Sisa kuota split/merge: ${sub.splitMergeRemaining}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Text('Quick Actions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
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
                onTap: () => context.push('/editor?operation=sign'),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_outlined, size: 72, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('Cloud Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hubungkan Google Drive atau iCloud untuk sinkronisasi dokumen. Fitur ini sedang disiapkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Integrasi cloud segera hadir.')),
              );
            },
            icon: const Icon(Icons.add_link),
            label: const Text('Connect Cloud'),
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
              style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
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
                leading: Icon(Icons.logout, color: AppTheme.errorColor),
                title: Text('Sign Out',
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
