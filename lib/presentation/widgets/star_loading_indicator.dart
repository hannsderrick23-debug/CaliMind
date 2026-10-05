import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:calimind/core/constants/app_colors.dart';

class StarLoadingIndicator extends StatefulWidget {
  const StarLoadingIndicator({
    super.key,
    this.size = 20,
    this.color = CaliMindColors.primary,
    this.semanticLabel = 'Loading',
  });

  final double size;
  final Color color;
  final String semanticLabel;

  @override
  State<StarLoadingIndicator> createState() => _StarLoadingIndicatorState();
}

class _StarLoadingIndicatorState extends State<StarLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: RotationTransition(
        turns: _rotation,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _RadialSpinnerPainter(color: widget.color),
        ),
      ),
    );
  }
}

class _RadialSpinnerPainter extends CustomPainter {
  const _RadialSpinnerPainter({required this.color});

  final Color color;

  static const int _spokeCount = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final spokeThickness = size.shortestSide * 0.14;
    final spokeLength = size.shortestSide * 0.28;
    final innerRadius = size.shortestSide * 0.19;
    final cornerRadius = Radius.circular(spokeThickness / 2);

    for (var index = 0; index < _spokeCount; index++) {
      final opacity = 1 - (index * 0.095);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      final spoke = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - spokeThickness / 2,
          center.dy - innerRadius - spokeLength,
          spokeThickness,
          spokeLength,
        ),
        cornerRadius,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(index * (2 * math.pi / _spokeCount));
      canvas.translate(-center.dx, -center.dy);
      canvas.drawRRect(spoke, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RadialSpinnerPainter oldDelegate) =>
      oldDelegate.color != color;
}
