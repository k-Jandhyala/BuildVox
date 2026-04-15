import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  /// Initialize FCM: request permission, create Android channel, get token.
  static Future<void> initialize() async {
    // Request notification permission (Android 13+)
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

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title}',
      );
      // In a production app you'd show a local notification here.
      // For the MVP, the Firestore notification collection is the source of truth.
    });
  }

  static Future<void> _setupTokenRefresh() async {
    // Get current token and save it
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Listen for token refreshes
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      await FirestoreService.upsertFcmToken(uid, token);
      debugPrint('[FCM] Token saved to Firestore');
    }
  }

  /// Call this after login to ensure the token is registered.
  static Future<void> refreshTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }
}
