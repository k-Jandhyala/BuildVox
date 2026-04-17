import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// HTTP calls to Firebase Cloud Functions with `Authorization: Bearer <Supabase access token>`.
/// Configure base URL via dart-define (see `dev-up.sh`).
class FunctionsService {
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'buildvox',
  );
  static const String _region = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );
  static const bool _useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );
  static const String _emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  static String get _baseUrl {
    if (_useEmulator) {
      return 'http://$_emulatorHost:5001/$_projectId/$_region';
    }
    return 'https://$_region-$_projectId.cloudfunctions.net';
  }

  static Future<Map<String, dynamic>> _post(
    String functionName,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      throw Exception('Not signed in');
    }
    final uri = Uri.parse('$_baseUrl/$functionName');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode(body),
        )
        .timeout(functionName == 'submitVoiceMemo'
            ? const Duration(seconds: 300)
            : timeout);

    Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map,
      );
    } catch (_) {
      throw Exception('Invalid response (${resp.statusCode}): ${resp.body}');
    }

    if (resp.statusCode >= 400) {
      final err = json['error'];
      throw Exception(err is String ? err : resp.body);
    }
    return json;
  }

  static Future<Map<String, dynamic>> submitVoiceMemo({
    required String audioUrl,
    String? storagePath,
    required String projectId,
    required String siteId,
    String mimeType = 'audio/mp4',
  }) async {
    return _post(
      'submitVoiceMemo',
      {
        'audioUrl': audioUrl,
        if (storagePath != null) 'storagePath': storagePath,
        'projectId': projectId,
        'siteId': siteId,
        'mimeType': mimeType,
      },
      timeout: const Duration(seconds: 300),
    );
  }

  static Future<Map<String, dynamic>> startVoiceMemoProcessing({
    required String audioUrl,
    required String storagePath,
    required String projectId,
    required String siteId,
    required String mimeType,
    List<String>? photoUrls,
  }) async {
    return _post('startVoiceMemoProcessing', {
      'audioUrl': audioUrl,
      'storagePath': storagePath,
      'projectId': projectId,
      'siteId': siteId,
      'mimeType': mimeType,
      if (photoUrls != null) 'photoUrls': photoUrls,
    });
  }

  static Future<Map<String, dynamic>> pollVoiceMemoProcessing({
    required String requestId,
  }) async {
    return _post('pollVoiceMemoProcessing', {'requestId': requestId});
  }

  static Future<Map<String, dynamic>> submitReviewedItems({
    required String requestId,
    required String projectId,
    required String siteId,
    required List<Map<String, dynamic>> items,
  }) async {
    return _post('submitReviewedItems', {
      'requestId': requestId,
      'projectId': projectId,
      'siteId': siteId,
      'items': items,
    }, timeout: const Duration(seconds: 180));
  }

  static Future<Map<String, dynamic>> assignTask({
    required String extractedItemId,
    required String assignedToUserId,
    String? dueDate,
  }) async {
    return _post('assignTask', {
      'extractedItemId': extractedItemId,
      'assignedToUserId': assignedToUserId,
      if (dueDate != null) 'dueDate': dueDate,
    });
  }

  static Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    await _post('updateTaskStatus', {'taskId': taskId, 'status': status});
  }

  static Future<void> addTaskUpdate({
    required String taskId,
    required String updateType,
    String? text,
    String? audioUrl,
    List<String>? photoUrls,
  }) async {
    await _post('addTaskUpdate', {
      'taskId': taskId,
      'updateType': updateType,
      if (text != null) 'text': text,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (photoUrls != null) 'photoUrls': photoUrls,
    });
  }

  static Future<void> escalateTask({
    required String taskId,
    required String reason,
    required String details,
  }) async {
    await _post('escalateTask', {
      'taskId': taskId,
      'reason': reason,
      'details': details,
    });
  }

  static Future<void> requestMaterials({
    required String projectId,
    required String siteId,
    required String itemName,
    required int quantity,
    required String supplier,
    String? notes,
    String? taskId,
    List<String>? photoUrls,
  }) async {
    await _post('requestMaterials', {
      'projectId': projectId,
      'siteId': siteId,
      'itemName': itemName,
      'quantity': quantity,
      'supplier': supplier,
      if (notes != null) 'notes': notes,
      if (taskId != null) 'taskId': taskId,
      if (photoUrls != null) 'photoUrls': photoUrls,
    });
  }

  static Future<void> flagBlocker({
    required String projectId,
    required String siteId,
    required String blockedWork,
    required String location,
    required String severity,
    String? taskId,
    List<String>? photoUrls,
  }) async {
    await _post('flagBlocker', {
      'projectId': projectId,
      'siteId': siteId,
      'blockedWork': blockedWork,
      'location': location,
      'severity': severity,
      if (taskId != null) 'taskId': taskId,
      if (photoUrls != null) 'photoUrls': photoUrls,
    });
  }

  static Future<Map<String, dynamic>> generateDailyDigest({
    required String projectId,
    String? dateKey,
  }) async {
    return _post('generateDailyDigest', {
      'projectId': projectId,
      if (dateKey != null) 'dateKey': dateKey,
    });
  }

  static Future<Map<String, dynamic>> seedDemoData() async {
    return _post('seedDemoDataFn', {}, timeout: const Duration(seconds: 120));
  }
}
