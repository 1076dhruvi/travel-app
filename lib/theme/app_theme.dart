import 'package:flutter/material.dart';

/// Centralized Design System & Theme configuration.
///
/// Palette specification (Restrained Premium Violet & Ivory-White):
/// - Background: Ivory-tinted off-white #F8F7FC
/// - Primary violet: #6D42E8 (Used for primary actions, selected states, highlights)
/// - Secondary violet: #9B80F5 (Used sparingly for secondary accents)
/// - Muted lavender: #E8E3F3 (Used only for subtle container/chip backgrounds)
/// - Primary text: Deep violet-slate #211B32
/// - Secondary text: Muted slate #777184
/// - Card & surface background: Pure white #FFFFFF
/// - Border color: Soft lavender-gray #EAE6F1
class AppTheme {
  // ── Palette Constants (New Visual Design System) ───────────────
  static const Color primaryViolet = Color(0xFF6D42E8);
  static const Color primaryVioletDark = Color(0xFF5630CE);
  static const Color primaryVioletLight = Color(0xFF855DF8);

  static const Color secondaryViolet = Color(0xFF9B80F5);
  static const Color mutedLavender = Color(0xFFE8E3F3);
  static const Color subtleAccent = Color(0xFFF3F0FA);

  static const Color background = Color(0xFFF8F7FC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAE6F1);
  static const Color borderLight = Color(0xFFF4F1F9);

  static const Color textPrimary = Color(0xFF211B32);
  static const Color textSecondary = Color(0xFF777184);
  static const Color textMuted = Color(0xFFA19BAE);

  // ── Backward-Compatibility Aliases ────────────────────────────
  // Preserves existing screen references without requiring mass rewrites.
  static const Color primaryTeal = primaryViolet;
  static const Color primaryTealDark = primaryVioletDark;
  static const Color primaryTealLight = mutedLavender;

  static const Color secondaryAmber = secondaryViolet;
  static const Color secondaryAmberLight = subtleAccent;
  static const Color secondaryAmberDark = primaryVioletDark;

  static const Color backgroundSlate = background;
  static const Color borderSlate = border;
  static const Color borderSlateLight = borderLight;

  static const Color textSlatePrimary = textPrimary;
  static const Color textSlateSecondary = textSecondary;
  static const Color textSlateMuted = textMuted;

  // ── Transport Mode Colors ─────────────────────────────────────
  // Clean, high-legibility transport indicators
  static const Color modeWalk = Color(0xFF16A34A);
  static const Color modeWalkLight = Color(0xFFDCFCE7);
  static const Color modeWalkBorder = Color(0xFF86EFAC);

  static const Color modeTransit = Color(0xFF2563EB);
  static const Color modeTransitLight = Color(0xFFDBEAFE);
  static const Color modeTransitBorder = Color(0xFF93C5FD);

  static const Color modeCab = Color(0xFFF97316);
  static const Color modeCabLight = Color(0xFFFFEDD5);
  static const Color modeCabBorder = Color(0xFFFDBA74);

  // ── Coordinated Day Color Palette ─────────────────────────────
  // Balanced accents for itinerary day pills and markers
  static const List<Color> dayColors = [
    Color(0xFF6D42E8), // Primary Violet (Day 1)
    Color(0xFF0F766E), // Deep Teal (Day 2)
    Color(0xFF2563EB), // Royal Blue (Day 3)
    Color(0xFFD97706), // Amber (Day 4)
    Color(0xFF059669), // Emerald (Day 5)
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
    return modeCab;
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

  // ── Visual Style Helpers ──────────────────────────────────────
  /// Subtle gradient for select header containers (restrained violet)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryViolet, primaryVioletDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft shadow for elevated cards
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A211B32), blurRadius: 10, offset: Offset(0, 4)),
  ];

  /// Subtle shadow for smaller floating controls
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(color: Color(0x06211B32), blurRadius: 6, offset: Offset(0, 2)),
  ];

  // ── Unified Light ThemeData ──────────────────────────────────
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryViolet,
      onPrimary: Colors.white,
      primaryContainer: mutedLavender,
      onPrimaryContainer: textPrimary,
      secondary: secondaryViolet,
      onSecondary: Colors.white,
      secondaryContainer: subtleAccent,
      onSecondaryContainer: textPrimary,
      surface: surfaceWhite,
      onSurface: textPrimary,
      surfaceContainerHighest: background,
      surfaceContainerLow: surfaceWhite,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: borderLight,
      error: Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryViolet,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 22),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),

      // Card Theme (Crisp white surface with subtle borders & soft depth)
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shadowColor: const Color(0x0C211B32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),

      // Elevated Button Theme (Clean primary action)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryViolet,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryViolet,
          side: const BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryViolet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryViolet, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        selectedColor: mutedLavender,
        disabledColor: borderLight,
        secondarySelectedColor: primaryViolet,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primaryViolet,
        ),
        iconTheme: const IconThemeData(size: 16, color: primaryViolet),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryViolet,
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(fontSize: 14, color: textSecondary),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // TabBar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryViolet,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryViolet,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryViolet,
        linearTrackColor: mutedLavender,
        circularTrackColor: mutedLavender,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: primaryViolet, size: 22),
    );
  }
}
