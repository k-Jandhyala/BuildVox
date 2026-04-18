import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../models/electrician_models.dart';
import '../../models/job_site_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../services/functions_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';

/// Quick-tag for field updates (maps to [ElectricianCategory] on submit).
enum _FieldNoteTag {
  blocker,
  materials,
  progress,
  safety,
  workOrder,
}

extension on _FieldNoteTag {
  String get chipLabel {
    switch (this) {
      case _FieldNoteTag.blocker:
        return '🚧 Blocker';
      case _FieldNoteTag.materials:
        return '📦 Materials';
      case _FieldNoteTag.progress:
        return '✅ Progress';
      case _FieldNoteTag.safety:
        return '⚠️ Safety';
      case _FieldNoteTag.workOrder:
        return '🔧 Work Order';
    }
  }

  /// Short label for recent cards (no emoji).
  String get shortTypeLabel {
    switch (this) {
      case _FieldNoteTag.blocker:
        return 'Blocker';
      case _FieldNoteTag.materials:
        return 'Materials';
      case _FieldNoteTag.progress:
        return 'Progress';
      case _FieldNoteTag.safety:
        return 'Safety';
      case _FieldNoteTag.workOrder:
        return 'Work Order';
    }
  }

  ElectricianCategory get category {
    switch (this) {
      case _FieldNoteTag.blocker:
        return ElectricianCategory.blocker;
      case _FieldNoteTag.materials:
        return ElectricianCategory.materialRequest;
      case _FieldNoteTag.progress:
        return ElectricianCategory.taskUpdate;
      case _FieldNoteTag.safety:
        return ElectricianCategory.siteIssue;
      case _FieldNoteTag.workOrder:
        return ElectricianCategory.workOrder;
    }
  }
}

class ElectricianRecordScreen extends ConsumerStatefulWidget {
  const ElectricianRecordScreen({super.key});

  @override
  ConsumerState<ElectricianRecordScreen> createState() =>
      _ElectricianRecordScreenState();
}

