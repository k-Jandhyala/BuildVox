import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// Uploads an audio file to Firebase Storage.
  ///
  /// Path: audio/{userId}/{timestamp}_{uuid}.{ext}
  ///
  /// Returns the storage path (not a download URL) so the backend can
  /// read the file directly via the Admin SDK.
  static Future<String> uploadAudio(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final ext = p.extension(file.path).toLowerCase();
    final safeExt = _sanitizeExt(ext);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4().substring(0, 8);
    final fileName = '${timestamp}_$id.$safeExt';
    final storagePath = 'audio/$uid/$fileName';

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: _mimeTypeForExt(safeExt),
    );

    final task = ref.putFile(file, metadata);

    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    await task;
    return storagePath;
  }

  static String _sanitizeExt(String ext) {
    // Normalize common audio extensions
    final clean = ext.replaceAll('.', '').toLowerCase();
    const allowed = {'m4a', 'mp3', 'wav', 'ogg', 'aac', 'mp4', 'webm', 'flac'};
    return allowed.contains(clean) ? clean : 'm4a';
  }

  static String _mimeTypeForExt(String ext) {
    switch (ext) {
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'mp4':
        return 'audio/mp4';
      case 'webm':
        return 'audio/webm';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mp4';
    }
  }

  /// Returns the MIME type that should be passed to the backend
  /// for a given storage path.
  static String getMimeType(String storagePath) {
    final ext = p.extension(storagePath).replaceAll('.', '').toLowerCase();
    return _mimeTypeForExt(ext);
  }
}
