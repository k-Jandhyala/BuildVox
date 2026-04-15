import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

// ── Raw Firebase auth state ───────────────────────────────────────────────────

/// Emits the raw Firebase [User] (or null) whenever auth state changes.
final firebaseAuthProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

// ── Firestore user profile ────────────────────────────────────────────────────

/// Watches the current user's Firestore document in real time.
/// Returns null when not signed in.
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return AuthService.currentUserProfileStream();
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ── Auth state notifier ───────────────────────────────────────────────────────

/// Manages sign-in and sign-out with loading/error state.
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  AuthNotifier() : super(const AsyncValue.loading());

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.signIn(email, password);
      // Register FCM token after sign-in
      await NotificationService.refreshTokenForCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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

// ── Convenience selector ──────────────────────────────────────────────────────

/// Current UserModel from the live Firestore stream.
/// Use this throughout the app to get role, companyId, etc.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(userProfileProvider).valueOrNull;
});
