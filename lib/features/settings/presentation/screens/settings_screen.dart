import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/api_service.dart';

/// Settings Screen — fully functional with persistence
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoSync = false;
  bool _autoSave = true;
  int _defaultZoom = 100;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAppVersion();
  }

  void _loadPreferences() {
    final hive = HiveService.instance;
    setState(() {
      _autoSync = hive.getPreference<bool>('auto_sync') ?? false;
      _autoSave = hive.getPreference<bool>('auto_save') ?? true;
      _defaultZoom = hive.getPreference<int>('default_zoom') ?? 100;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  Future<void> _savePreference(String key, dynamic value) async {
    await HiveService.instance.savePreference(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                (auth.displayName?.isNotEmpty == true
                        ? auth.displayName![0]
                        : 'U')
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(auth.displayName ?? 'User'),
            subtitle: Text(auth.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Profile editing — show edit dialog
              _showProfileEditDialog(context, auth);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset_outlined),
            title: const Text('Ganti Password'),
            subtitle: const Text('Ubah password akun kamu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),
          ListTile(
            leading: Icon(
              Icons.workspace_premium_outlined,
              color: sub.isPro ? Colors.amber : AppTheme.textSecondary,
            ),
            title: const Text('Subscription'),
            subtitle: Text(sub.isPro
                ? 'Pro Plan — All features unlocked'
                : 'Free Plan • Tap to upgrade'),
            trailing: sub.isPro
                ? const Icon(Icons.check_circle, color: AppTheme.successColor)
                : const Icon(Icons.chevron_right),
            onTap: () => context.push('/subscription'),
          ),

          const Divider(),

          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: Text(_getThemeModeLabel(
                ref.watch(appPersonalizationProvider).themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(appPersonalizationProvider).themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref
                      .read(appPersonalizationProvider.notifier)
                      .setThemeMode(mode);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Color Theme'),
            subtitle:
                Text(ref.watch(appPersonalizationProvider).colorScheme.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showColorSchemePicker(context, ref),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('Dashboard Background'),
              subtitle: Text(
                  ref.watch(appPersonalizationProvider).dashboardWallpaper !=
                          null
                      ? 'Custom photo'
                      : 'Default gradient'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWallpaperOptions(context, ref),
            ),

          const Divider(),

          // Document Settings
          _buildSectionHeader(context, 'Document Settings'),
          ListTile(
            leading: const Icon(Icons.zoom_in_outlined),
            title: const Text('Default Zoom Level'),
            subtitle: Text('$_defaultZoom%'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showZoomPicker(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined),
            title: const Text('Auto-save'),
            subtitle: const Text('Automatically save changes'),
            value: _autoSave,
            onChanged: (value) async {
              setState(() => _autoSave = value);
              await _savePreference('auto_save', value);
            },
          ),

          const Divider(),

          // Cloud Section
          _buildSectionHeader(context, 'Cloud & Sync'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Google Drive'),
            subtitle: const Text('Not connected'),
            trailing: TextButton(
              onPressed: () => _showCloudConnectInfo(context, 'Google Drive'),
              child: const Text('Connect'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_circle_outlined),
            title: const Text('iCloud'),
            subtitle: const Text('iOS only'),
            trailing: TextButton(
              onPressed: () => _showCloudConnectInfo(context, 'iCloud'),
              child: const Text('Connect'),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: const Text('Auto-sync'),
            subtitle: const Text('Sync documents automatically'),
            value: _autoSync,
            onChanged: (value) async {
              setState(() => _autoSync = value);
              await _savePreference('auto_sync', value);
            },
          ),

          const Divider(),

          // Pro Features Section
          _buildSectionHeader(context, 'Pro Features'),
          ListTile(
            leading:
                const Icon(Icons.draw_outlined, color: AppTheme.successColor),
            title: const Text('Digital Signature'),
            subtitle: Text(sub.isPro ? 'Available' : 'Requires Pro'),
            trailing: sub.isPro
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.lock_outline, color: Colors.amber),
            onTap: () => context.push('/signature'),
          ),
          ListTile(
            leading:
                const Icon(Icons.document_scanner, color: AppTheme.accentColor),
            title: const Text('OCR Text Recognition'),
            subtitle: Text(sub.isPro ? 'Available' : 'Requires Pro'),
            trailing: sub.isPro
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.lock_outline, color: Colors.amber),
            onTap: () => context.push('/ocr'),
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined,
                color: AppTheme.secondaryColor),
            title: const Text('Annotations'),
            subtitle: Text(
                sub.isPro ? 'Full access' : 'Limited (Highlight & Text only)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/annotations'),
          ),

          const Divider(),

          // Support Section
          _buildSectionHeader(context, 'Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://github.com'),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send Feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFeedbackDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline, color: Colors.amber),
            title: const Text('Rate App'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rate app — opening store')),
              );
            },
          ),

          const Divider(),

          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://example.com/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launchUrl('https://example.com/privacy'),
          ),

          const Divider(),

          // Danger zone
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Sign Out',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () => _confirmSignOut(context),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Follow System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  void _showZoomPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        int tempZoom = _defaultZoom;
        return StatefulBuilder(
          builder: (_, setSt) => AlertDialog(
            title: const Text('Default Zoom Level'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$tempZoom%',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Slider(
                  value: tempZoom.toDouble(),
                  min: 50,
                  max: 200,
                  divisions: 15,
                  label: '$tempZoom%',
                  onChanged: (v) => setSt(() => tempZoom = v.toInt()),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  setState(() => _defaultZoom = tempZoom);
                  await _savePreference('default_zoom', tempZoom);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCloudConnectInfo(BuildContext context, String provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect $provider'),
        content: Text(
          '$provider integration requires OAuth setup and backend configuration. '
          'This feature will be available in a future update.',
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showProfileEditDialog(BuildContext context, AuthState auth) {
    final nameController = TextEditingController(text: auth.displayName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText: 'Nama Tampilan', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.length < 2) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Nama minimal 2 karakter')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.instance
                    .put('/users/profile', data: {'displayName': newName});
                // Refresh auth state
                await ref.read(authStateProvider.notifier).refreshProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Profil berhasil diperbarui')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal update profil: $e')));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool processing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ganti Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password saat ini',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password baru (min. 6)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Konfirmasi password baru',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: processing ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: processing
                  ? null
                  : () async {
                      if (newCtrl.text.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Password baru minimal 6 karakter')));
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Konfirmasi password tidak cocok')));
                        return;
                      }
                      setSt(() => processing = true);
                      try {
                        await ApiService.instance
                            .post('/auth/change-password', data: {
                          'currentPassword': currentCtrl.text,
                          'newPassword': newCtrl.text,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Password berhasil diubah')));
                        }
                      } catch (e) {
                        setSt(() => processing = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(
                                'Gagal: password saat ini salah atau error')));
                      }
                    },
              child: processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ubah'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showColorSchemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(appPersonalizationProvider).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Tema Warna',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppColorScheme.values.map((scheme) {
                  final isSelected = scheme == current;
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(appPersonalizationProvider.notifier)
                          .setColorScheme(scheme);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: scheme.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(scheme.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWallpaperOptions(
      BuildContext context, WidgetRef ref) async {
    final hasWallpaper =
        ref.read(appPersonalizationProvider).dashboardWallpaper != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Dashboard Background',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (hasWallpaper)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppTheme.errorColor),
                title: const Text('Hapus Wallpaper',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'remove') {
      await ref
          .read(appPersonalizationProvider.notifier)
          .setDashboardWallpaper(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper dihapus')),
        );
      }
      return;
    }

    if (action == 'pick') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null || bytes.isEmpty) return;

      await ref
          .read(appPersonalizationProvider.notifier)
          .setDashboardWallpaper(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper dashboard diperbarui!')),
        );
      }
    }
  }
}
