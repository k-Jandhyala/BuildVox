import 'package:flutter/material.dart';

// ── Brand Palette ──────────────────────────────────────────────────────────────

class BVColors {
  BVColors._();

  static const Color primary = Color(0xFF1D4ED8);       // Professional blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color accent = Color(0xFFF59E0B);         // Amber — construction cue
  static const Color background = Color(0xFFF1F5F9);     // Slate-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1E293B);      // Slate-800
  static const Color textSecondary = Color(0xFF64748B);  // Slate-500
  static const Color divider = Color(0xFFE2E8F0);        // Slate-200

  // Status / tier colours
  static const Color blocker = Color(0xFFDC2626);        // Red-600
  static const Color scheduleChange = Color(0xFFEA580C); // Orange-600
  static const Color materialRequest = Color(0xFF7C3AED);// Violet-600
  static const Color progressUpdate = Color(0xFF059669); // Emerald-600

  // Urgency
  static const Color critical = Color(0xFF991B1B);
  static const Color high = Color(0xFFDC2626);
  static const Color medium = Color(0xFFF59E0B);
  static const Color low = Color(0xFF10B981);

  // Task status
  static const Color pending = Color(0xFF94A3B8);
  static const Color acknowledged = Color(0xFF3B82F6);
  static const Color inProgress = Color(0xFFF59E0B);
  static const Color done = Color(0xFF10B981);
}

// ── Material 3 Theme ───────────────────────────────────────────────────────────

ThemeData buildVoxTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BVColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: BVColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFEF3C7),
    onSecondaryContainer: Color(0xFF78350F),
    error: BVColors.blocker,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: BVColors.surface,
    onSurface: BVColors.onSurface,
    surfaceContainerHighest: BVColors.background,
    onSurfaceVariant: BVColors.textSecondary,
    outline: BVColors.divider,
    outlineVariant: Color(0xFFCBD5E1),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BVColors.background,
    fontFamily: 'Roboto',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: BVColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
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
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BVColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BVColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BVColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BVColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BVColors.blocker),
      ),
      labelStyle: const TextStyle(color: BVColors.textSecondary),
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
    ),
  );
}