class _ElectricianRecordScreenState extends ConsumerState<ElectricianRecordScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  _FieldNoteTag _selectedTag = _FieldNoteTag.progress;
  List<String> _photos = [];
  bool _submitting = false;
  bool _offlineBannerDismissed = false;

  static const _inputBg = Color(0xFF1A2733);
  static const _inputBorder = Color(0xFF2A3A4A);
  static const _placeholder = Color(0xFFA8B8C8);

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isLikelyOfflineError(String raw) {
    final s = raw.toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('timed out') ||
        s.contains('clientexception');
  }

  int _wordCount(String t) {
    final trimmed = t.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String _previewOneLine(String text) {
    final one = text.trim().replaceAll('\n', ' ');
    if (one.length <= 60) return one;
    return '${one.substring(0, 57)}…';
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hrs ago';
    if (d.inDays < 7) return '${d.inDays} days ago';
    return '${(d.inDays / 7).floor()} wks ago';
  }

  Future<bool> _ensurePhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted || await Permission.storage.request().isGranted;
  }

  Future<void> _attachPhoto() async {
    if (!await _ensurePhotos()) {
      if (!mounted) return;
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
        ...result.files.where((f) => f.path != null).map((f) => f.path!)
      ];
    });
  }

  Future<void> _confirmClear() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    if (text.length <= 20) {
      _textController.clear();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BVColors.surface,
        title: const Text('Clear note?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Discard everything in this field?',
          style: TextStyle(color: BVColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _textController.clear();
    }
  }

  Future<void> _submit() async {
    final raw = _textController.text.trim();
    if (raw.isEmpty || _submitting) return;

    final siteId = ref.read(selectedElectricianSiteProvider).valueOrNull;
    final sites = ref.read(electricianJobsitesProvider).valueOrNull ?? const [];
    JobSiteModel? site;
    for (final s in sites) {
      if (s.id == siteId) {
        site = s;
        break;
      }
    }
    if (site == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select a valid jobsite before submitting.'),
      ));
      return;
    }

    final user = ref.read(currentUserProvider);
    final trade = user?.trade?.name ?? 'electrical';

    setState(() => _submitting = true);
    HapticFeedback.lightImpact();

    final photoUrls = <String>[];
    try {
      for (final p in _photos) {
        final up = await StorageService.uploadPhoto(File(p));
        photoUrls.add(up.publicUrl);
      }

      final item = AiExtractedItem(
        id: const Uuid().v4(),
        transcriptSegment: raw,
        summary: _previewOneLine(raw),
        category: _selectedTag.category,
        priority: ElectricianPriority.medium,
        location: '',
        relatedTrade: trade,
        notes: '',
        isBlocker: _selectedTag == _FieldNoteTag.blocker,
        isMaterialRequest: _selectedTag == _FieldNoteTag.materials,
        attachedPhotos: photoUrls,
        expanded: false,
      );

      final requestId = 'field_note_${DateTime.now().millisecondsSinceEpoch}';

      await FunctionsService.submitReviewedItems(
        requestId: requestId,
        projectId: site.projectId,
        siteId: site.id,
        items: [item.toJson()],
      );

      if (!mounted) return;
      await ref.read(recentFieldNotesProvider.notifier).prepend(
            RecentFieldNote(
              id: requestId,
              preview: _previewOneLine(raw),
              typeLabel: _selectedTag.shortTypeLabel,
              createdAt: DateTime.now(),
              status: RecentFieldNoteStatus.processed,
            ),
          );
      _textController.clear();
      setState(() {
        _photos = [];
        _selectedTag = _FieldNoteTag.progress;
        _submitting = false;
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update submitted')),
      );
    } catch (e) {
      final err = e.toString();
      final queued = _isLikelyOfflineError(err);
      if (queued) {
        final requestId = 'field_note_q_${DateTime.now().millisecondsSinceEpoch}';
        final item = AiExtractedItem(
          id: const Uuid().v4(),
          transcriptSegment: raw,
          summary: _previewOneLine(raw),
          category: _selectedTag.category,
          priority: ElectricianPriority.medium,
          location: '',
          relatedTrade: trade,
          notes: '',
          isBlocker: _selectedTag == _FieldNoteTag.blocker,
          isMaterialRequest: _selectedTag == _FieldNoteTag.materials,
          attachedPhotos: photoUrls,
          expanded: false,
        );
        try {
          await ref.read(electricianQueueProvider.notifier).enqueue(
                QueuedSubmission(
                  id: const Uuid().v4(),
                  type: QueueSubmissionType.finalSubmission,
                  status: QueueStatus.queued,
                  createdAt: DateTime.now(),
                  attempts: 0,
                  payload: {
                    'requestId': requestId,
                    'projectId': site.projectId,
                    'siteId': site.id,
                    'items': [item.toJson()],
                  },
                  error: err,
                ),
              );
          if (!mounted) return;
          await ref.read(recentFieldNotesProvider.notifier).prepend(
                RecentFieldNote(
                  id: requestId,
                  preview: _previewOneLine(raw),
                  typeLabel: _selectedTag.shortTypeLabel,
                  createdAt: DateTime.now(),
                  status: RecentFieldNoteStatus.pending,
                ),
              );
          _textController.clear();
          setState(() {
            _photos = [];
            _selectedTag = _FieldNoteTag.progress;
            _submitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No connection. Queued for sync: ${err.length > 80 ? "${err.substring(0, 80)}…" : err}',
              ),
            ),
          );
        } catch (_) {
          if (!mounted) return;
          setState(() => _submitting = false);
          await ref.read(recentFieldNotesProvider.notifier).prepend(
                RecentFieldNote(
                  id: const Uuid().v4(),
                  preview: _previewOneLine(raw),
                  typeLabel: _selectedTag.shortTypeLabel,
                  createdAt: DateTime.now(),
                  status: RecentFieldNoteStatus.failed,
                ),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Submit failed: $err')),
          );
        }
      } else {
        if (!mounted) return;
        setState(() => _submitting = false);
        await ref.read(recentFieldNotesProvider.notifier).prepend(
              RecentFieldNote(
                id: const Uuid().v4(),
                preview: _previewOneLine(raw),
                typeLabel: _selectedTag.shortTypeLabel,
                createdAt: DateTime.now(),
                status: RecentFieldNoteStatus.failed,
              ),
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Focus when this tab becomes visible (IndexedStack keeps all children built).
    ref.listen<int>(tradeWorkerShellTabProvider, (prev, next) {
      if (next == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      } else {
        _focusNode.unfocus();
      }
    });

    // Re-tap "Add Update" / center button while already on this tab.
    ref.listen<int>(recordScreenAutofocusTriggerProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(tradeWorkerShellTabProvider) == 2) {
          _focusNode.requestFocus();
        }
      });
    });

    final summary = ref.watch(selectedSiteSummaryProvider);
    final queue = ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final queuedCount = queue.where((e) => e.status != QueueStatus.completed).length;
    final recentAsync = ref.watch(recentFieldNotesProvider);
    final recent = recentAsync.valueOrNull ?? const <RecentFieldNote>[];

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final textAreaHeight = math.max(200.0, math.min(screenH * 0.4, 520.0));

    final text = _textController.text;
    final words = _wordCount(text);
    final canSubmit = text.trim().isNotEmpty && !_submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'New Update',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            summary == null ? 'No jobsite selected' : 'Current jobsite: ${summary.site.name}',
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          if (queuedCount > 0 && !_offlineBannerDismissed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BVColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BVColors.primary.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('☁', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$queuedCount pending submission${queuedCount == 1 ? '' : 's'} — will sync when online',
                      style: const TextStyle(color: BVColors.onSurface, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close_rounded, color: BVColors.textSecondary, size: 22),
                    onPressed: () => setState(() => _offlineBannerDismissed = true),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _FieldNoteTag.values.map((tag) {
                final selected = _selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tag.chipLabel),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedTag = tag),
                    selectedColor: BVColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? BVColors.onPrimary : BVColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: selected ? BVColors.primary : BVColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: textAreaHeight,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  minLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: true,
                  enableSuggestions: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
                  cursorColor: BVColors.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: _inputBg,
                    hintText:
                        'Describe what\'s happening on site...\n(Tip: tap the 🎤 on your keyboard to speak)',
                    hintStyle: const TextStyle(color: _placeholder, fontSize: 16, height: 1.35),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: BVColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  '${text.length} chars · $words words',
                  style: TextStyle(
                    color: BVColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Badge(
            isLabelVisible: _photos.isNotEmpty,
            label: Text(
              '${_photos.length}',
              style: const TextStyle(
                color: BVColors.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: BVColors.primary,
            child: OutlinedButton.icon(
              onPressed: _attachPhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text('Attach photos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BVColors.primary,
                side: const BorderSide(color: BVColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 8),
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
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _confirmClear,
              child: const Text(
                'Clear',
                style: TextStyle(color: BVColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BVColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: BVColors.divider,
                disabledForegroundColor: BVColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Processing...',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '✦ Submit Update',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, size: 22),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent submissions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Text(
              'No submissions yet',
              style: TextStyle(color: BVColors.textSecondary),
            )
          else
            ...recent.map((n) => _RecentNoteCard(note: n, relativeTime: _relativeTime)),
        ],
      ),
    );
  }
}

class _RecentNoteCard extends StatelessWidget {
  final RecentFieldNote note;
  final String Function(DateTime) relativeTime;

  const _RecentNoteCard({required this.note, required this.relativeTime});

  Color _statusColor(RecentFieldNoteStatus s) {
    switch (s) {
      case RecentFieldNoteStatus.processed:
        return BVColors.done;
      case RecentFieldNoteStatus.pending:
        return BVColors.primary;
      case RecentFieldNoteStatus.failed:
        return BVColors.blocker;
    }
  }

  String _statusLabel(RecentFieldNoteStatus s) {
    switch (s) {
      case RecentFieldNoteStatus.processed:
        return 'Processed';
      case RecentFieldNoteStatus.pending:
        return 'Pending';
      case RecentFieldNoteStatus.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BVColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BVColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: BVColors.divider),
                ),
                child: Text(
                  note.typeLabel,
                  style: const TextStyle(color: BVColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                relativeTime(note.createdAt),
                style: const TextStyle(color: BVColors.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(note.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(note.status),
                  style: TextStyle(
                    color: _statusColor(note.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
