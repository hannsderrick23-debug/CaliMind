import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/services/biometric_service.dart';
import 'package:calimind/data/datasources/audit_remote_datasource.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, mfaRequired }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuditRemoteDatasourceImpl _audit = AuditRemoteDatasourceImpl();
  final BiometricService _biometrics = BiometricService();

  AuthNotifier() : super(const AuthState()) {
    _initialize();
  }

  void _initialize() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        state = AuthState(status: AuthStatus.authenticated, user: session.user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

      Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final session = event.session;
        if (session == null) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        } else {
          state = AuthState(status: AuthStatus.authenticated, user: session.user);
        }
      });
    } catch (_) {
      // Mock/offline mode — treat as authenticated with demo user
      state = const AuthState(status: AuthStatus.authenticated);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _audit.writeLog('SIGN_IN');
        state = AuthState(status: AuthStatus.authenticated, user: res.user);
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Sign in failed. Please try again.');
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) {
        state = AuthState(status: AuthStatus.authenticated, user: res.user);
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Sign up failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> biometricUnlock() async {
    return _biometrics.authenticate(localizedReason: 'Unlock CaliMind');
  }

  // Demo/mock sign in for offline mode
  void signInAsMockUser() {
    state = const AuthState(status: AuthStatus.authenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
