import 'package:flutter/material.dart';

class CaliMindColors {
  // Core Background & Surfaces
  static const Color background = Color(0xFF12161F);
  static const Color card = Color(0xFF191E2B);
  static const Color cardBorder = Color(0x14FFFFFF); // 8% white
  static const Color cardFocusBorder = Color(0x8C7C6EED);
  static const Color surfaceOverlay = Color(0x99191E2B);

  // Typography
  static const Color foreground = Color(0xFFF5F6F9);
  static const Color mutedForeground = Color(0xFFA5ABB8);

  // Brand Accents
  static const Color primary = Color(0xFF7C6EED); // Mind Indigo
  static const Color primaryVariant = Color(0xFF6366F1);
  static const Color accent = Color(0xFF2DD4BF); // Mind Teal
  static const Color destructive = Color(0xFFF43F5E); // Rose Red
  static const Color warning = Color(0xFFFBBF24); // Amber
  static const Color success = Color(0xFF10B981); // Emerald Green

  // Role Category Accents
  static const Color catClass = Color(0xFF3B82F6); // Class Rep (Electric Blue)
  static const Color catClub = Color(0xFFD946EF); // Club President (Vibrant Purple)
  static const Color catStudy = Color(0xFF10B981); // Study (Emerald)
  static const Color catPersonal = Color(0xFFF59E0B); // Personal (Warm Amber)

  // Gradients
  static const LinearGradient mindGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x337C6EED), Color(0x112DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fabPulseGradient = LinearGradient(
    colors: [Color(0xFF7C6EED), Color(0xFF2DD4BF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
