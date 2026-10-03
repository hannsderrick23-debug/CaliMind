import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class OAuthButtons extends ConsumerWidget {
  final bool isLoading;

  const OAuthButtons({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(authProvider.notifier);
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: CaliMindColors.cardBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR CONTINUE WITH',
                style: TextStyle(
                  color: CaliMindColors.mutedForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: CaliMindColors.cardBorder)),
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
  final VoidCallback? onPressed;

  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: CaliMindColors.foreground,
        side: const BorderSide(color: CaliMindColors.cardBorder),
        backgroundColor: CaliMindColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
