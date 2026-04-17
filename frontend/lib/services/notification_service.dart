import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'database_service.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '[FCM] Authorization status: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _setupTokenRefresh();
    }

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title}',
      );
    });
  }

  static Future<void> _setupTokenRefresh() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final uid = AuthService.currentUser?.id;
    if (uid != null) {
      await DatabaseService.upsertFcmToken(uid, token);
      debugPrint('[FCM] Token saved to Supabase');
    }
  }

  static Future<void> refreshTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }
}
