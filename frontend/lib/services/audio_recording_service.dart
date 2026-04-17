import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  static const Duration amplitudeSampleInterval = Duration(milliseconds: 500);

  /// Stable mobile voice config for upload + AI transcription.
  static const RecordConfig stableVoiceConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 44100,
    bitRate: 128000,
    numChannels: 1,
  );

  static Future<bool> isAndroidEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final fingerprint = info.fingerprint.toLowerCase();
      final model = info.model.toLowerCase();
      final product = info.product.toLowerCase();
      final brand = info.brand.toLowerCase();
      final device = info.device.toLowerCase();
      final hardware = info.hardware.toLowerCase();

      return fingerprint.contains('generic') ||
          fingerprint.contains('emulator') ||
          model.contains('emulator') ||
          model.contains('sdk') ||
          product.contains('sdk') ||
          product.contains('emulator') ||
          brand.startsWith('generic') ||
          device.contains('generic') ||
          hardware.contains('goldfish') ||
          hardware.contains('ranchu');
    } catch (_) {
      return false;
    }
  }

  static void logStart({
    required String flow,
    required String path,
    required DateTime startedAt,
    required bool isEmulator,
  }) {
    debugPrint(
      '[Audio][$flow] start path=$path startedAt=${startedAt.toIso8601String()} '
      'config=aacLc/44100Hz/mono/128kbps emulator=$isEmulator',
    );
  }

  static void logAmplitude({
    required String flow,
    required double currentDb,
    required double maxDb,
  }) {
    debugPrint('[Audio][$flow] amplitude currentDb=$currentDb maxDb=$maxDb');
  }

  static Future<void> logStop({
    required String flow,
    required DateTime? startedAt,
    required DateTime stoppedAt,
    required String? path,
    required double maxDb,
  }) async {
    final trackedMs =
        startedAt == null ? null : stoppedAt.difference(startedAt).inMilliseconds;
    int? bytes;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        bytes = await f.length();
      }
    }
    debugPrint(
      '[Audio][$flow] stop path=$path stoppedAt=${stoppedAt.toIso8601String()} '
      'trackedDurationMs=$trackedMs fileBytes=$bytes maxDb=$maxDb',
    );
  }

  static String emulatorHintText() {
    return 'Running on Android emulator: microphone capture can be flaky. '
        'Please verify final voice quality on a physical device before production use.';
  }
}
