import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calimind/core/constants/app_colors.dart';

class AuthBackdrop extends StatelessWidget {
  final Widget child;
  final bool showWelcomeImage;
  final String? backgroundAsset;

  const AuthBackdrop({
    super.key,
    required this.child,
    this.showWelcomeImage = false,
    this.backgroundAsset,
  });

  @override
  Widget build(BuildContext context) {
    final hasImageBackground = showWelcomeImage || backgroundAsset != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: hasImageBackground
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF101639),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CaliMindColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImageBackground)
              Image.asset(
                backgroundAsset ?? 'assets/branding/welcome_photo.jpg',
                fit: BoxFit.cover,
              ),
            if (hasImageBackground)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x5A101639),
                      Color(0x80101639),
                    ],
                  ),
                ),
              ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool glass;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: glass ? 16 : 0,
          sigmaY: glass ? 16 : 0,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: glass ? const Color(0xB8FFFFFF) : CaliMindColors.card,
            borderRadius: borderRadius,
            border: Border.all(
              color: glass
                  ? Colors.white.withValues(alpha: 0.52)
                  : CaliMindColors.cardBorder,
            ),
            boxShadow: glass
                ? [
                    BoxShadow(
                      color: const Color(0xFF11152F).withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
