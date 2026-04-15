import 'package:cloud_functions/cloud_functions.dart';

/// Wraps all Cloud Function callable invocations.
/// For local emulator testing, call [useEmulator] in main.dart.
class FunctionsService {
  static final _functions = FirebaseFunctions.instance;

  /// Call this in main() to use the local emulator.
  /// Usage: FunctionsService.useEmulator('10.0.2.2', 5001);
  ///   (10.0.2.2 is the Android emulator loopback to your host machine)
  static void useEmulator(String host, int port) {
    _functions.useFunctionsEmulator(host, port);
  }

  /// Submit a voice memo for processing.
  ///
  /// [storagePath] — Firebase Storage path of the uploaded audio
  /// [projectId] — Firestore project document ID
  /// [siteId] — Firestore job_site document ID
  /// [mimeType] — audio MIME type (e.g. 'audio/mp4')
  ///
  /// Returns: { success, memoId, itemCount?, error? }
  static Future<Map<String, dynamic>> submitVoiceMemo({
    required String storagePath,
    required String projectId,
    required String siteId,
    String mimeType = 'audio/mp4',
  }) async {
    final callable = _functions.httpsCallable(
      'submitVoiceMemo',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
    );

    final result = await callable.call({
      'storagePath': storagePath,
      'projectId': projectId,
      'siteId': siteId,
      'mimeType': mimeType,
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Assign an extracted item to a worker.
  ///
  /// Returns: { success, taskId }
  static Future<Map<String, dynamic>> assignTask({
    required String extractedItemId,
    required String assignedToUserId,
    String? dueDate,
  }) async {
    final callable = _functions.httpsCallable('assignTask');
    final result = await callable.call({
      'extractedItemId': extractedItemId,
      'assignedToUserId': assignedToUserId,
      if (dueDate != null) 'dueDate': dueDate,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Update the status of a task assignment.
  ///
  /// [status] must be one of: pending, acknowledged, in_progress, done, cancelled
  ///
  /// Returns: { success }
  static Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final callable = _functions.httpsCallable('updateTaskStatus');
    await callable.call({'taskId': taskId, 'status': status});
  }

  /// Generate the daily digest for a project.
  ///
  /// Returns: { success, digestId, summary, itemCount }
  static Future<Map<String, dynamic>> generateDailyDigest({
    required String projectId,
    String? dateKey,
  }) async {
    final callable = _functions.httpsCallable('generateDailyDigest');
    final result = await callable.call({
      'projectId': projectId,
      if (dateKey != null) 'dateKey': dateKey,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Seed demo data. Only works if the calling user is an admin,
  /// or if called for the first time before any users exist.
  ///
  /// Returns: { message, created }
  static Future<Map<String, dynamic>> seedDemoData() async {
    final callable = _functions.httpsCallable(
      'seedDemoDataFn',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    final result = await callable.call({});
    return Map<String, dynamic>.from(result.data as Map);
  }
}
