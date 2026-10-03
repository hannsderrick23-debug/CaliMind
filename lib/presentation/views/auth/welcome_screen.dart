import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _WelcomeSlide(
      backgroundAsset: 'assets/branding/welcome_photo.jpg',
      icon: LucideIcons.audioLines,
      title: 'Make room for what matters.',
      description:
          'A calmer way to gather your thoughts, shape your day, and follow through.',
      highlight: 'Capture tasks in your own words',
      detail: 'Speak naturally and keep moving.',
    ),
    _WelcomeSlide(
      backgroundAsset: 'assets/branding/register_photo.jpg',
      icon: LucideIcons.notebookPen,
      title: 'Get it out of your head.',
      description:
          'Turn quick thoughts and to-dos into a clear place you can come back to.',
      highlight: 'One home for your ideas',
      detail: 'Keep the little things from slipping away.',
    ),
    _WelcomeSlide(
      backgroundAsset: 'assets/branding/planning_photo.jpg',
      icon: LucideIcons.calendarCheck,
      title: 'Make a plan that feels possible.',
      description:
          'Shape your tasks into a thoughtful day, one manageable step at a time.',
      highlight: 'A plan built around your day',
      detail: 'Stay focused on what matters next.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return AuthBackdrop(
      backgroundAsset: slide.backgroundAsset,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CaliMindMark(size: 42),
                const SizedBox(width: 11),
                Text(
                  'CaliMind',
                  style: CaliMindTypography.h2.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _WelcomeSlideContent(
                slide: _slides[index],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => Semantics(
                        label: 'Go to slide ${index + 1}',
                        button: true,
                        child: GestureDetector(
                          onTap: () => _goToPage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: index == _currentPage ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: index == _currentPage ? 1 : 0.52,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CaliMindColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get started',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [
                            Shadow(color: Color(0xCC101639), blurRadius: 8),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSlideContent extends StatelessWidget {
  final _WelcomeSlide slide;

  const _WelcomeSlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.48),
                    width: 1.5,
                  ),
                ),
                child: Icon(slide.icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 28),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: CaliMindTypography.h1.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.12,
                  shadows: const [
                    Shadow(color: Color(0xCC101639), blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                slide.description,
                textAlign: TextAlign.center,
                style: CaliMindTypography.bodyLarge.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.55,
                  shadows: const [
                    Shadow(color: Color(0xCC101639), blurRadius: 9),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _WelcomeBenefit(
                icon: slide.icon,
                title: slide.highlight,
                detail: slide.detail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _WelcomeBenefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Color(0xCC101639), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  shadows: const [
                    Shadow(color: Color(0xCC101639), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeSlide {
  final String backgroundAsset;
  final IconData icon;
  final String title;
  final String description;
  final String highlight;
  final String detail;

  const _WelcomeSlide({
    required this.backgroundAsset,
    required this.icon,
    required this.title,
    required this.description,
    required this.highlight,
    required this.detail,
  });
}
