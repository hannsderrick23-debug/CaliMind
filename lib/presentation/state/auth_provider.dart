import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:calimind/core/services/biometric_service.dart';
import 'package:calimind/core/services/push_notification_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/data/datasources/audit_remote_datasource.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticated,
  biometricLocked,
  mfaRequired,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final String? successMessage;
  final bool isLoading;
  final bool isPasswordRecovery;
  final bool biometricSetupPending;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.successMessage,
    this.isLoading = false,
    this.isPasswordRecovery = false,
    this.biometricSetupPending = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool? isLoading,
    bool? isPasswordRecovery,
    bool? biometricSetupPending,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        successMessage:
            clearSuccess ? null : (successMessage ?? this.successMessage),
        isLoading: isLoading ?? this.isLoading,
        isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
        biometricSetupPending:
            biometricSetupPending ?? this.biometricSetupPending,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuditRemoteDatasourceImpl _audit = AuditRemoteDatasourceImpl();
  final BiometricService _biometrics = BiometricService();
  StreamSubscription<supabase.AuthState>? _authSubscription;
  bool _lockRestoredSession = false;
  bool _passwordSignInInProgress = false;
  String? _pendingBiometricEmail;
  String? _pendingBiometricPassword;

  AuthNotifier() : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final biometricsEnabled = await _biometrics.isEnabled();
      _lockRestoredSession = session != null && biometricsEnabled;
      if (session != null) {
        state = AuthState(
          status: _lockRestoredSession
              ? AuthStatus.biometricLocked
              : AuthStatus.authenticated,
          user: session.user,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final session = event.session;
        if (session == null) {
          _lockRestoredSession = false;
          state = const AuthState(status: AuthStatus.unauthenticated);
        } else if (event.event == supabase.AuthChangeEvent.initialSession &&
            _lockRestoredSession) {
          state = AuthState(
            status: AuthStatus.biometricLocked,
            user: session.user,
          );
        } else {
          if (_passwordSignInInProgress &&
              event.event == supabase.AuthChangeEvent.signedIn) {
            return;
          }
          _lockRestoredSession = false;
          state = AuthState(
            status: AuthStatus.authenticated,
            user: session.user,
            isPasswordRecovery:
                event.event == supabase.AuthChangeEvent.passwordRecovery,
          );
        }
      });
    } catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Could not initialize authentication: $error',
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    _passwordSignInInProgress = true;
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _audit.writeLog('SIGN_IN');
        var shouldOfferSetup = false;
        if (!await _biometrics.isEnabled() &&
            !await _biometrics.hasPromptedForSetup() &&
            await _biometrics.isBiometricsAvailable()) {
          shouldOfferSetup = true;
          await _biometrics.markSetupPrompted();
          _pendingBiometricEmail = email;
          _pendingBiometricPassword = password;
        }
        state = AuthState(
          status: AuthStatus.authenticated,
          user: res.user,
          biometricSetupPending: shouldOfferSetup,
        );
      } else {
        state = state.copyWith(
            isLoading: false, errorMessage: 'Sign in did not return a user.');
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Sign in failed. Please try again.');
    } finally {
      _passwordSignInInProgress = false;
    }
  }

  Future<bool> verifyPasswordForBiometricSetup(
    String email,
    String password,
  ) async {
    final wasSigningIn = _passwordSignInInProgress;
    _passwordSignInInProgress = true;
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return true;
    } on AuthException {
      return false;
    } finally {
      _passwordSignInInProgress = wasSigningIn;
    }
  }

  Future<void> finishBiometricSetup({required bool enable}) async {
    if (enable) {
      final email = _pendingBiometricEmail;
      final password = _pendingBiometricPassword;
      if (email == null || password == null) {
        state = state.copyWith(
          errorMessage: 'Sign in again to set up biometric sign-in.',
        );
        return;
      }
      try {
        await _biometrics.saveLoginCredentials(email, password);
      } catch (error) {
        debugPrint(
            'Could not securely save biometric sign-in credentials: $error');
        _pendingBiometricEmail = null;
        _pendingBiometricPassword = null;
        state = state.copyWith(
          biometricSetupPending: false,
          errorMessage: 'Could not save secure sign-in details on this device.',
        );
        return;
      }
    }
    _pendingBiometricEmail = null;
    _pendingBiometricPassword = null;
    state = state.copyWith(biometricSetupPending: false, clearError: true);
  }

  Future<void> signUp(
    String email,
    String password, {
    required String termsVersion,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'terms_version': termsVersion,
        },
      );
      if (res.session != null && res.user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: res.user);
      } else if (res.user != null) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          successMessage:
              'Account created. Check your email to confirm your address.',
        );
      } else {
        state = state.copyWith(
            isLoading: false,
            errorMessage: 'Account creation did not return a user.');
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: 'Sign up failed. Please try again.');
    }
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.calimind://login-callback',
      );
      if (!launched) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not start ${provider.name} sign in.',
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '${provider.name} sign in failed. Please try again.',
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.calimind://login-callback',
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        successMessage: 'Password reset link sent. Check your email.',
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not send the reset link. Please try again.',
      );
    }
  }

  Future<void> updatePassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not update your password. Please try again.',
      );
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = state.user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Sign in again before updating your profile.',
      );
      return;
    }

    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': displayName.trim()}),
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: response.user ?? user,
        successMessage: 'Your profile has been updated.',
      );
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not update your profile. Please try again.',
      );
    }
  }

  Future<bool> signOut() async {
    final user = state.user ?? Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;
    if (metadataName != null) {
      try {
        await _biometrics.rememberDisplayName(metadataName);
      } catch (error) {
        debugPrint('Could not save the remembered display name: $error');
      }
    }
    await PushNotificationService.instance.unregisterCurrentDevice();
    await WidgetService.clearPublishedTaskTitle();
    try {
      await Supabase.instance.client.auth.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return true;
    } catch (error) {
      debugPrint('Could not sign out from the remote auth session: $error');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not sign out. Please try again.',
      );
      return false;
    }
  }

  Future<bool> biometricUnlock() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || !await _biometrics.isEnabled()) return false;

    final authenticated = await _biometrics.authenticate(
      localizedReason: 'Unlock CaliMind',
    );
    if (authenticated) {
      _lockRestoredSession = false;
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
    }
    return authenticated;
  }

  Future<bool> biometricSignIn() async {
    if (state.status == AuthStatus.biometricLocked && state.user != null) {
      return biometricUnlock();
    }

    final credentials = await _biometrics.loginCredentials();
    if (credentials == null || !await _biometrics.isEnabled()) {
      state = state.copyWith(
        errorMessage:
            'Set up biometric sign-in after signing in with your password.',
      );
      return false;
    }

    final authenticated = await _biometrics.authenticate(
      localizedReason: 'Confirm your identity to sign in to CaliMind',
    );
    if (!authenticated) {
      state = state.copyWith(
        errorMessage:
            'Biometric check was cancelled. You can use your password instead.',
      );
      return false;
    }

    await signIn(credentials.$1, credentials.$2);
    return state.status == AuthStatus.authenticated;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
