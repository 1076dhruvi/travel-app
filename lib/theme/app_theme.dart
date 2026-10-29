import 'package:flutter/material.dart';

/// Centralized Design System & Theme configuration.
///
/// Palette specification:
/// - Primary: Deep Teal #0F766E
/// - Secondary: Warm Amber #F59E0B
/// - Background: Slate-tinted #F8FAFC
/// - Surface: White #FFFFFF
/// - Text Slate: Primary #0F172A, Secondary #64748B
/// - Mode Colors: Walk Green #16A34A, Bus/Train Blue #2563EB, Auto/Cab Orange #F97316
class AppTheme {
  // ── Palette Constants ─────────────────────────────────────────
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealDark = Color(0xFF115E59);
  static const Color primaryTealLight = Color(0xFFCCFBF1);

  static const Color secondaryAmber = Color(0xFFF59E0B);
  static const Color secondaryAmberLight = Color(0xFFFEF3C7);
  static const Color secondaryAmberDark = Color(0xFFB45309);

  static const Color backgroundSlate = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderSlate = Color(0xFFE2E8F0);
  static const Color borderSlateLight = Color(0xFFF1F5F9);

  static const Color textSlatePrimary = Color(0xFF0F172A);
  static const Color textSlateSecondary = Color(0xFF64748B);
  static const Color textSlateMuted = Color(0xFF94A3B8);

  // ── Transport Mode Colors ─────────────────────────────────────
  // Green for Walk
  static const Color modeWalk = Color(0xFF16A34A);
  static const Color modeWalkLight = Color(0xFFDCFCE7);
  static const Color modeWalkBorder = Color(0xFF86EFAC);

  // Blue for Bus / Train / Metro
  static const Color modeTransit = Color(0xFF2563EB);
  static const Color modeTransitLight = Color(0xFFDBEAFE);
  static const Color modeTransitBorder = Color(0xFF93C5FD);

  // Orange for Auto / Cab
  static const Color modeCab = Color(0xFFF97316);
  static const Color modeCabLight = Color(0xFFFFEDD5);
  static const Color modeCabBorder = Color(0xFFFDBA74);

  // ── Coordinated Day Color Palette (No purple anywhere) ────────
  static const List<Color> dayColors = [
    Color(0xFF0F766E), // Deep Teal (Day 1)
    Color(0xFFF59E0B), // Warm Amber (Day 2)
    Color(0xFF0284C7), // Sky Blue (Day 3)
    Color(0xFF059669), // Emerald (Day 4)
    Color(0xFF4F46E5), // Indigo (Day 5)
    Color(0xFFE11D48), // Rose Red (Day 6)
  ];

  static Color getDayColor(int dayNum) {
    var effectiveDay = dayNum;
    if (effectiveDay < 1) effectiveDay = 1;
    return dayColors[(effectiveDay - 1) % dayColors.length];
  }

  /// Returns the specific mode color for chips and UI indicators
  static Color getModeColor(String? mode) {
    final m = (mode ?? '').toLowerCase();
    if (m.contains('walk')) return modeWalk;
    if (m.contains('bus') ||
        m.contains('train') ||
        m.contains('metro') ||
        m.contains('subway') ||
        m.contains('rail') ||
        m.contains('transit')) {
      return modeTransit;
    }
    return modeCab; // auto, cab, taxi, drive
  }

  /// Returns light tinted background for mode containers
  static Color getModeLightColor(String? mode) {
    final m = (mode ?? '').toLowerCase();
    if (m.contains('walk')) return modeWalkLight;
    if (m.contains('bus') ||
        m.contains('train') ||
        m.contains('metro') ||
        m.contains('subway') ||
        m.contains('rail') ||
        m.contains('transit')) {
      return modeTransitLight;
    }
    return modeCabLight;
  }

  /// Returns border color for mode chips
  static Color getModeBorderColor(String? mode) {
    final m = (mode ?? '').toLowerCase();
    if (m.contains('walk')) return modeWalkBorder;
    if (m.contains('bus') ||
        m.contains('train') ||
        m.contains('metro') ||
        m.contains('subway') ||
        m.contains('rail') ||
        m.contains('transit')) {
      return modeTransitBorder;
    }
    return modeCabBorder;
  }

  /// Returns mode hex color code for MapLibre line layers
  static String getModeHexColor(String? mode) {
    final m = (mode ?? '').toLowerCase();
    if (m.contains('walk')) return '#16A34A'; // Green
    if (m.contains('bus') ||
        m.contains('train') ||
        m.contains('metro') ||
        m.contains('subway') ||
        m.contains('rail') ||
        m.contains('transit')) {
      return '#2563EB'; // Blue
    }
    return '#F97316'; // Orange for Auto/Cab
  }

  // ── Unified Light ThemeData ──────────────────────────────────
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: primaryTealLight,
      onPrimaryContainer: primaryTealDark,
      secondary: secondaryAmber,
      onSecondary: Colors.white,
      secondaryContainer: secondaryAmberLight,
      onSecondaryContainer: secondaryAmberDark,
      surface: surfaceWhite,
      onSurface: textSlatePrimary,
      surfaceContainerHighest: borderSlateLight,
      onSurfaceVariant: textSlateSecondary,
      outline: borderSlate,
      outlineVariant: borderSlateLight,
      error: Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundSlate,

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textSlatePrimary),
        displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textSlatePrimary),
        displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textSlatePrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textSlatePrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textSlatePrimary),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSlatePrimary),
        bodyLarge: TextStyle(fontSize: 15, color: textSlatePrimary),
        bodyMedium: TextStyle(fontSize: 13, color: textSlatePrimary),
        bodySmall: TextStyle(fontSize: 11, color: textSlateSecondary),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1,
        shadowColor: const Color(0x0F0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSlate, width: 1),
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderSlate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderSlate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryTeal, width: 1.6),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        selectedColor: primaryTeal,
        disabledColor: borderSlateLight,
        secondarySelectedColor: secondaryAmber,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderSlate),
        ),
        labelStyle: const TextStyle(fontSize: 12, color: textSlatePrimary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: primaryTeal,
        size: 22,
      ),
    );
  }
}