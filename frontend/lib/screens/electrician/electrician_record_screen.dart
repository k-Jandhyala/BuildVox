import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/electrician_models.dart';
import '../../models/job_site_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../services/audio_recording_service.dart';

enum RecordUiState {
  idle,
  recording,
  processing,
  aiReview,
  submitting,
  success,
  queuedOffline
}

class ElectricianRecordScreen extends ConsumerStatefulWidget {
  const ElectricianRecordScreen({super.key});

  @override
  ConsumerState<ElectricianRecordScreen> createState() =>
      _ElectricianRecordScreenState();
}

class _ElectricianRecordScreenState extends ConsumerState<ElectricianRecordScreen>
    with WidgetsBindingObserver {
  final AudioRecorder _recorder = AudioRecorder();
  RecordUiState _state = RecordUiState.idle;
  String? _recordedPath;
  List<String> _photos = [];
  String _status = 'Tap to start recording';
  DateTime? _recordingStartedAt;
  StreamSubscription<Amplitude>? _amplitudeSub;
  DateTime? _lastAmplitudeLogAt;
  double _maxAmplitudeDb = -160.0;
  bool _isEmulator = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRecordingEnvironment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amplitudeSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_state == RecordUiState.recording &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _toggleRecord().ignore();
    }
  }

  Future<void> _initRecordingEnvironment() async {
    final emulator = await AudioRecordingService.isAndroidEmulator();
    if (!mounted) return;
    setState(() => _isEmulator = emulator);
  }

  Future<bool> _ensureMic() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> _ensurePhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted || await Permission.storage.request().isGranted;
  }

  Future<void> _toggleRecord() async {
    if (_state == RecordUiState.recording) {
      final path = await _recorder.stop();
      final stoppedAt = DateTime.now();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      await AudioRecordingService.logStop(
        flow: 'electrician_record',
        startedAt: _recordingStartedAt,
        stoppedAt: stoppedAt,
        path: path,
        maxDb: _maxAmplitudeDb,
      );
      HapticFeedback.mediumImpact();
      if (path != null) {
        final trackedSeconds = _recordingStartedAt == null
            ? 0
            : stoppedAt.difference(_recordingStartedAt!).inSeconds;
        final lowSignal = _maxAmplitudeDb < -45.0;
        setState(() {
          _recordedPath = path;
          _state = RecordUiState.idle;
          _status = lowSignal
              ? 'Recording captured but mic signal looked very low. Test on a real device if using emulator.'
              : trackedSeconds > 0
                  ? 'Recording captured (${trackedSeconds}s). Process with AI.'
                  : 'Recording captured. Process with AI.';
        });
      }
      return;
    }
    if (!await _ensureMic()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone permission denied. Enable it in settings.'),
      ));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/electrician_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final startedAt = DateTime.now();
    await _recorder.start(AudioRecordingService.stableVoiceConfig, path: path);
    AudioRecordingService.logStart(
      flow: 'electrician_record',
      path: path,
      startedAt: startedAt,
      isEmulator: _isEmulator,
    );
    _amplitudeSub?.cancel();
    _maxAmplitudeDb = -160.0;
    _lastAmplitudeLogAt = null;
    _amplitudeSub = _recorder
        .onAmplitudeChanged(AudioRecordingService.amplitudeSampleInterval)
        .listen((amp) {
      final currentDb = amp.current;
      if (currentDb > _maxAmplitudeDb) {
        _maxAmplitudeDb = currentDb;
      }
      final now = DateTime.now();
      if (_lastAmplitudeLogAt == null ||
          now.difference(_lastAmplitudeLogAt!).inSeconds >= 2) {
        _lastAmplitudeLogAt = now;
        AudioRecordingService.logAmplitude(
          flow: 'electrician_record',
          currentDb: currentDb,
          maxDb: _maxAmplitudeDb,
        );
      }
    });
    HapticFeedback.heavyImpact();
    setState(() {
      _state = RecordUiState.recording;
      _recordingStartedAt = startedAt;
      _status = _isEmulator
          ? '${AudioRecordingService.emulatorHintText()} Tap again to stop.'
          : 'Recording... tap again to stop';
    });
  }

  Future<void> _attachPhoto() async {
    if (!await _ensurePhotos()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo permission denied. Enable it in settings.'),
      ));
      return;
    }
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return;
    setState(() {
      _photos = [
        ..._photos,
        ...result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
      ];
    });
  }

  Future<void> _process() async {
    final siteId = ref.read(selectedElectricianSiteProvider).valueOrNull;
    final sites = ref.read(electricianJobsitesProvider).valueOrNull ?? const [];
    JobSiteModel? site;
    for (final s in sites) {
      if (s.id == siteId) {
        site = s;
        break;
      }
    }
    if (_recordedPath == null || site == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Record a memo and select a valid jobsite first.'),
      ));
      return;
    }
    final draft = VoiceMemoDraft(
      localAudioPath: _recordedPath!,
      siteId: site.id,
      projectId: site.projectId,
      attachedPhotoPaths: _photos,
      createdAt: DateTime.now(),
    );
    setState(() {
      _state = RecordUiState.processing;
      _status = 'Processing voice memo with AI...';
    });
    try {
      await ref.read(recordFlowProvider.notifier).startProcessing(
            draft: draft,
            queueIfOffline: true,
          );
      if (!mounted) return;
      setState(() {
        _state = RecordUiState.aiReview;
        _status = 'AI extracted items. Review before submission.';
      });
      HapticFeedback.selectionClick();
      final user = ref.read(currentUserProvider);
      final route = user?.trade == TradeType.plumbing
          ? '/plumber/ai-review'
          : '/electrician/ai-review';
      context.push(route);
    } catch (e) {
      final msg = e.toString();
      final queued = msg.contains('queued_offline:');
      final isStorageRls = _isStorageRlsError(msg);
      setState(() {
        _state = queued ? RecordUiState.queuedOffline : RecordUiState.idle;
        _status = queued
            ? 'No connection. Memo queued and will auto-sync.'
            : isStorageRls
                ? 'Upload blocked by storage permissions. See error details.'
                : 'Processing failed. See error details.';
      });
      if (queued) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Queued offline: ${msg.replaceFirst('Exception: queued_offline:', '')}')),
        );
      } else {
        final errorText = isStorageRls
            ? 'Processing failed: Upload blocked by Supabase Storage RLS (403 Unauthorized).\n'
                'Please add/update a Storage policy that allows authenticated users to upload under '
                'audio/{uid}/ and photos/{uid}/ in the voice-memos bucket.'
            : 'Processing failed: $msg';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
          ),
        );
      }
    }
  }

  bool _isStorageRlsError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('storageexception') &&
        lower.contains('row-level security policy');
  }

  String? _buildAiSummary(List<AiExtractedItem> items) {
    final summaries = items
        .map((e) => e.summary.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (summaries.isEmpty) return null;

    if (summaries.length == 1) {
      return summaries.first;
    }

    final preview = summaries.take(3).join(' ');
    if (summaries.length <= 3) return preview;
    return '$preview (+${summaries.length - 3} more item(s))';
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(selectedSiteSummaryProvider);
    final queue = ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final extractedItems = ref.watch(recordFlowProvider).valueOrNull ?? const [];
    final aiSummary = _buildAiSummary(extractedItems);
    final queuedCount = queue.where((e) => e.status != QueueStatus.completed).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Record',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          summary == null
              ? 'No jobsite selected'
              : 'Current jobsite: ${summary.site.name}',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        if (queuedCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Offline queue: $queuedCount pending submission(s)',
              style: const TextStyle(color: Color(0xFFBFDBFE)),
            ),
          )
        ],
        const SizedBox(height: 24),
        Center(
          child: InkWell(
            onTap: _toggleRecord,
            borderRadius: BorderRadius.circular(90),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: _state == RecordUiState.recording
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Icon(
                _state == RecordUiState.recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 72,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _attachPhoto,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text('Attach photos (${_photos.length})'),
        ),
        if (_photos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _photos
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        File(p).uri.pathSegments.last,
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ))
                .toList(),
          ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _state == RecordUiState.processing ? null : _process,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Process with AI and Review'),
        ),
        if (aiSummary != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1D4ED8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Summary',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  aiSummary,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
