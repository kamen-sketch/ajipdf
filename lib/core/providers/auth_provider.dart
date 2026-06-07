import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication state model
class AuthState {
  final String? userId;
  final String? email;
  final String? displayName;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.userId,
    this.email,
    this.displayName,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => userId != null;

  AuthState copyWith({
    String? userId,
    String? email,
    String? displayName,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _initAuth();
  }

  final _controller = StreamController<AuthState>.broadcast();
  @override
  Stream<AuthState> get stream => _controller.stream;

  void _initAuth() {
    // Check for stored auth token on app start
    // This will be implemented with Firebase Auth
    state = const AuthState();
  }

  /// Login with email and password
  Future<bool> loginWithEmailPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Implement Firebase Auth login
      await Future.delayed(const Duration(seconds: 1)); // Simulated delay

      // Simulated successful login
      state = AuthState(
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: email.split('@').first,
        isLoading: false,
      );

      _controller.add(state);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
      return false;
    }
  }

  /// Register with email and password
  Future<bool> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Implement Firebase Auth registration
      await Future.delayed(const Duration(seconds: 1)); // Simulated delay

      // Simulated successful registration
      state = AuthState(
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
        isLoading: false,
      );

      _controller.add(state);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
      return false;
    }
  }

  /// Login with Google
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Implement Google Sign In
      await Future.delayed(const Duration(seconds: 1)); // Simulated delay

      // Simulated successful login
      state = AuthState(
        userId: 'google_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'user@gmail.com',
        displayName: 'Google User',
        isLoading: false,
      );

      _controller.add(state);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
      return false;
    }
  }

  /// Login with Apple
  Future<bool> loginWithApple() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Implement Apple Sign In
      await Future.delayed(const Duration(seconds: 1)); // Simulated delay

      // Simulated successful login
      state = AuthState(
        userId: 'apple_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'user@icloud.com',
        displayName: 'Apple User',
        isLoading: false,
      );

      _controller.add(state);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Implement Firebase password reset
      await Future.delayed(const Duration(seconds: 1)); // Simulated delay

      state = state.copyWith(isLoading: false);
      _controller.add(state);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      // TODO: Implement Firebase Auth logout
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulated delay

      state = const AuthState();
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _controller.add(state);
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

/// Provider for authentication state
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});

/// Provider to get current user
final currentUserProvider = Provider<AuthState?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated ? authState : null;
});
