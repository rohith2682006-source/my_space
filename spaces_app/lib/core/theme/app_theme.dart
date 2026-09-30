import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      bodyLarge: GoogleFonts.inter(
        color: AppColors.darkTextPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        color: AppColors.darkTextSecondary,
        fontSize: 13,
        height: 1.4,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground.withOpacity(0.8),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      hintStyle: GoogleFonts.inter(color: AppColors.darkTextTertiary, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      bodyLarge: GoogleFonts.inter(
        color: AppColors.lightTextPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        color: AppColors.lightTextSecondary,
        fontSize: 13,
        height: 1.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.inter(color: AppColors.lightTextTertiary, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: AppColors.lightTextSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
