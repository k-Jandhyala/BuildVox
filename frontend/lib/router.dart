import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/worker/worker_home.dart';
import 'screens/worker/task_detail_screen.dart';
import 'screens/gc/gc_home.dart';
import 'screens/manager/manager_home.dart';
import 'screens/admin/admin_home.dart';

// Route names
const String kRouteLogin = '/login';
const String kRouteWorker = '/worker';
const String kRouteGc = '/gc';
const String kRouteManager = '/manager';
const String kRouteAdmin = '/admin';
const String kRouteTaskDetail = '/task/:taskId';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final authValue = ref.read(firebaseAuthProvider);
      final isSignedIn = authValue.valueOrNull != null;
      final isLoginRoute = state.uri.path == '/login';

      // Not signed in → send to login
      if (!isSignedIn) {
        return isLoginRoute ? null : '/login';
      }

      // Signed in but on login page → route to role-appropriate home
      if (isSignedIn && isLoginRoute) {
        final userProfile = ref.read(currentUserProvider);
        return _homeRouteForRole(userProfile?.role);
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/worker',
        builder: (context, state) => const WorkerHome(),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return TaskDetailScreen(
                taskId: taskId,
                extractedItemId: extra?['extractedItemId'] as String? ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/gc',
        builder: (context, state) => const GcHome(),
      ),
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerHome(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHome(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

String _homeRouteForRole(UserRole? role) {
  switch (role) {
    case UserRole.worker:
      return '/worker';
    case UserRole.gc:
      return '/gc';
    case UserRole.manager:
      return '/manager';
    case UserRole.admin:
      return '/admin';
    default:
      return '/login';
  }
}

/// A [ChangeNotifier] that triggers GoRouter to re-evaluate redirects
/// when the auth state changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(ProviderRef ref) {
    ref.listen(firebaseAuthProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}
