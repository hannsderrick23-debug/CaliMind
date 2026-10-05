import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  const OAuthCallbackScreen({super.key});

  @override
  ConsumerState<OAuthCallbackScreen> createState() =>
      _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (mounted &&
          ref.read(authProvider).status != AuthStatus.authenticated) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaliMindColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.brain,
                color: CaliMindColors.primary, size: 44),
            const SizedBox(height: 20),
            Text('Completing sign in…', style: CaliMindTypography.h3),
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: const StarLoadingIndicator(size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
