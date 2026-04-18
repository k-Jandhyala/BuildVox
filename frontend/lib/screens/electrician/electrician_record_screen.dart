import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/electrician_models.dart';
import '../../models/job_site_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';

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

class _ElectricianRecordScreenState
    extends ConsumerState<ElectricianRecordScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  RecordUiState _state = RecordUiState.idle;
  String? _recordedPath;
  List<String> _photos = [];
  DateTime? _startedAt;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
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
      HapticFeedback.mediumImpact();
      if (path != null) {
        setState(() {
          _recordedPath = path;
          _state = RecordUiState.idle;
          _startedAt = null;
        });
      }
      return;
    }
    if (!await _ensureMic()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone permission denied. Enable it in Settings.'),
      ));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.defaultSource,
          ),
        ),
        path: path);
    HapticFeedback.heavyImpact();
    setState(() {
      _state = RecordUiState.recording;
      _startedAt = DateTime.now();
    });
  }

  Future<void> _attachPhoto() async {
    if (!await _ensurePhotos()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo permission denied. Enable it in Settings.'),
      ));
      return;
    }
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null) return;
    setState(() {
      _photos = [
        ..._photos,
        ...result.files.where((f) => f.path != null).map((f) => f.path!)
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
    setState(() => _state = RecordUiState.processing);
    try {
      await ref.read(recordFlowProvider.notifier).startProcessing(
            draft: draft,
            queueIfOffline: true,
          );
      if (!mounted) return;
      setState(() => _state = RecordUiState.aiReview);
      HapticFeedback.selectionClick();
      final user = ref.read(currentUserProvider);
      final route = user?.trade == TradeType.plumbing
          ? '/plumber/ai-review'
          : '/electrician/ai-review';
      context.push(route);
    } catch (e) {
      final msg = e.toString();
      final queued = msg.contains('queued_offline:');
      setState(() {
        _state =
            queued ? RecordUiState.queuedOffline : RecordUiState.idle;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(queued
              ? 'No connection — memo queued and will auto-sync.'
              : 'Processing failed: $msg'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue =
        ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final queuedCount =
        queue.where((e) => e.status != QueueStatus.completed).length;
    final recent = queue.take(3).toList();
    final isRecording = _state == RecordUiState.recording;
    final hasRecording = _recordedPath != null;
    final isProcessing = _state == RecordUiState.processing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── Offline queue banner ────────────────────────────────────────
        if (queuedCount > 0) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: BVColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: BVColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$queuedCount pending · Will sync when online',
                    style: const TextStyle(
                        color: BVColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Mic button ──────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: isProcessing ? null : _toggleRecord,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isRecording
                          ? const [Color(0xFFF87171), Color(0xFFEF4444)]
                          : const [BVColors.primaryLight, BVColors.primary],
                      radius: 0.85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording
                                ? BVColors.danger
                                : BVColors.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Timer or prompt
              if (isRecording && _startedAt != null)
                StreamBuilder<int>(
                  stream: Stream.periodic(
                      const Duration(seconds: 1), (x) => x),
                  builder: (_, __) {
                    final d =
                        DateTime.now().difference(_startedAt!);
                    final mm =
                        d.inMinutes.toString().padLeft(2, '0');
                    final ss =
                        (d.inSeconds % 60).toString().padLeft(2, '0');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingDot(),
                        const SizedBox(width: 8),
                        Text(
                          '$mm:$ss',
                          style: const TextStyle(
                            color: BVColors.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                )
              else if (isProcessing)
                const Text(
                  'Processing with AI…',
                  style: TextStyle(
                      color: BVColors.textSecondary, fontSize: 15),
                )
              else
                Text(
                  hasRecording
                      ? 'Recording captured — tap to re-record'
                      : 'Tap to record',
                  style: const TextStyle(
                      color: BVColors.textSecondary, fontSize: 15),
                ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Attach photos ────────────────────────────────────────────────
        GestureDetector(
          onTap: _attachPhoto,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BVColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    color: BVColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  _photos.isEmpty
                      ? 'Attach photos'
                      : 'Attach photos  ·  ${_photos.length} attached',
                  style: const TextStyle(
                      color: BVColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _photos.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BVColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      File(p).uri.pathSegments.last,
                      style: const TextStyle(
                          color: BVColors.textSecondary,
                          fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(
                          () => _photos.remove(p)),
                      child: const Icon(Icons.close,
                          color: BVColors.textMuted, size: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 20),

        // ── Submit button ─────────────────────────────────────────────
        AnimatedOpacity(
          opacity:
              hasRecording && !isProcessing ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            onPressed: hasRecording && !isProcessing
                ? _process
                : null,
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
                isProcessing ? 'Processing…' : 'Submit & Review'),
          ),
        ),

        const SizedBox(height: 32),

        // ── Recent recordings ────────────────────────────────────────
        if (recent.isNotEmpty) ...[
          const Text(
            'Recent',
            style: TextStyle(
              color: BVColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...recent.map((q) => _RecentItem(entry: q)),
        ],
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
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
            color: BVColors.danger, shape: BoxShape.circle),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final dynamic entry;
  const _RecentItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCompleted = entry.status == QueueStatus.completed;
    final isFailed = entry.status == QueueStatus.failed;
    final statusColor = isCompleted
        ? BVColors.success
        : isFailed
            ? BVColors.danger
            : BVColors.primary;
    final statusLabel =
        isCompleted ? 'Synced' : isFailed ? 'Failed' : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Memo · ${DateFormat('h:mm a').format(entry.createdAt)}',
              style: const TextStyle(
                  color: BVColors.onSurface, fontSize: 13),
            ),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
