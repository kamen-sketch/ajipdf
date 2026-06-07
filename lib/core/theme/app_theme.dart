import 'package:flutter/material.dart';

/// Pilihan color scheme yang tersedia.
enum AppColorScheme {
  oceanBlue,
  forestGreen,
  sunsetOrange,
  royalPurple,
  midnight,
  roseGold,
}

extension AppColorSchemeInfo on AppColorScheme {
  String get label => switch (this) {
        AppColorScheme.oceanBlue => 'Ocean Blue',
        AppColorScheme.forestGreen => 'Forest Green',
        AppColorScheme.sunsetOrange => 'Sunset Orange',
        AppColorScheme.royalPurple => 'Royal Purple',
        AppColorScheme.midnight => 'Midnight',
        AppColorScheme.roseGold => 'Rose Gold',
      };

  Color get primary => switch (this) {
        AppColorScheme.oceanBlue => const Color(0xFF2563EB),
        AppColorScheme.forestGreen => const Color(0xFF059669),
        AppColorScheme.sunsetOrange => const Color(0xFFEA580C),
        AppColorScheme.royalPurple => const Color(0xFF7C3AED),
        AppColorScheme.midnight => const Color(0xFF334155),
        AppColorScheme.roseGold => const Color(0xFFDB2777),
      };

  Color get primaryLight => switch (this) {
        AppColorScheme.oceanBlue => const Color(0xFF3B82F6),
        AppColorScheme.forestGreen => const Color(0xFF10B981),
        AppColorScheme.sunsetOrange => const Color(0xFFF97316),
        AppColorScheme.royalPurple => const Color(0xFF8B5CF6),
        AppColorScheme.midnight => const Color(0xFF475569),
        AppColorScheme.roseGold => const Color(0xFFEC4899),
      };

  Color get primaryDark => switch (this) {
        AppColorScheme.oceanBlue => const Color(0xFF1D4ED8),
        AppColorScheme.forestGreen => const Color(0xFF047857),
        AppColorScheme.sunsetOrange => const Color(0xFFC2410C),
        AppColorScheme.royalPurple => const Color(0xFF6D28D9),
        AppColorScheme.midnight => const Color(0xFF1E293B),
        AppColorScheme.roseGold => const Color(0xFFBE185D),
      };

  Color get secondary => switch (this) {
        AppColorScheme.oceanBlue => const Color(0xFF7C3AED),
        AppColorScheme.forestGreen => const Color(0xFF0891B2),
        AppColorScheme.sunsetOrange => const Color(0xFFDC2626),
        AppColorScheme.royalPurple => const Color(0xFF2563EB),
        AppColorScheme.midnight => const Color(0xFF6366F1),
        AppColorScheme.roseGold => const Color(0xFF9333EA),
      };

  /// Gradient untuk header dashboard.
  List<Color> get gradient => [primary, primaryLight];
}

/// Application theme configuration
/// Supports light/dark themes + multiple color schemes
class AppTheme {
  AppTheme._();

  // ============== Default Colors (Ocean Blue fallback) ==============

  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color secondaryColor = Color(0xFF7C3AED);
  static const Color secondaryLight = Color(0xFF8B5CF6);
  static const Color secondaryDark = Color(0xFF6D28D9);

  static const Color accentColor = Color(0xFF06B6D4);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);

  // Neutral colors
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);

  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF111827);
  static const Color darkSurfaceColor = Color(0xFF1F2937);
  static const Color darkCardColor = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFFD1D5DB);
  static const Color darkTextHint = Color(0xFF9CA3AF);

  // ============== Typography ==============

  // Menggunakan font bawaan system (bebas lisensi).
  static const String? fontFamily = null;

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    displayMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    displaySmall: TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  );

  // ============== Build Themes from Color Scheme ==============

  static ThemeData lightThemeFrom(AppColorScheme scheme) {
    final p = scheme.primary;
    final pl = scheme.primaryLight;
    final s = scheme.secondary;
    return _buildLight(p, pl, scheme.primaryDark, s);
  }

  static ThemeData darkThemeFrom(AppColorScheme scheme) {
    final pl = scheme.primaryLight;
    final pd = scheme.primaryDark;
    final s = scheme.secondary;
    return _buildDark(pl, pd, s);
  }

  // Default themes (Ocean Blue)
  static ThemeData get lightTheme => lightThemeFrom(AppColorScheme.oceanBlue);
  static ThemeData get darkTheme => darkThemeFrom(AppColorScheme.oceanBlue);

  // ============== Light Theme Builder ==============

  static ThemeData _buildLight(
      Color primary, Color primaryLt, Color primaryDk, Color secondary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLt,
        onPrimaryContainer: textPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accentColor,
        onTertiary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        errorContainer: const Color(0xFFFEE2E2),
        onErrorContainer: errorColor,
        surface: surfaceColor,
        onSurface: textPrimary,
        surfaceContainerHighest: backgroundColor,
        onSurfaceVariant: textSecondary,
        outline: const Color(0xFFE5E7EB),
        outlineVariant: const Color(0xFFF3F4F6),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: primary, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textHint),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primary.withValues(alpha: 0.1),
        elevation: 0,
        height: 64,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        selectedColor: primary.withValues(alpha: 0.1),
        labelStyle: textTheme.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E7EB), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: textSecondary, size: 24),
      textTheme:
          textTheme.apply(bodyColor: textPrimary, displayColor: textPrimary),
    );
  }

  // ============== Dark Theme Builder ==============

  static ThemeData _buildDark(
      Color primaryLt, Color primaryDk, Color secondary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryLt,
        onPrimary: Colors.white,
        primaryContainer: primaryDk,
        onPrimaryContainer: darkTextPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accentColor,
        onTertiary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        errorContainer: const Color(0xFF7F1D1D),
        onErrorContainer: const Color(0xFFFEE2E2),
        surface: darkSurfaceColor,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkBackgroundColor,
        onSurfaceVariant: darkTextSecondary,
        outline: const Color(0xFF374151),
        outlineVariant: const Color(0xFF1F2937),
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkTextPrimary,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge
            ?.copyWith(color: darkTextPrimary, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF374151), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLt,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLt,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: primaryLt, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLt,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLt,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF374151))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF374151))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryLt, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorColor, width: 2)),
        labelStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextHint),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurfaceColor,
        indicatorColor: primaryLt.withValues(alpha: 0.1),
        elevation: 0,
        height: 64,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCardColor,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCardColor,
        selectedColor: primaryLt.withValues(alpha: 0.1),
        labelStyle: textTheme.bodySmall?.copyWith(color: darkTextPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
          color: Color(0xFF374151), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: darkTextSecondary, size: 24),
      textTheme: textTheme.apply(
          bodyColor: darkTextPrimary, displayColor: darkTextPrimary),
    );
  }
}
