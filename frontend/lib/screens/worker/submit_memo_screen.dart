import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../providers/project_provider.dart';
import '../../services/audio_recording_service.dart';
import '../../services/functions_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';

enum _MemoState { idle, recording, uploading, processing, success, error }

class SubmitMemoScreen extends ConsumerStatefulWidget {
  const SubmitMemoScreen({super.key});

  @override
  ConsumerState<SubmitMemoScreen> createState() => _SubmitMemoScreenState();
}

class _SubmitMemoScreenState extends ConsumerState<SubmitMemoScreen>
    with WidgetsBindingObserver {
  final AudioRecorder _recorder = AudioRecorder();
  _MemoState _state = _MemoState.idle;
  File? _selectedFile;
  String _statusMessage = '';
  String? _aiSummary;
  double _uploadProgress = 0;
  Duration _recordingDuration = Duration.zero;
  DateTime? _recordingStart;
  StreamSubscription<Amplitude>? _amplitudeSub;
  DateTime? _lastAmplitudeLogAt;
  double _maxAmplitudeDb = -160.0;
  bool _isEmulator = false;

  // State ticked by a periodic update during recording
  late final _ticker = Stream.periodic(const Duration(seconds: 1));

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
    if (_state == _MemoState.recording &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _stopRecording().ignore();
    }
  }

  Future<void> _initRecordingEnvironment() async {
    final emulator = await AudioRecordingService.isAndroidEmulator();
    if (!mounted) return;
    setState(() => _isEmulator = emulator);
  }

  // ── Permission check ──────────────────────────────────────────────────────

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _requestMicPermission()) {
      _showError('Microphone permission denied.\nGo to Settings → Apps → BuildVox → Permissions.');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final startedAt = DateTime.now();
    await _recorder.start(AudioRecordingService.stableVoiceConfig, path: path);
    AudioRecordingService.logStart(
      flow: 'worker_submit_memo',
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
          flow: 'worker_submit_memo',
          currentDb: currentDb,
          maxDb: _maxAmplitudeDb,
        );
      }
    });

    setState(() {
      _state = _MemoState.recording;
      _recordingStart = startedAt;
      _recordingDuration = Duration.zero;
      _selectedFile = null;
      _statusMessage = _isEmulator ? AudioRecordingService.emulatorHintText() : '';
    });

    // Update duration counter
    _ticker.listen((_) {
      if (_state == _MemoState.recording && _recordingStart != null) {
        setState(() {
          _recordingDuration =
              DateTime.now().difference(_recordingStart!);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    final stoppedAt = DateTime.now();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await AudioRecordingService.logStop(
      flow: 'worker_submit_memo',
      startedAt: _recordingStart,
      stoppedAt: stoppedAt,
      path: path,
      maxDb: _maxAmplitudeDb,
    );
    if (path == null) {
      _showError('Recording failed — no audio captured.');
      setState(() => _state = _MemoState.idle);
      return;
    }

    final trackedSeconds = _recordingStart == null
        ? 0
        : stoppedAt.difference(_recordingStart!).inSeconds;
    final lowSignal = _maxAmplitudeDb < -45.0;
    setState(() {
      _selectedFile = File(path);
      _state = _MemoState.idle;
      _statusMessage = lowSignal
          ? 'Low microphone signal detected. If this is an emulator, test on a real device for reliable capture.'
          : trackedSeconds > 0
              ? 'Recorded ${trackedSeconds}s audio.'
              : '';
    });
  }

  // ── File pick (upload instead of record) ─────────────────────────────────

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    setState(() {
      _selectedFile = File(filePath);
      _state = _MemoState.idle;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedFile == null) {
      _showError('No audio selected. Record or upload a file first.');
      return;
    }

    final projectId = ref.read(selectedProjectIdProvider);
    final siteId = ref.read(selectedSiteIdProvider);

    if (projectId == null || siteId == null) {
      _showError('Select a project and site before submitting.');
      return;
    }

    setState(() {
      _state = _MemoState.uploading;
      _statusMessage = 'Uploading audio…';
      _aiSummary = null;
      _uploadProgress = 0;
    });

    try {
      // 1. Upload to Supabase Storage
      final uploadResult = await StorageService.uploadAudio(
        _selectedFile!,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      setState(() {
        _state = _MemoState.processing;
        _statusMessage = 'Processing with AI…';
      });

      // 2. Call backend Cloud Function
      final result = await FunctionsService.submitVoiceMemo(
        audioUrl: uploadResult.publicUrl,
        storagePath: uploadResult.objectPath,
        projectId: projectId,
        siteId: siteId,
        mimeType: uploadResult.mimeType,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final count = result['itemCount'] as int? ?? 0;
        final summary = (result['overallSummary'] ?? result['overall_summary'])
            ?.toString()
            .trim();
        setState(() {
          _state = _MemoState.success;
          _statusMessage =
              'Done! Extracted $count action item${count != 1 ? 's' : ''}';
          _aiSummary = (summary != null && summary.isNotEmpty) ? summary : null;
          _selectedFile = null;
        });
      } else {
        _showError(result['error'] as String? ?? 'Processing failed');
      }
    } catch (e) {
      _showError('Submission failed: $e');
    }
  }

  void _showError(String msg) {
    setState(() {
      _state = _MemoState.error;
      _statusMessage = msg;
    });
  }

  void _reset() {
    setState(() {
      _state = _MemoState.idle;
      _statusMessage = '';
      _aiSummary = null;
      _selectedFile = null;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(userProjectsProvider);
    final sitesAsync = ref.watch(selectedProjectSitesProvider);
    final selectedProjectId = ref.watch(selectedProjectIdProvider);
    final selectedSiteId = ref.watch(selectedSiteIdProvider);

    final isLoading = _state == _MemoState.uploading ||
        _state == _MemoState.processing;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              const Text(
                'Submit Voice Memo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BVColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Record or upload a voice note. AI will extract action items automatically.',
                style: TextStyle(fontSize: 13, color: BVColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),

              // ── Project selector ─────────────────────────────────────────
              const _FieldLabel(label: 'PROJECT'),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Error loading projects: $e',
                        style: const TextStyle(color: BVColors.blocker)),
                data: (projects) => DropdownButtonFormField<String>(
                  value: selectedProjectId,
                  hint: const Text('Select a project'),
                  items: projects
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    ref.read(selectedProjectIdProvider.notifier).state = v;
                    ref.read(selectedSiteIdProvider.notifier).state = null;
                  },
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 14),

              // ── Site selector ────────────────────────────────────────────
              const _FieldLabel(label: 'JOB SITE'),
              sitesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Error loading sites: $e',
                        style: const TextStyle(color: BVColors.blocker)),
                data: (sites) => DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  hint: const Text('Select a job site'),
                  items: sites
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      ref.read(selectedSiteIdProvider.notifier).state = v,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Recording interface ───────────────────────────────────────
              _RecordCard(
                state: _state,
                recordingDuration: _recordingDuration,
                selectedFile: _selectedFile,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onPickFile: _pickAudioFile,
                onClear: _reset,
              ),

              // ── Upload progress bar ──────────────────────────────────────
              if (_state == _MemoState.uploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: BVColors.divider,
                  color: BVColors.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12, color: BVColors.textSecondary),
                ),
              ],

              // ── Status messages ───────────────────────────────────────────
              if (_state == _MemoState.success) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  message: _statusMessage,
                  color: BVColors.done,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  child: const Text('Submit Another Memo'),
                ),
              ],
              if (_state == _MemoState.error) ...[
                const SizedBox(height: 16),
                _StatusBanner(
                  message: _statusMessage,
                  color: BVColors.blocker,
                  icon: Icons.error_outline_rounded,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  child: const Text('Try Again'),
                ),
              ],

              if (_aiSummary != null && _aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AiSummaryBox(summary: _aiSummary!),
              ],

              // ── Submit button ─────────────────────────────────────────────
              if (_state != _MemoState.success &&
                  _state != _MemoState.error &&
                  _state != _MemoState.recording) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      _selectedFile != null && !isLoading ? _submit : null,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isLoading ? _statusMessage : 'Submit Memo'),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        // Full overlay only during processing (not upload — we show progress bar)
        if (_state == _MemoState.processing)
          const LoadingOverlay(message: 'AI is extracting action items…\nThis takes 15–30 seconds.'),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: BVColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final _MemoState state;
  final Duration recordingDuration;
  final File? selectedFile;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onPickFile;
  final VoidCallback onClear;

  const _RecordCard({
    required this.state,
    required this.recordingDuration,
    required this.selectedFile,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onPickFile,
    required this.onClear,
  });

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = state == _MemoState.recording;
    final hasFile = selectedFile != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecording
              ? BVColors.blocker.withOpacity(0.5)
              : BVColors.divider,
          width: isRecording ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Recording indicator
          if (isRecording) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingDot(),
                const SizedBox(width: 8),
                Text(
                  'Recording  ${_formatDuration(recordingDuration)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BVColors.blocker,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onStopRecording,
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: const Text('Stop Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BVColors.blocker,
                minimumSize: const Size(200, 48),
              ),
            ),
          ] else if (hasFile) ...[
            const Icon(Icons.audio_file_rounded,
                size: 40, color: BVColors.primary),
            const SizedBox(height: 8),
            Text(
              selectedFile!.path.split('/').last,
              style: const TextStyle(
                  fontSize: 13, color: BVColors.onSurface, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 16, color: BVColors.textSecondary),
              label: const Text('Remove',
                  style: TextStyle(color: BVColors.textSecondary)),
            ),
          ] else ...[
            const Icon(Icons.mic_none_rounded,
                size: 48, color: BVColors.textSecondary),
            const SizedBox(height: 8),
            const Text(
              'Tap to record or upload an audio file',
              style: TextStyle(fontSize: 13, color: BVColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStartRecording,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Record'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickFile,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Upload'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: BVColors.blocker,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _StatusBanner(
      {required this.message, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSummaryBox extends StatelessWidget {
  final String summary;

  const _AiSummaryBox({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BVColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BVColors.primary.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Summary',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BVColors.primary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 13,
              color: BVColors.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
