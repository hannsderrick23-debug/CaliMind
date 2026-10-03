import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'presentation/routing/app_router.dart';

class CaliMindApp extends ConsumerWidget {
  const CaliMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CaliMind',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: CaliMindColors.background,
      colorScheme: const ColorScheme.light(
        primary: CaliMindColors.primary,
        secondary: CaliMindColors.accent,
        surface: CaliMindColors.card,
        error: CaliMindColors.destructive,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: CaliMindColors.foreground,
      ),
      textTheme: CaliMindTypography.textTheme,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: CaliMindColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CaliMindColors.foreground,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        color: CaliMindColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CaliMindColors.cardBorder),
        ),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CaliMindColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: CaliMindColors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: CaliMindColors.foreground),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CaliMindColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CaliMindColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CaliMindColors.card,
        hintStyle: GoogleFonts.inter(color: CaliMindColors.mutedForeground, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CaliMindColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CaliMindColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CaliMindColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: CaliMindColors.primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CaliMindColors.foreground,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: CaliMindColors.cardBorder),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return CaliMindColors.mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return CaliMindColors.primary;
          return CaliMindColors.cardBorder;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: CaliMindColors.primary,
        thumbColor: CaliMindColors.primary,
        inactiveTrackColor: CaliMindColors.cardBorder,
        overlayColor: Color(0x22167D78),
      ),
      dividerTheme: const DividerThemeData(color: CaliMindColors.cardBorder, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: CaliMindColors.primary),
    );
  }
}
