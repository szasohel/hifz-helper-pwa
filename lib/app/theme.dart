import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Day / Parchment Palette (Real Mushaf Feel)
  static const Color primaryGreen = Color(0xFF0D5638);
  static const Color emeraldLight = Color(0xFF1E825C);
  static const Color goldAccent = Color(0xFFC79836);
  static const Color antiqueGold = Color(0xFFB38228);
  static const Color warmParchment = Color(0xFFFAF6ED);
  static const Color cardParchment = Color(0xFFF6F0E2);
  static const Color mushafBorder = Color(0xFFDECDB0);
  static const Color quranInk = Color(0xFF17241E);

  // Night / Midnight Palette (Tahajjud Mode)
  static const Color darkBg = Color(0xFF111714);
  static const Color darkCard = Color(0xFF19231E);
  static const Color darkBorder = Color(0xFF2B3A33);
  static const Color darkInk = Color(0xFFE9EEEA);

  // Fluency Tag Colors
  static const Color fluencyMastered = Color(0xFF2E7D32); // Green
  static const Color fluencyHesitant = Color(0xFFF57C00); // Amber/Yellow
  static const Color fluencyWeak = Color(0xFFC62828);     // Red

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: goldAccent,
        surface: warmParchment,
      ),
      scaffoldBackgroundColor: warmParchment,
      cardTheme: CardThemeData(
        color: cardParchment,
        elevation: 1,
        shadowColor: Colors.black.withAlpha(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: mushafBorder, width: 0.8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: warmParchment,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryGreen),
        titleTextStyle: TextStyle(
          color: primaryGreen,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
        titleLarge: const TextStyle(fontWeight: FontWeight.bold, color: quranInk),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryGreen,
        primary: emeraldLight,
        secondary: goldAccent,
        surface: darkBg,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 0.8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
    );
  }

  // Dual-Script Arabic Typography Helper (Uthmani vs Indo-Pak)
  static TextStyle arabicStyle({
    String script = 'uthmani',
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    double height = 2.0,
    bool ornamental = false,
    String? text,
  }) {
    if (script == 'indopak') {
      // Indo-Pak / Asian Nastaliq script styling
      return GoogleFonts.lateef(
        fontSize: fontSize * 1.2, // Lateef glyphs scale naturally slightly smaller, adjust for readability
        fontWeight: fontWeight,
        color: color,
        height: height * 0.9,
        letterSpacing: 0,
      );
    }

    // ornamental/text no longer change styling — kept for call-site compatibility.
    // Scheherazade New: verified (fontTools cmap/glyph check) to correctly render
    // every codepoint used by the Uthmani ayah text, incl. all waqf/sajda marks,
    // unlike the bundled KFGQPC Hafs font which has broken glyphs for some marks.
    return GoogleFonts.scheherazadeNew(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }
}
