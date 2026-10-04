import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/presentation/routing/app_router.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/views/splash_screen.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';

Future<void> _pumpAuthAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('welcome opens separate registration and login screens',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, child) => MaterialApp.router(
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );
    await _pumpAuthAnimations(tester);

    expect(find.text('Make room for what matters.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Explore with a demo account'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/welcome_photo.jpg',
      ),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Get it out of your head.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/register_photo.jpg',
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Make room for what matters.'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/register_photo.jpg',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Make room for what matters.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('Sign in with biometrics'), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/welcome_photo.jpg',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Forgot password?'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/welcome_photo.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('splash screen shows the brand over the photo background',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('CaliMind'), findsOneWidget);
    expect(find.text('A little more clarity, every day.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/welcome_photo.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('successful authentication routes through a welcome screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) => MaterialApp.router(
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );
    await _pumpAuthAnimations(tester);

    container.read(authProvider.notifier).state = const AuthState(
      status: AuthStatus.authenticated,
    );
    await _pumpAuthAnimations(tester);

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Open my planner'), findsOneWidget);
    expect(find.text('View my schedule'), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/register_photo.jpg',
      ),
      findsOneWidget,
    );
  });
}
