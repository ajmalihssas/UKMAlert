import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary — UKM Deep Blue
  static const Color primary = Color(0xFF003DA5);
  static const Color primaryContainer = Color(0xFF1A4FBF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFD0E4FF);
  static const Color primaryFixed = Color(0xFFD0E4FF);
  static const Color primaryFixedDim = Color(0xFF9EC5FF);
  static const Color onPrimaryFixed = Color(0xFF001A45);
  static const Color onPrimaryFixedVariant = Color(0xFF003DA5);

  // Secondary — UKM Gold/Yellow
  static const Color secondary = Color(0xFFC9A227);
  static const Color secondaryContainer = Color(0xFFFFE08B);
  static const Color onSecondary = Color(0xFF3D2D00);
  static const Color onSecondaryContainer = Color(0xFF3D2D00);
  static const Color secondaryFixed = Color(0xFFFFF1B0);
  static const Color secondaryFixedDim = Color(0xFFFFD740);
  static const Color onSecondaryFixed = Color(0xFF241A00);
  static const Color onSecondaryFixedVariant = Color(0xFF7A5C00);

  // Tertiary — UKM Red (emergency accent)
  static const Color tertiary = Color(0xFFCC0000);
  static const Color tertiaryContainer = Color(0xFFFF4444);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF5A0000);
  static const Color tertiaryFixed = Color(0xFFFFDAD6);
  static const Color tertiaryFixedDim = Color(0xFFFFB4A8);
  static const Color onTertiaryFixed = Color(0xFF410000);
  static const Color onTertiaryFixedVariant = Color(0xFF930000);

  // Error
  static const Color error = Color(0xFFCC0000);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface — white / light blue-tinted
  static const Color surface = Color(0xFFF7F9FF);
  static const Color surfaceBright = Color(0xFFF7F9FF);
  static const Color surfaceDim = Color(0xFFD6D9EB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3FF);
  static const Color surfaceContainer = Color(0xFFE8ECFF);
  static const Color surfaceContainerHigh = Color(0xFFE0E5FF);
  static const Color surfaceContainerHighest = Color(0xFFD8DEFF);
  static const Color surfaceVariant = Color(0xFFD8DEFF);
  static const Color surfaceTint = Color(0xFF003DA5);

  // On Surface
  static const Color onSurface = Color(0xFF001A45);
  static const Color onSurfaceVariant = Color(0xFF44546A);
  static const Color onBackground = Color(0xFF001A45);
  static const Color background = Color(0xFFF7F9FF);

  // Outline
  static const Color outline = Color(0xFF74788D);
  static const Color outlineVariant = Color(0xFFC4C8DE);

  // Inverse
  static const Color inverseSurface = Color(0xFF001A45);
  static const Color inverseOnSurface = Color(0xFFEEF0FF);
  static const Color inversePrimary = Color(0xFF9EC5FF);

  // SOS — dedicated red for emergency panic button
  static const Color sos = Color(0xFFCC0000);
  static const Color sosContainer = Color(0xFFFF2222);
}

class AppTheme {
  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -0.25),
      displayMedium: GoogleFonts.manrope(fontSize: 45, fontWeight: FontWeight.w800),
      displaySmall: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w800),
      headlineLarge: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.15),
      titleSmall: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: _textTheme,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceTint: AppColors.surfaceTint,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
