import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/presentation/routing/app_router.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

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

    await tester.tap(find.text('Get started'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
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

    await tester.tap(find.text('Forgot password?'));
    await _pumpAuthAnimations(tester);
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
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

    expect(find.text('You’re in.'), findsOneWidget);
    expect(find.text('Open my planner'), findsOneWidget);
  });
}
