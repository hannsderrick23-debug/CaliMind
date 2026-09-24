import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class CaliMindTypography {
  static TextStyle get h1 => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: CaliMindColors.foreground,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: CaliMindColors.foreground,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CaliMindColors.foreground,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: CaliMindColors.foreground,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: CaliMindColors.foreground,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: CaliMindColors.mutedForeground,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: CaliMindColors.mutedForeground,
      );

  static TextStyle get timeMonospace => GoogleFonts.jetbrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CaliMindColors.foreground,
      );

  static TextTheme textTheme = TextTheme(
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: label.copyWith(fontWeight: FontWeight.w600),
    labelMedium: label,
  );
}
