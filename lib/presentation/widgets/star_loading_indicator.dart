import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';

class StarLoadingIndicator extends StatefulWidget {
  const StarLoadingIndicator({
    super.key,
    this.size = 22,
    this.color = CaliMindColors.primary,
  });

  final double size;
  final Color color;

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
      label: 'Loading',
      child: SizedBox.square(
        dimension: widget.size,
        child: RotationTransition(
          turns: _rotation,
          child: Icon(
            LucideIcons.sparkles,
            size: widget.size * 0.82,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
