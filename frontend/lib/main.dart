import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/functions_service.dart';
import 'services/notification_service.dart';

/// Top-level FCM background message handler.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── EMULATOR CONFIGURATION ────────────────────────────────────────────────
  // Uncomment these lines when using `firebase emulators:start` for local dev.
  // Use 10.0.2.2 for Android emulator → points to your host machine.
  // Use your LAN IP (e.g. 192.168.1.10) for physical devices on same network.
  //
  // FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
  // FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
  // FirebaseStorage.instance.useStorageEmulator('10.0.2.2', 9199);
  // FunctionsService.useEmulator('10.0.2.2', 5001);
  // ─────────────────────────────────────────────────────────────────────────

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notification channel for Android
  await NotificationService.initialize();

  runApp(
    // ProviderScope is required for Riverpod
    const ProviderScope(
      child: BuildVoxApp(),
    ),
  );
}
