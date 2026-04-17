import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Current Supabase session (null when signed out).
final supabaseSessionProvider = StreamProvider<Session?>((ref) {
  return AuthService.sessionStream;
});

/// Watches `app_users` for the signed-in Supabase user (id = auth.users.id).
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  return AuthService.currentUserProfileStream();
});

/// Manages sign-in and sign-out with loading/error state.
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  /// `data(null)` means "no explicit profile from this notifier" — session + profile
  /// still come from [userProfileProvider] (see [currentUserProvider]).
  AuthNotifier() : super(const AsyncValue.data(null));

  /// Returns the signed-in profile. Rethrows on failure so callers can show errors.
  Future<UserModel> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.signIn(email, password);
      try {
        await NotificationService.refreshTokenForCurrentUser();
      } catch (e, st) {
        debugPrint('[FCM] refreshTokenForCurrentUser failed (sign-in still OK): $e');
        debugPrint('$st');
      }
      state = AsyncValue.data(user);
      return user;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier();
});

/// Current profile (role, company, projects, …).
///
/// Merges [authNotifierProvider] (set immediately on sign-in) with
/// [userProfileProvider] (Realtime stream — can lag behind sign-in).
/// Without this merge, [currentUserProvider] is often null right after login
/// even when the profile exists, which misroutes to "profile not found".
final currentUserProvider = Provider<UserModel?>((ref) {
  final session = ref.watch(supabaseSessionProvider).valueOrNull;
  final authAsync = ref.watch(authNotifierProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;

  final explicitUser = authAsync.maybeWhen(
    data: (u) => u,
    orElse: () => null,
  );
  if (explicitUser != null) return explicitUser;

  if (session == null) return null;

  return authAsync.maybeWhen(
    data: (u) => u ?? profile,
    orElse: () => profile,
  );
});
