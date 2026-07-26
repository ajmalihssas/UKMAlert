import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── UKM Colour Palette ────────────────────────────────────────────────────────
const Color kBg        = Color(0xFFF0F4FF);   // light blue-tinted bg
const Color kSurface   = Color(0xFFFFFFFF);
const Color kSidebar   = Color(0xFF001A45);   // UKM Deep Navy
const Color kPrimary   = Color(0xFF003DA5);   // UKM Blue
const Color kPrimaryLt = Color(0xFFEEF3FF);   // light blue
const Color kBorder    = Color(0xFFD8DEFF);
const Color kText1     = Color(0xFF001A45);
const Color kText2     = Color(0xFF44546A);
const Color kText3     = Color(0xFF8090A0);
const Color kSuccess   = Color(0xFF16A34A);
const Color kWarning   = Color(0xFFD97706);
const Color kDanger    = Color(0xFFCC0000);   // UKM Red
const Color kInfo      = Color(0xFF003DA5);   // UKM Blue
const Color kGold      = Color(0xFFC9A227);   // UKM Gold/Yellow

// Legacy aliases
const Color kPrimaryLight  = kPrimaryLt;
const Color kSidebarBg     = kSidebar;
const Color kSidebarActive = kPrimary;

// ── Shadow helper ─────────────────────────────────────────────────────────────
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 16,
    offset: Offset(0, 2),
  ),
];

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData webTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      surface: kSurface,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kText1,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: kBorder,
    cardColor: kSurface,
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kPrimaryLt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: kText3, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kPrimary),
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
  );
}
