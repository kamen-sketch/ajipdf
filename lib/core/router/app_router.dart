import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/pdf_viewer/presentation/screens/pdf_viewer_screen.dart';
import '../../features/pdf_editor/presentation/screens/pdf_editor_screen.dart';
import '../../features/pdf_editor/presentation/screens/rotate_reorder_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/signature/presentation/screens/signature_screen.dart';
import '../../features/annotations/presentation/screens/annotation_screen.dart';
import '../../features/ocr/presentation/screens/ocr_screen.dart';
import '../../features/scan/presentation/screens/scan_to_pdf_screen.dart';

import '../providers/auth_provider.dart';

/// Router configuration for the application
/// Uses go_router for declarative routing with authentication guards

/// Provider for router configuration
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      ref.read(authStateProvider.notifier).stream,
    ),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Authentication routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main app routes (requires authentication)
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // PDF Viewer
      GoRoute(
        path: '/viewer',
        name: 'viewer',
        builder: (context, state) {
          final filePath = state.uri.queryParameters['file'];
          return PDFViewerScreen(filePath: filePath);
        },
      ),

      // PDF Editor
      GoRoute(
        path: '/editor',
        name: 'editor',
        builder: (context, state) {
          final operation = state.uri.queryParameters['operation'];
          return PDFEditorScreen(operation: operation);
        },
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Subscription
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),

      // Digital Signature
      GoRoute(
        path: '/signature',
        name: 'signature',
        builder: (context, state) => const SignatureScreen(),
      ),

      // Annotations
      GoRoute(
        path: '/annotations',
        name: 'annotations',
        builder: (context, state) => const AnnotationScreen(),
      ),

      // OCR
      GoRoute(
        path: '/ocr',
        name: 'ocr',
        builder: (context, state) => const OCRScreen(),
      ),

      // Rotate & Reorder
      GoRoute(
        path: '/rotate-reorder',
        name: 'rotate-reorder',
        builder: (context, state) => const RotateReorderScreen(),
      ),

      // Scan to PDF
      GoRoute(
        path: '/scan',
        name: 'scan',
        builder: (context, state) => const ScanToPdfScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Text(
          'Page not found: ${state.error?.toString() ?? "Unknown error"}',
          style: AppTheme.textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

/// Helper class to make StateNotifier work with GoRouter refreshListenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
