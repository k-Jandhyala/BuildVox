import 'package:flutter/material.dart';

// ── Brand Palette ──────────────────────────────────────────────────────────────

class BVColors {
  BVColors._();

  // Core brand
  static const Color background     = Color(0xFF0B1A2E); // brand-navy
  static const Color surface        = Color(0xFF122340); // brand-navy-light
  static const Color surfaceElevated = Color(0xFF1C3254); // brand-navy-muted
  static const Color primary        = Color(0xFFF59E0B); // brand-amber
  static const Color primaryLight   = Color(0xFFFBBF24); // brand-amber-light
  static const Color primaryDark    = Color(0xFFD97706); // brand-amber-dark
  static const Color onPrimary      = Color(0xFF0B1A2E);
  static const Color onSurface      = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color(0xFF94A3B8); // slate-400
  static const Color textMuted      = Color(0xFF64748B); // slate-500
  static const Color divider        = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color surfaceOverlay = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)

  // Semantic
  static const Color danger    = Color(0xFFEF4444);
  static const Color dangerBg  = Color(0x1FEF4444); // 12% opacity
  static const Color success   = Color(0xFF22C55E);
  static const Color successBg = Color(0x1F22C55E);
  static const Color info      = Color(0xFF3B82F6);
  static const Color infoBg    = Color(0x1F3B82F6);
  static const Color warningBg = Color(0x1FF59E0B);

  // Legacy aliases — keep existing code compiling
  static const Color blocker        = danger;
  static const Color done           = success;
  static const Color accent         = info;
  static const Color scheduleChange   = info;
  static const Color materialRequest  = success;
  static const Color progressUpdate   = success;
  static const Color critical         = danger;
  static const Color high             = primary;
  static const Color medium           = info;
  static const Color low              = success;
  static const Color pending          = textSecondary;
  static const Color acknowledged     = info;
  static const Color inProgress       = primary;
}

// ── Material 3 Theme ───────────────────────────────────────────────────────────

ThemeData buildVoxTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BVColors.primary,
    onPrimary: BVColors.onPrimary,
    primaryContainer: BVColors.surface,
    onPrimaryContainer: BVColors.onSurface,
    secondary: BVColors.info,
    onSecondary: Colors.white,
    secondaryContainer: BVColors.surface,
    onSecondaryContainer: BVColors.onSurface,
    error: BVColors.danger,
    onError: Colors.white,
    errorContainer: BVColors.dangerBg,
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

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: BVColors.background,
      foregroundColor: BVColors.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: BVColors.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),

    // Cards — no visible border, 16px radius, floating on background
    cardTheme: CardThemeData(
      color: BVColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    // Elevated buttons — amber, 56px, bold
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BVColors.primary,
        foregroundColor: BVColors.onPrimary,
        disabledBackgroundColor: BVColors.surfaceElevated,
        disabledForegroundColor: BVColors.textMuted,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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

    // Input fields — no visible border, dark fill
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BVColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BVColors.danger, width: 2),
      ),
      labelStyle: const TextStyle(color: BVColors.textSecondary),
      hintStyle: const TextStyle(color: BVColors.textMuted),
      prefixIconColor: BVColors.textMuted,
      suffixIconColor: BVColors.textMuted,
    ),

    // Chips — full pill, amber when selected
    chipTheme: ChipThemeData(
      backgroundColor: BVColors.surfaceOverlay,
      selectedColor: BVColors.primary,
      secondarySelectedColor: BVColors.primary,
      labelStyle: const TextStyle(color: BVColors.textSecondary, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: BVColors.onPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      showCheckmark: false,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: BVColors.surfaceElevated,
      contentTextStyle: const TextStyle(color: BVColors.onSurface),
    ),

    // Progress indicators
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BVColors.primary,
      linearTrackColor: BVColors.surfaceElevated,
    ),

    // Tab bar — amber active, muted inactive
    tabBarTheme: const TabBarThemeData(
      labelColor: BVColors.primary,
      unselectedLabelColor: BVColors.textMuted,
      indicatorColor: BVColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      dividerColor: Colors.transparent,
    ),

    // Bottom app bar
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: BVColors.background,
      elevation: 0,
      padding: EdgeInsets.zero,
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BVColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: CircleBorder(),
    ),

    // Navigation bar (Material 3 style)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BVColors.background,
      indicatorColor: BVColors.primary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: BVColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: BVColors.textMuted,
          fontSize: 11,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: BVColors.primary, size: 24);
        }
        return const IconThemeData(color: BVColors.textMuted, size: 22);
      }),
      elevation: 0,
    ),
  );
}
