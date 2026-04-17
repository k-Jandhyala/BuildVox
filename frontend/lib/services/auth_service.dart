import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  static SupabaseClient get _c => SupabaseService.client;

  /// Demo emails → `app_users.role` (used when auto-creating a missing row).
  static String _roleForDemoEmail(String email) {
    switch (email.toLowerCase()) {
      case 'gc@demo.com':
        return 'gc';
      case 'manager@demo.com':
        return 'manager';
      case 'admin@demo.com':
        return 'admin';
      default:
        return 'worker';
    }
  }

  static String? _tradeForDemoEmail(String email) {
    switch (email.toLowerCase()) {
      case 'electrician@demo.com':
        return 'electrical';
      case 'plumber@demo.com':
        return 'plumbing';
      default:
        return null;
    }
  }

  static String _displayNameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  /// Creates `app_users` for this auth user if missing (e.g. UUID changed after Supabase migration).
  static Future<void> _ensureAppUserRow(String uid) async {
    final user = _c.auth.currentUser;
    if (user == null) return;
    final email = user.email ?? '';
    final role = _roleForDemoEmail(email);
    final trade = _tradeForDemoEmail(email);

    final row = <String, dynamic>{
      'id': uid,
      'email': email,
      'name': _displayNameFromEmail(email),
      'role': role,
    };
    if (trade != null) row['trade'] = trade;

    await _c.from('app_users').upsert(row);
  }

  /// Supabase Auth session changes (sign-in / sign-out / refresh).
  static Stream<Session?> get sessionStream =>
      _c.auth.onAuthStateChange.map((event) => event.session);

  /// Currently signed-in Supabase user (may be null).
  static User? get currentUser => _c.auth.currentUser;

  /// Sign in with email and password. Profile is loaded from `app_users` (id = auth user id).
  static Future<UserModel> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final uid = _c.auth.currentUser?.id;
    if (uid == null) {
      await _c.auth.signOut();
      throw Exception('Sign-in failed: no session.');
    }

    var row = await _c.from('app_users').select().eq('id', uid).maybeSingle();

    if (row == null) {
      try {
        await _ensureAppUserRow(uid);
        row = await _c.from('app_users').select().eq('id', uid).maybeSingle();
      } catch (_) {
        // RLS or constraint — fall through to error below
      }
    }

    if (row == null) {
      await _c.auth.signOut();
      throw Exception(
        'User profile not found in Supabase. '
        'Ensure app_users.id matches this user\'s UUID in Authentication. '
        'If the row exists in the Table Editor but login still fails, check RLS: '
        'signed-in clients use the `authenticated` role (not only `anon`).',
      );
    }

    return UserModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> signOut() async {
    await _c.auth.signOut();
  }

  static Future<UserModel?> getCurrentUserProfile() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return null;

    var row = await _c.from('app_users').select().eq('id', uid).maybeSingle();
    if (row == null) {
      try {
        await _ensureAppUserRow(uid);
        row = await _c.from('app_users').select().eq('id', uid).maybeSingle();
      } catch (_) {}
    }
    if (row == null) return null;

    return UserModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Live profile for the signed-in user (Realtime on `app_users`).
  static Stream<UserModel?> currentUserProfileStream() {
    return _c.auth.onAuthStateChange.asyncExpand((event) {
      final uid = event.session?.user.id;
      if (uid == null) return Stream<UserModel?>.value(null);
      return _c.from('app_users').stream(primaryKey: ['id']).eq('id', uid).map(
        (rows) {
          if (rows.isEmpty) return null;
          return UserModel.fromJson(Map<String, dynamic>.from(rows.first));
        },
      );
    });
  }
}
