import 'package:flutter/material.dart';
import 'package:calimind/core/constants/app_colors.dart';

class AuthBackdrop extends StatelessWidget {
  final Widget child;

  const AuthBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaliMindColors.background,
      body: SafeArea(child: child),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: borderRadius,
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: child,
    );
  }
}
