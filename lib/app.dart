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
      themeMode: ThemeMode.dark,
      darkTheme: _buildDarkTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: CaliMindColors.background,
      colorScheme: const ColorScheme.dark(
        primary: CaliMindColors.primary,
        secondary: CaliMindColors.accent,
        surface: CaliMindColors.card,
        error: CaliMindColors.destructive,
        onPrimary: Colors.white,
        onSurface: CaliMindColors.foreground,
      ),
      textTheme: CaliMindTypography.textTheme,
      cardTheme: CardTheme(
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
        modalBackgroundColor: CaliMindColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: CaliMindColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CaliMindColors.background,
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
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
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
        overlayColor: Color(0x337C6EED),
      ),
      dividerTheme: const DividerThemeData(color: CaliMindColors.cardBorder, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: CaliMindColors.primary),
    );
  }
}
