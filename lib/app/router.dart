import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../features/api_docs/api_docs_page.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/billing/billing_page.dart';
import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/set_password_page.dart';
import '../features/corporate/corporate_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/pooling/pooling_page.dart';
import '../features/reports/reports_page.dart';
import '../features/roles/roles_page.dart';
import '../features/sim/sim_page.dart';
import '../features/users/users_page.dart';
import 'navigation.dart';
import 'portal_shell.dart';

const _guestRoutes = {'/login', '/forgot-password', '/set-password'};

/// Guards mirror Angular `authGuard` / `guestGuard` / `roleGuard`.
String? portalRedirect(AuthState auth, Uri uri) {
  // Keep the requested URL until the saved session is restored, then decide.
  if (auth.booting || auth.recoveryRequired) return null;
  final path = uri.path;
  final guest = _guestRoutes.contains(path);
  if (!auth.authenticated) return guest ? null : '/login';
  if (guest) return '/dashboard';
  final roles = restrictedRoutes[path];
  if (roles != null && !roles.contains(auth.user!.role)) return '/dashboard';
  return null;
}

GoRouter createRouter(AuthBloc auth) {
  NoTransitionPage<void> page(GoRouterState state, Widget child) => NoTransitionPage(key: state.pageKey, child: child);
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _StreamListenable(auth.stream.map((s) => (s.booting, s.authenticated, s.user?.role, s.recoveryRequired)).distinct()),
    redirect: (context, state) => portalRedirect(auth.state, state.uri),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/set-password', builder: (_, state) => SetPasswordPage(token: state.uri.queryParameters['token'] ?? '')),
      ShellRoute(
        builder: (context, state, child) => PortalShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (_, s) => page(s, const DashboardPage())),
          GoRoute(path: '/corporate', pageBuilder: (_, s) => page(s, const CorporatePage())),
          GoRoute(path: '/sim', pageBuilder: (_, s) => page(s, const SimPage())),
          GoRoute(path: '/pooling', pageBuilder: (_, s) => page(s, PoolingPage(poolId: s.uri.queryParameters['pool']))),
          GoRoute(path: '/users', pageBuilder: (_, s) => page(s, const UsersPage())),
          GoRoute(path: '/billing', pageBuilder: (_, s) => page(s, const BillingPage())),
          GoRoute(path: '/reports', pageBuilder: (_, s) => page(s, const ReportsPage())),
          GoRoute(path: '/roles', pageBuilder: (_, s) => page(s, const RolesPage())),
          GoRoute(path: '/api-docs', pageBuilder: (_, s) => page(s, const ApiDocsPage())),
        ],
      ),
    ],
    errorBuilder: (_, _) => const _UnknownRoute(),
  );
}

/// Unknown paths go to Dashboard (Angular `**` route).
class _UnknownRoute extends StatefulWidget {
  const _UnknownRoute();
  @override
  State<_UnknownRoute> createState() => _UnknownRouteState();
}

class _UnknownRouteState extends State<_UnknownRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.go('/dashboard'); });
  }
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) { _subscription = stream.listen((_) => notifyListeners()); }
  late final StreamSubscription<Object?> _subscription;
  @override
  void dispose() { _subscription.cancel(); super.dispose(); }
}
