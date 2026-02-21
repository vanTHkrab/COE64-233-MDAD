import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Election-themed application theme.
///
/// Colors inspired by Thai election / civic duty aesthetics:
///   • Primary: deep navy-blue (trustworthy, official)
///   • Secondary: warm gold (authority, national pride)
///   • Tertiary: crimson-red (urgency, alerts)
///   • Surface variants: clean neutrals for readability
abstract final class AppTheme {
  // ─── Color Palette ──────────────────────────────────────────────────────

  static const _primarySeed = Color(0xFF0D47A1); // deep navy
  static const _gold = Color(0xFFD4A017); // Thai gold
  static const _crimson = Color(0xFFC62828); // alert red
  static const _teal = Color(0xFF00796B); // success / synced

  // ─── Color Scheme ───────────────────────────────────────────────────────

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _primarySeed,
    brightness: Brightness.light,
    primary: const Color(0xFF0D47A1),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD6E4FF),
    onPrimaryContainer: const Color(0xFF001B3F),
    secondary: _gold,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFFFF1CC),
    onSecondaryContainer: const Color(0xFF3E2E00),
    tertiary: _crimson,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFDAD6),
    onTertiaryContainer: const Color(0xFF410002),
    error: const Color(0xFFBA1A1A),
    surface: const Color(0xFFF8F9FC),
    onSurface: const Color(0xFF1A1C1E),
    onSurfaceVariant: const Color(0xFF44474E),
    outline: const Color(0xFF74777F),
    outlineVariant: const Color(0xFFC4C6D0),
    surfaceContainerHighest: const Color(0xFFE2E2E6),
  );

  // ─── Severity Colors (used across the app) ─────────────────────────────

  static const Color severityHigh = Color(0xFFD32F2F);
  static const Color severityMedium = Color(0xFFEF6C00);
  static const Color severityLow = Color(0xFF2E7D32);

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return severityHigh;
      case 'medium':
        return severityMedium;
      case 'low':
        return severityLow;
      default:
        return Colors.grey;
    }
  }

  static const Color syncedColor = _teal;
  static const Color pendingColor = Color(0xFFE65100);
  static const Color offlineColor = Color(0xFF616161);

  // ─── Chart Colors ───────────────────────────────────────────────────────

  static const List<Color> chartColors = [
    Color(0xFF0D47A1), // navy
    Color(0xFFD4A017), // gold
    Color(0xFFC62828), // crimson
    Color(0xFF00796B), // teal
    Color(0xFF6A1B9A), // purple
    Color(0xFFEF6C00), // amber
    Color(0xFF1565C0), // blue
    Color(0xFF2E7D32), // green
  ];

  // ─── Theme Data ─────────────────────────────────────────────────────────

  static ThemeData get light {
    final textTheme = GoogleFonts.promptTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightScheme,
      brightness: Brightness.light,
      textTheme: textTheme,

      // ── AppBar ───────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: _lightScheme.surface,
        foregroundColor: _lightScheme.onSurface,
        titleTextStyle: GoogleFonts.prompt(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightScheme.onSurface,
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _lightScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Input Decoration ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ── Filled Button ────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── Elevated Button ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.prompt(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── Navigation Bar ───────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        height: 72,
        indicatorColor: _lightScheme.primaryContainer,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.prompt(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _lightScheme.primary,
            );
          }
          return GoogleFonts.prompt(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _lightScheme.onSurfaceVariant,
          );
        }),
      ),

      // ── FAB ──────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightScheme.primary,
        foregroundColor: _lightScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Snackbar ─────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── Dialog ───────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Chip ─────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
