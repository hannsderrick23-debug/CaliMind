import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/focus_session_provider.dart';
import '../views/focus/focus_timer_screen.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/register_screen.dart';
import '../views/auth/post_login_welcome_screen.dart';
import '../views/auth/forgot_password_screen.dart';
import '../views/auth/reset_password_screen.dart';
import '../views/auth/welcome_screen.dart';
import '../views/auth/oauth_callback_screen.dart';
import '../views/auth/unlock_screen.dart';
import '../views/splash_screen.dart';
import '../views/dashboard/dashboard_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier(ref.read(authProvider));
  ref.listen(authProvider, (previous, next) {
    authState.value = next;
  });
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authState,
    redirect: (context, state) {
      final currentAuthState = authState.value;
      final isAuth = currentAuthState.status == AuthStatus.authenticated;
      final location = state.matchedLocation;
      final isAuthCallback = state.uri.host == 'login-callback';
      if (isAuthCallback && location != '/login-callback') {
        return '/login-callback';
      }
      if (currentAuthState.status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }
      if (currentAuthState.status == AuthStatus.biometricLocked) {
        return const {'/login', '/unlock'}.contains(location) ? null : '/login';
      }
      if (currentAuthState.biometricSetupPending && location == '/login') {
        return null;
      }

      if (currentAuthState.isPasswordRecovery &&
          location != '/reset-password') {
        return '/reset-password';
      }
      if (isAuth && state.uri.host == 'voice-capture') {
        return '/dashboard?voiceShortcut=1';
      }
      if (isAuth && location == '/voice-capture') {
        return '/dashboard?voiceShortcut=1';
      }
      if (!isAuth && (location == '/splash' || location == '/')) {
        return '/welcome';
      }
      if (!isAuth &&
          !const {
            '/welcome',
            '/auth',
            '/login',
            '/register',
            '/forgot-password',
            '/login-callback',
            '/unlock',
          }.contains(location)) {
        return '/welcome';
      }
      if (isAuth &&
          const {
            '/welcome',
            '/auth',
            '/login',
            '/register',
            '/forgot-password',
            '/splash',
            '/',
            '/login-callback',
            '/unlock',
          }.contains(location)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PostLoginWelcomeScreen(),
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const UnlockScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/login-callback',
        builder: (context, state) => const OAuthCallbackScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => DashboardScreen(
          voiceShortcutRequested:
              state.uri.queryParameters['voiceShortcut'] == '1',
        ),
      ),
      GoRoute(
        path: '/voice-capture',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) {
          final extra = state.extra;
          final task = extra is Task ? extra : null;
          return FocusTimerScreen(
            controller: ref.read(focusSessionControllerProvider),
            taskId: task?.id,
            taskTitle: task?.title ?? 'Focus session',
            focusTarget: task == null
                ? const Duration(minutes: 25)
                : Duration(minutes: task.duration),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
