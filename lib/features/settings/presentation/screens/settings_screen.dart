import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';

/// Settings Screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Manage your profile information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Subscription'),
            subtitle: const Text('Free Plan • Upgrade to Pro'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/subscription'),
          ),
          
          const Divider(),
          
          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: Text(_getThemeModeLabel(themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).state = mode;
                }
              },
            ),
          ),
          
          const Divider(),
          
          // Document Settings
          _buildSectionHeader(context, 'Document Settings'),
          ListTile(
            leading: const Icon(Icons.zoom_in_outlined),
            title: const Text('Default Zoom Level'),
            subtitle: const Text('100%'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show zoom level picker
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined),
            title: const Text('Auto-save'),
            subtitle: const Text('Automatically save changes'),
            value: true,
            onChanged: (value) {
              // TODO: Update auto-save setting
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
              onPressed: () {
                // TODO: Connect Google Drive
              },
              child: const Text('Connect'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('iCloud'),
            subtitle: const Text('Not connected'),
            trailing: TextButton(
              onPressed: () {
                // TODO: Connect iCloud
              },
              child: const Text('Connect'),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: const Text('Auto-sync'),
            subtitle: const Text('Sync documents automatically'),
            value: false,
            onChanged: (value) {
              // TODO: Update auto-sync setting
            },
          ),
          
          const Divider(),
          
          // Support Section
          _buildSectionHeader(context, 'Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open help center
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send Feedback'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open feedback form
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate App'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open app store rating
            },
          ),
          
          const Divider(),
          
          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open terms
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          
          const SizedBox(height: 24),
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
}
