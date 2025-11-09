import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
/// Following Material Design 3 principles with custom color scheme
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Color Palette - Based on NextDesk logo colors
  // Primary blue from logo (#27A4F2)
  static const Color primaryPurple = Color(0xFF27A4F2);
  static const Color primaryPurpleLight = Color(0xFF5CB8F5);
  static const Color primaryPurpleDark = Color(0xFF1F82BF);

  // Secondary blue from logo (#145E8C)
  static const Color secondaryBlue = Color(0xFF145E8C);
  static const Color secondaryBlueLight = Color(0xFF1F82BF);
  static const Color secondaryBlueDark = Color(0xFF011F26);

  // Accent colors
  static const Color accentGreen = Color(0xFF06FFA5);
  static const Color accentGreenDark = Color(0xFF00D97E);

  static const Color errorRed = Color(0xFFFF006E);
  static const Color warningOrange = Color(0xFFFFBE0B);

  // Background colors - Dark theme with subtle blue tint
  static const Color backgroundDark = Color(0xFF0A0E10);
  static const Color backgroundMedium = Color(0xFF0F1419);
  static const Color backgroundLight = Color(0xFF151B20);
  static const Color backgroundElevated = Color(0xFF1A2228);

  // Surface colors
  static const Color surfaceDark = Color(0xFF141A1F);
  static const Color surfaceMedium = Color(0xFF1C2329);
  static const Color surfaceLight = Color(0xFF242B32);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8B8);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF4D4D4D);

  // Border colors - Subtle borders for better contrast
  static const Color borderSubtle = Color(0xFF2A3540);
  static const Color borderMedium = Color(0xFF3D4A57);
  static const Color borderStrong = Color(0xFF526070);

  // Spacing system (8px base)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;
  static const double space3xl = 64.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // Elevation/Shadow
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowGlow => [
        BoxShadow(
          color: primaryPurple.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ];

  // Typography
  static TextTheme get textTheme {
    final baseTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return baseTheme.copyWith(
      // Display styles
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: textPrimary,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: textPrimary,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      ),

      // Headline styles
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      ),

      // Title styles
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: textPrimary,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: textPrimary,
      ),

      // Body styles
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textPrimary,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textSecondary,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textTertiary,
      ),

      // Label styles
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textPrimary,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textSecondary,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textTertiary,
      ),
    );
  }

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: primaryPurple,
        primaryContainer: primaryPurpleDark,
        secondary: secondaryBlue,
        secondaryContainer: secondaryBlueDark,
        tertiary: accentGreen,
        error: errorRed,
        surface: surfaceDark,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),

      scaffoldBackgroundColor: backgroundDark,

      // Text theme
      textTheme: textTheme,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundMedium,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: textPrimary),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: surfaceMedium,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
