import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

class UploadAudioResult {
  final String objectPath;
  final String publicUrl;
  final String mimeType;

  const UploadAudioResult({
    required this.objectPath,
    required this.publicUrl,
    required this.mimeType,
  });
}

class UploadPhotoResult {
  final String objectPath;
  final String publicUrl;

  const UploadPhotoResult({required this.objectPath, required this.publicUrl});
}

class StorageService {
  static const String _bucketName = String.fromEnvironment(
    'SUPABASE_STORAGE_BUCKET',
    defaultValue: 'voice-memos',
  );
  static const _uuid = Uuid();

  /// Uploads an audio file to Supabase Storage.
  ///
  /// Path: audio/{userId}/{timestamp}_{uuid}.{ext}
  /// Returns both object path and public URL for backend ingestion.
  static Future<UploadAudioResult> uploadAudio(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) throw Exception('User not authenticated');

    final ext = p.extension(file.path).toLowerCase();
    final safeExt = _sanitizeExt(ext);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4().substring(0, 8);
    final fileName = '${timestamp}_$id.$safeExt';
    final objectPath = 'audio/$uid/$fileName';
    final mimeType = _mimeTypeForExt(safeExt);
    final bytes = await file.readAsBytes();
    final Uint8List uploadBytes = Uint8List.fromList(bytes);

    onProgress?.call(0.1);
    await SupabaseService.client.storage.from(_bucketName).uploadBinary(
          objectPath,
          uploadBytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    onProgress?.call(1.0);

    final publicUrl =
        SupabaseService.client.storage.from(_bucketName).getPublicUrl(objectPath);
    return UploadAudioResult(
      objectPath: objectPath,
      publicUrl: publicUrl,
      mimeType: mimeType,
    );
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
  /// for a given object path.
  static String getMimeType(String objectPath) {
    final ext = p.extension(objectPath).replaceAll('.', '').toLowerCase();
    return _mimeTypeForExt(ext);
  }

  static Future<UploadPhotoResult> uploadPhoto(File file) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) throw Exception('User not authenticated');

    final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'photos/$uid/${timestamp}_${_uuid.v4().substring(0, 8)}.$safeExt';
    final bytes = await file.readAsBytes();

    await SupabaseService.client.storage.from(_bucketName).uploadBinary(
          objectPath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: 'image/$safeExt', upsert: false),
        );

    return UploadPhotoResult(
      objectPath: objectPath,
      publicUrl:
          SupabaseService.client.storage.from(_bucketName).getPublicUrl(objectPath),
    );
  }
}
