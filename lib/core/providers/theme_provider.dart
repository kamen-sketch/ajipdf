import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';
import '../theme/app_theme.dart';

/// State untuk personalisasi tampilan.
class AppPersonalization {
  AppPersonalization({
    this.colorScheme = AppColorScheme.oceanBlue,
    this.themeMode = ThemeMode.system,
    this.dashboardWallpaper,
  });

  final AppColorScheme colorScheme;
  final ThemeMode themeMode;

  /// Bytes gambar wallpaper dashboard (disimpan di Hive).
  /// Hanya di native (Android/iOS) — web tidak support pick photo untuk ini.
  final Uint8List? dashboardWallpaper;

  AppPersonalization copyWith({
    AppColorScheme? colorScheme,
    ThemeMode? themeMode,
    Uint8List? dashboardWallpaper,
    bool clearWallpaper = false,
  }) {
    return AppPersonalization(
      colorScheme: colorScheme ?? this.colorScheme,
      themeMode: themeMode ?? this.themeMode,
      dashboardWallpaper: clearWallpaper
          ? null
          : (dashboardWallpaper ?? this.dashboardWallpaper),
    );
  }
}

class AppPersonalizationNotifier extends StateNotifier<AppPersonalization> {
  AppPersonalizationNotifier() : super(AppPersonalization()) {
    _load();
  }

  void _load() {
    final hive = HiveService.instance;
    final schemeName =
        hive.getPreference<String>('color_scheme') ?? 'oceanBlue';
    final modeName = hive.getPreference<String>('theme_mode') ?? 'system';
    final wallpaper = hive.preferencesBox.get('dashboard_wallpaper');

    AppColorScheme scheme;
    try {
      scheme = AppColorScheme.values.firstWhere((e) => e.name == schemeName);
    } catch (_) {
      scheme = AppColorScheme.oceanBlue;
    }

    ThemeMode mode;
    switch (modeName) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      default:
        mode = ThemeMode.system;
    }

    Uint8List? wp;
    if (wallpaper != null && wallpaper is Uint8List && wallpaper.isNotEmpty) {
      wp = wallpaper;
    }

    state = AppPersonalization(
      colorScheme: scheme,
      themeMode: mode,
      dashboardWallpaper: wp,
    );
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(colorScheme: scheme);
    await HiveService.instance.savePreference('color_scheme', scheme.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await HiveService.instance.savePreference('theme_mode', mode.name);
  }

  /// Set wallpaper dari bytes gambar (hanya native).
  Future<void> setDashboardWallpaper(Uint8List? bytes) async {
    if (bytes != null && bytes.isNotEmpty) {
      state = state.copyWith(dashboardWallpaper: bytes);
      await HiveService.instance.preferencesBox
          .put('dashboard_wallpaper', bytes);
    } else {
      state = state.copyWith(clearWallpaper: true);
      await HiveService.instance.preferencesBox.delete('dashboard_wallpaper');
    }
  }

  /// Apakah platform mendukung wallpaper (non-web).
  bool get canSetWallpaper => !kIsWeb;
}

final appPersonalizationProvider =
    StateNotifierProvider<AppPersonalizationNotifier, AppPersonalization>(
        (ref) => AppPersonalizationNotifier());

/// Convenience providers
final currentColorSchemeProvider = Provider<AppColorScheme>(
    (ref) => ref.watch(appPersonalizationProvider).colorScheme);
final currentThemeModeProvider = Provider<ThemeMode>(
    (ref) => ref.watch(appPersonalizationProvider).themeMode);
final dashboardWallpaperProvider = Provider<Uint8List?>(
    (ref) => ref.watch(appPersonalizationProvider).dashboardWallpaper);
