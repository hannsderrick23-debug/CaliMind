import 'package:flutter/material.dart';

class CaliMindColors {
  static const Color background = Color(0xFFF7F4FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE5DDEB);
  static const Color cardFocusBorder = Color(0xFF6C2198);
  static const Color surfaceOverlay = Color(0xFFF2ECF7);

  static const Color foreground = Color(0xFF281D30);
  static const Color mutedForeground = Color(0xFF65596D);

  static const Color primary = Color(0xFF641A91);
  static const Color primaryVariant = Color(0xFF4C0C74);
  static const Color accent = Color(0xFF813CAC);
  static const Color destructive = Color(0xFFB93848);
  static const Color warning = Color(0xFF8A5A00);
  static const Color success = Color(0xFF287A55);

  static const Color catClass = Color(0xFF326A9D);
  static const Color catClub = Color(0xFF70428F);
  static const Color catStudy = Color(0xFF287A55);
  static const Color catPersonal = Color(0xFF9A6700);

  static const LinearGradient mindGradient = LinearGradient(
    colors: [Color(0xFF641A91), Color(0xFF641A91)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0xFFF2ECF7), Color(0xFFF7F4FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fabPulseGradient = LinearGradient(
    colors: [Color(0xFF641A91), Color(0xFF641A91)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
