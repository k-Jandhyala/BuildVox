import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/worker/worker_home.dart';
import 'screens/worker/task_detail_screen.dart';
import 'screens/electrician/ai_review_screen.dart';
import 'screens/electrician/electrician_shell_screen.dart';
import 'screens/electrician/electrician_task_detail_screen.dart';
import 'screens/plumber/plumber_shell_screen.dart';
import 'screens/plumber/plumber_task_detail_screen.dart';
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
const String kRouteElectrician = '/electrician';
const String kRoutePlumber = '/plumber';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final session = ref.read(supabaseSessionProvider).valueOrNull;
      final isSignedIn = session != null;
      final isLoginRoute = state.uri.path == '/login';

      if (!isSignedIn) {
        return isLoginRoute ? null : '/login';
      }

      if (isSignedIn && isLoginRoute) {
        final userProfile = ref.read(currentUserProvider);
        return _homeRouteForUser(userProfile);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/worker',
        builder: (context, state) {
          final user = ref.read(currentUserProvider);
          final isElectrician =
              user?.role == UserRole.worker && user?.trade == TradeType.electrical;
          final isPlumber =
              user?.role == UserRole.worker && user?.trade == TradeType.plumbing;
          if (isElectrician) return const ElectricianShellScreen();
          if (isPlumber) return const PlumberShellScreen();
          return const WorkerHome();
        },
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
        path: '/electrician',
        builder: (context, state) => const ElectricianShellScreen(),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return ElectricianTaskDetailScreen(
                taskId: taskId,
                extractedItemId: extra?['extractedItemId'] as String? ?? '',
              );
            },
          ),
          GoRoute(
            path: 'ai-review',
            builder: (context, state) => const AiReviewScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/plumber',
        builder: (context, state) => const PlumberShellScreen(),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return PlumberTaskDetailScreen(
                taskId: taskId,
                extractedItemId: extra?['extractedItemId'] as String? ?? '',
              );
            },
          ),
          GoRoute(
            path: 'ai-review',
            builder: (context, state) => const AiReviewScreen(),
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

String _homeRouteForUser(UserModel? user) {
  if (user?.role == UserRole.worker && user?.trade == TradeType.electrical) {
    return '/electrician';
  }
  if (user?.role == UserRole.worker && user?.trade == TradeType.plumbing) {
    return '/plumber';
  }
  return _homeRouteForRole(user?.role);
}

/// Triggers GoRouter redirect when Supabase session or profile changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(supabaseSessionProvider, (_, __) => notifyListeners());
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}
