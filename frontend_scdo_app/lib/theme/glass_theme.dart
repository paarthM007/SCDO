import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTheme {
  // Colors
  static const Color backgroundDark = Color(0xFF1E222D);
  static const Color backgroundCard = Color(0xFF2A2E39);
  static const Color accentNeonGreen = Color(0xFF39FF14);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color danger = Color(0xFFFF4C4C);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accentNeonGreen,
      colorScheme: const ColorScheme.dark(
        primary: accentNeonGreen,
        secondary: accentCyan,
        surface: backgroundCard,
        error: danger,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: accentNeonGreen),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentNeonGreen,
          foregroundColor: backgroundDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentNeonGreen),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundCard,
        selectedItemColor: accentNeonGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
