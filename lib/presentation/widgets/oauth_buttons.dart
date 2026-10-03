import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class OAuthButtons extends ConsumerWidget {
  final bool isLoading;
  final bool photoStyle;

  const OAuthButtons({
    super.key,
    required this.isLoading,
    this.photoStyle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(authProvider.notifier);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: photoStyle
                    ? Colors.white.withValues(alpha: 0.56)
                    : CaliMindColors.cardBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  color: photoStyle
                      ? Colors.white.withValues(alpha: 0.9)
                      : CaliMindColors.mutedForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: photoStyle
                    ? Colors.white.withValues(alpha: 0.56)
                    : CaliMindColors.cardBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _OAuthButton(
                label: 'Google',
                icon: FontAwesomeIcons.google,
                iconColor: const Color(0xFF4285F4),
                photoStyle: photoStyle,
                onPressed: isLoading
                    ? null
                    : () => notifier.signInWithOAuth(OAuthProvider.google),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OAuthButton(
                label: 'Apple',
                icon: FontAwesomeIcons.apple,
                iconColor: CaliMindColors.foreground,
                photoStyle: photoStyle,
                onPressed: isLoading
                    ? null
                    : () => notifier.signInWithOAuth(OAuthProvider.apple),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final Color iconColor;
  final bool photoStyle;
  final VoidCallback? onPressed;

  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.photoStyle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: photoStyle ? Colors.white : CaliMindColors.foreground,
        side: BorderSide(
          color: photoStyle
              ? Colors.white.withValues(alpha: 0.7)
              : CaliMindColors.cardBorder,
        ),
        backgroundColor: photoStyle
            ? Colors.white.withValues(alpha: 0.12)
            : CaliMindColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            icon,
            size: 18,
            color: photoStyle && icon == FontAwesomeIcons.apple
                ? Colors.white
                : iconColor,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
