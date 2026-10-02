import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../presentation/main_layout.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

import '../../features/records/presentation/pages/records_page.dart';
import '../../features/finances/presentation/pages/finances_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/invoices/presentation/invoice_form_screen.dart';
import '../../features/users/presentation/pages/users_page.dart';

import '../../features/splash/presentation/splash_screen.dart';
import '../../features/patients/presentation/patient_form_screen.dart';

/// Notifier that triggers GoRouter redirects whenever Auth or Profile state updates,
/// WITHOUT destroying and re-instantiating the GoRouter instance.
/// This prevents losing the current screen (e.g. /register or /invoices) when the app is minimized.
class AppRouterNotifier extends ChangeNotifier {
  final Ref _ref;

  AppRouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (prev, next) => notifyListeners());
    _ref.listen(userProfileProvider, (prev, next) => notifyListeners());
    _ref.listen(splashCompletedProvider, (prev, next) => notifyListeners());
  }
}

final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      final splashCompleted = ref.read(splashCompletedProvider);
      if (!splashCompleted) {
        return isSplash ? null : '/splash';
      }

      final authState = ref.read(authStateProvider);
      if (authState.isLoading) {
        // While re-authenticating or reconnecting on app resume,
        // do NOT kick the user out of where they already are!
        return null;
      }

      final user = authState.value;
      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      final userProfile = ref.read(userProfileProvider);
      // If user is logged in, wait for profile or use fallback without redirecting away
      if (userProfile.isLoading && !userProfile.hasValue) {
        return null;
      }

      final profile = userProfile.value;
      if (profile == null) {
        return isLoggingIn ? null : '/login';
      }

      // Check if the account has been deactivated
      final status = (profile['status'] ?? 'active').toString().toLowerCase();
      if (status == 'deactivated' || status == 'disabled' || status == 'inactive') {
        // Defer provider modification out of the synchronous widget build lifecycle
        Future.microtask(() {
          ref.read(loginErrorMessageProvider.notifier).setMessage(
            'Your account has been deactivated. Please contact an administrator.',
          );
          ref.read(authControllerProvider).logout();
        });
        return '/login';
      }

      final role = (profile['role'] ?? 'staff').toString().toLowerCase();

      // Only redirect to dashboard if the user is on /login, /, or /splash.
      // If they are on /register, /invoices, /records, /finances, keep them there!
      if (isLoggingIn || state.matchedLocation == '/' || state.matchedLocation == '/splash') {
         return '/dashboard';
      }

      // Role-based protection
      if (role == 'staff') {
        final loc = state.matchedLocation;
        if (loc.startsWith('/users')) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const PatientFormScreen(),
          ),
          GoRoute(
            path: '/records',
            builder: (context, state) => const RecordsPage(),
          ),
          GoRoute(
            path: '/finances',
            builder: (context, state) => const FinancesPage(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesPage(),
          ),
          GoRoute(
            path: '/invoices/new',
            builder: (context, state) {
              final patientId = state.uri.queryParameters['patientId'];
              final defaultDaysStr = state.uri.queryParameters['defaultDays'];
              final defaultDays = defaultDaysStr != null ? int.tryParse(defaultDaysStr) ?? 15 : 15;
              return InvoiceFormScreen(patientId: patientId, defaultDays: defaultDays);
            },
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
        ],
      ),
    ],
  );
});
