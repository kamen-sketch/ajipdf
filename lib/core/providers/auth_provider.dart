import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/error_reporter.dart';
import '../services/hive_service.dart';

/// Authentication state model
class AuthState {
  final String? userId;
  final String? email;
  final String? displayName;
  final String? token;
  final String? role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.userId,
    this.email,
    this.displayName,
    this.token,
    this.role,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => userId != null && token != null;

  AuthState copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? token,
    String? role,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      token: token ?? this.token,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Authentication state notifier connected to backend API
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _initAuth();
  }

  final _controller = StreamController<AuthState>.broadcast();
  @override
  Stream<AuthState> get stream => _controller.stream;

  /// Check stored token on app start and validate with backend
  Future<void> _initAuth() async {
    final storedToken =
        HiveService.instance.getPreference<String>('auth_token');

    if (storedToken == null || storedToken.isEmpty) {
      state = const AuthState();
      _controller.add(state);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final response = await ApiService.instance.get('/auth/me');
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      state = AuthState(
        userId: data['id']?.toString(),
        email: data['email'] as String?,
        displayName:
            data['display_name'] as String? ?? data['displayName'] as String?,
        token: storedToken,
        role: data['role'] as String?,
        isLoading: false,
      );
      _controller.add(state);
    } catch (e, st) {
      // Token invalid or network error — clear and reset
      await ApiService.instance.setToken(null);
      state = const AuthState();
      _controller.add(state);
      ErrorReporter.instance
          .reportError(e, st, screen: 'AuthProvider', action: '_initAuth');
    }
  }

  /// Login with email and password via backend API
  Future<bool> loginWithEmailPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    ErrorReporter.instance.addBreadcrumb('Auth', 'login_attempt');

    try {
      final response = await ApiService.instance.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final body = response.data as Map<String, dynamic>;
      final payload = body['data'] as Map<String, dynamic>? ?? body;
      final jwt = payload['token'] as String;

      await ApiService.instance.setToken(jwt);

      final user = payload['user'] as Map<String, dynamic>? ?? payload;

      state = AuthState(
        userId: user['id']?.toString(),
        email: user['email'] as String? ?? email,
        displayName: user['displayName'] as String? ?? user['name'] as String?,
        token: jwt,
        role: user['role'] as String?,
        isLoading: false,
      );

      _controller.add(state);
      ErrorReporter.instance.addBreadcrumb('Auth', 'login_success');
      return true;
    } catch (e, st) {
      final message = _extractErrorMessage(e) ?? 'Login gagal';
      state = state.copyWith(isLoading: false, error: message);
      _controller.add(state);
      ErrorReporter.instance
          .reportError(e, st, screen: 'Auth', action: 'loginWithEmailPassword');
      return false;
    }
  }

  /// Register with email and password via backend API
  Future<bool> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    ErrorReporter.instance.addBreadcrumb('Auth', 'register_attempt');

    try {
      final response = await ApiService.instance.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final payload = body['data'] as Map<String, dynamic>? ?? body;
      final jwt = payload['token'] as String;

      await ApiService.instance.setToken(jwt);

      final user = payload['user'] as Map<String, dynamic>? ?? payload;

      state = AuthState(
        userId: user['id']?.toString(),
        email: user['email'] as String? ?? email,
        displayName: user['displayName'] as String? ??
            user['name'] as String? ??
            displayName,
        token: jwt,
        role: user['role'] as String?,
        isLoading: false,
      );

      _controller.add(state);
      ErrorReporter.instance.addBreadcrumb('Auth', 'register_success');
      return true;
    } catch (e, st) {
      final message = _extractErrorMessage(e) ?? 'Registrasi gagal';
      state = state.copyWith(isLoading: false, error: message);
      _controller.add(state);
      ErrorReporter.instance.reportError(e, st,
          screen: 'Auth', action: 'registerWithEmailPassword');
      return false;
    }
  }

  /// Login with Google — stub, OAuth not configured
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(
      isLoading: false,
      error: 'OAuth belum dikonfigurasi',
    );
    _controller.add(state);
    return false;
  }

  /// Login with Apple — stub, OAuth not configured
  Future<bool> loginWithApple() async {
    state = state.copyWith(
      isLoading: false,
      error: 'OAuth belum dikonfigurasi',
    );
    _controller.add(state);
    return false;
  }

  /// Send password reset email — stub
  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: false, error: null);
    _controller.add(state);
    // Inform user to contact admin
    state = state.copyWith(
      isLoading: false,
      error: 'Hubungi admin untuk reset password',
    );
    _controller.add(state);
    return false;
  }

  /// Logout — clear token and reset state
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    ErrorReporter.instance.addBreadcrumb('Auth', 'logout');

    try {
      await ApiService.instance.setToken(null);
      state = const AuthState();
      _controller.add(state);
    } catch (e, st) {
      // Even if something fails, force clear state
      state = const AuthState();
      _controller.add(state);
      ErrorReporter.instance
          .reportError(e, st, screen: 'Auth', action: 'logout');
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Extract error message from DioException or generic error
  String? _extractErrorMessage(dynamic e) {
    if (e is Exception) {
      try {
        // Try to extract message from Dio response
        final dynamic dioError = e;
        final response = (dioError as dynamic).response;
        if (response != null && response.data is Map) {
          return response.data['message'] as String?;
        }
      } catch (_) {}
    }
    return null;
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
