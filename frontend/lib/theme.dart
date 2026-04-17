import 'package:flutter/material.dart';

// ── Brand Palette ──────────────────────────────────────────────────────────────

class BVColors {
  BVColors._();

  static const Color primary = Color(0xFFF5A623);
  static const Color onPrimary = Color(0xFF0F1923);
  static const Color primaryLight = Color(0xFFFFB840);
  static const Color accent = Color(0xFF2D9CDB);
  static const Color background = Color(0xFF0F1923);
  static const Color surface = Color(0xFF1A2733);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8B8C8);
  static const Color divider = Color(0xFF2A3A4A);

  // Status / tier colours
  static const Color blocker = Color(0xFFE5383B);
  static const Color scheduleChange = Color(0xFF2D9CDB);
  static const Color materialRequest = Color(0xFF2DC653);
  static const Color progressUpdate = Color(0xFF2DC653);

  // Urgency
  static const Color critical = Color(0xFFE5383B);
  static const Color high = Color(0xFFF5A623);
  static const Color medium = Color(0xFF2D9CDB);
  static const Color low = Color(0xFF2DC653);

  // Task status
  static const Color pending = Color(0xFFA8B8C8);
  static const Color acknowledged = Color(0xFF2D9CDB);
  static const Color inProgress = Color(0xFFF5A623);
  static const Color done = Color(0xFF2DC653);
}

// ── Material 3 Theme ───────────────────────────────────────────────────────────

ThemeData buildVoxTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BVColors.primary,
    onPrimary: Color(0xFF0F1923),
    primaryContainer: BVColors.surface,
    onPrimaryContainer: BVColors.onSurface,
    secondary: BVColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: BVColors.surface,
    onSecondaryContainer: BVColors.onSurface,
    error: BVColors.blocker,
    onError: Colors.white,
    errorContainer: Color(0xFF482327),
    onErrorContainer: Colors.white,
    surface: BVColors.surface,
    onSurface: BVColors.onSurface,
    surfaceContainerHighest: BVColors.background,
    onSurfaceVariant: BVColors.textSecondary,
    outline: BVColors.divider,
    outlineVariant: BVColors.divider,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BVColors.background,
    fontFamily: 'Roboto',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: BVColors.background,
      foregroundColor: BVColors.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: BVColors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: BVColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BVColors.divider, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    // Elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BVColors.primary,
        foregroundColor: BVColors.onPrimary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // Outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BVColors.primary,
        side: const BorderSide(color: BVColors.primary),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BVColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.blocker),
      ),
      labelStyle: const TextStyle(color: BVColors.textSecondary),
      hintStyle: const TextStyle(color: BVColors.textSecondary),
      prefixIconColor: BVColors.textSecondary,
      suffixIconColor: BVColors.textSecondary,
    ),

    // Bottom nav bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BVColors.surface,
      indicatorColor: BVColors.primaryLight.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: BVColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: BVColors.textSecondary,
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: BVColors.primary, size: 24);
        }
        return const IconThemeData(color: BVColors.textSecondary, size: 22);
      }),
      elevation: 3,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: BVColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: BVColors.divider,
      thickness: 1,
      space: 1,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: BVColors.surface,
      contentTextStyle: const TextStyle(color: BVColors.onSurface),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BVColors.primary,
      linearTrackColor: BVColors.divider,
    ),
  );
}
