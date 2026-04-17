import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/electrician_models.dart';
import '../models/extracted_item_model.dart';
import '../models/job_site_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/electrician_session_service.dart';
import '../services/functions_service.dart';
import '../services/offline_queue_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';
import 'project_provider.dart';

final electricianEnabledProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.worker && user?.trade == TradeType.electrical;
});

final electricianJobsitesProvider = FutureProvider<List<JobSiteModel>>((ref) async {
  final projects = await ref.watch(userProjectsProvider.future);
  final user = ref.watch(currentUserProvider);
  if (user == null || projects.isEmpty) return const [];

  final byId = <String, JobSiteModel>{};
  for (final p in projects) {
    final sites = await DatabaseService.getSitesForProject(p.id);
    for (final s in sites) {
      if (user.assignedSiteIds.contains(s.id)) {
        byId[s.id] = s;
      }
    }
  }
  return byId.values.toList();
});

class SelectedJobsiteNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    final sites = await ref.watch(electricianJobsitesProvider.future);
    if (sites.isEmpty) return null;
    final saved = await ElectricianSessionService.loadSelectedSiteId(user.uid);
    if (saved != null && sites.any((s) => s.id == saved)) return saved;
    return sites.first.id;
  }

  Future<void> setSite(String siteId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    state = AsyncValue.data(siteId);
    await ElectricianSessionService.saveSelectedSiteId(user.uid, siteId);
  }
}

final selectedElectricianSiteProvider =
    AsyncNotifierProvider<SelectedJobsiteNotifier, String?>(
  SelectedJobsiteNotifier.new,
);

final electricianTasksProvider = StreamProvider<List<ElectricianTask>>((ref) async* {
  final user = ref.watch(currentUserProvider);
  final siteId = ref.watch(selectedElectricianSiteProvider).valueOrNull;
  if (user == null || siteId == null) {
    yield const [];
    return;
  }

  await for (final assignments in DatabaseService.workerTasksStream(user.uid)) {
    final scoped = assignments.where((t) => t.siteId == siteId).toList();
    final list = <ElectricianTask>[];
    for (final task in scoped) {
      final item = await DatabaseService.getExtractedItem(task.extractedItemId);
      if (item == null) continue;
      final tradeName = user.trade?.name;
      if (tradeName != null && tradeName.isNotEmpty && item.trade != tradeName) {
        continue;
      }
      list.add(ElectricianTask(
        assignment: task,
        item: item,
        assignedByLabel: 'Project Team',
      ));
    }
    list.sort((a, b) =>
        (b.item.createdAt ?? DateTime(0)).compareTo(a.item.createdAt ?? DateTime(0)));
    yield list;
  }
});

final electricianWarningsProvider = Provider<List<SiteWarning>>((ref) {
  final tasks = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
  final warnings = <SiteWarning>[];
  for (final t in tasks) {
    if (t.item.tier == TierType.issueOrBlocker || t.item.needsGcAttention) {
      warnings.add(SiteWarning(
        id: 'warn-${t.item.id}',
        siteId: t.assignment.siteId,
        category: WarningCategory.safety,
        severity: t.item.urgency == UrgencyLevel.critical
            ? WarningSeverity.critical
            : WarningSeverity.high,
        title: t.item.normalizedSummary,
        description: t.item.suggestedNextStep,
        createdAt: t.item.createdAt ?? DateTime.now(),
      ));
    }
    if (t.item.tier == TierType.materialRequest) {
      warnings.add(SiteWarning(
        id: 'warn-mat-${t.item.id}',
        siteId: t.assignment.siteId,
        category: WarningCategory.materialShortage,
        severity: WarningSeverity.medium,
        title: 'Material request pending',
        description: t.item.normalizedSummary,
        createdAt: t.item.createdAt ?? DateTime.now(),
      ));
    }
  }
  return warnings.take(20).toList();
});

class QueueNotifier extends AsyncNotifier<List<QueuedSubmission>> {
  Timer? _timer;

  @override
  Future<List<QueuedSubmission>> build() async {
    final existing = await OfflineQueueService.loadAll();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _sync());
    ref.onDispose(() => _timer?.cancel());
    return existing;
  }

  Future<void> enqueue(QueuedSubmission s) async {
    final list = <QueuedSubmission>[
      ...(state.valueOrNull ?? const <QueuedSubmission>[]),
      s,
    ];
    state = AsyncValue.data(list);
    await OfflineQueueService.saveAll(list);
  }

  Future<void> _sync() async {
    final current = <QueuedSubmission>[
      ...(state.valueOrNull ?? const <QueuedSubmission>[]),
    ];
    if (current.isEmpty) return;
    var changed = false;

    for (var i = 0; i < current.length; i++) {
      var q = current[i];
      if (q.status == QueueStatus.completed) continue;

      q = q.copyWith(
        status: QueueStatus.syncing,
        lastTriedAt: DateTime.now(),
        attempts: q.attempts + 1,
      );
      current[i] = q;
      changed = true;

      try {
        if (q.type == QueueSubmissionType.audioUpload) {
          final path = q.payload['localAudioPath'] as String;
          final file = File(path);
          if (!await file.exists()) {
            throw Exception('Audio file no longer available');
          }
          final upload = await StorageService.uploadAudio(file);
          current[i] = q.copyWith(
            status: QueueStatus.completed,
            payload: {
              ...q.payload,
              'uploadedAudioUrl': upload.publicUrl,
              'uploadedStoragePath': upload.objectPath,
            },
          );
        } else {
          await FunctionsService.submitReviewedItems(
            requestId: q.payload['requestId'] as String,
            projectId: q.payload['projectId'] as String,
            siteId: q.payload['siteId'] as String,
            items: List<Map<String, dynamic>>.from(q.payload['items'] as List),
          );
          current[i] = q.copyWith(status: QueueStatus.completed, error: null);
        }
      } catch (e) {
        current[i] = q.copyWith(status: QueueStatus.failed, error: e.toString());
      }
    }

    if (changed) {
      state = AsyncValue.data(current);
      await OfflineQueueService.saveAll(current);
    }
  }
}

final electricianQueueProvider =
    AsyncNotifierProvider<QueueNotifier, List<QueuedSubmission>>(
  QueueNotifier.new,
);

class RecordFlowController extends AsyncNotifier<List<AiExtractedItem>> {
  String _defaultTrade() {
    final user = ref.read(currentUserProvider);
    return user?.trade?.name ?? 'electrical';
  }

  String? _requestId;
  VoiceMemoDraft? _draft;
  Timer? _pollTimer;

  @override
  Future<List<AiExtractedItem>> build() async {
    return _loadSavedDraft();
  }

  Future<List<AiExtractedItem>> _loadSavedDraft() async {
    final file = await _draftFile();
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const [];
    final json = Map<String, dynamic>.from(jsonDecode(raw));
    _requestId = json['requestId'] as String?;
    final items = (json['items'] as List? ?? const [])
        .map((e) => AiExtractedItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return items;
  }

  Future<File> _draftFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/electrician_ai_review_draft.json');
  }

  Future<void> _persistDraft() async {
    final file = await _draftFile();
    final body = {
      'requestId': _requestId,
      'items': (state.valueOrNull ?? const []).map((e) => e.toJson()).toList(),
      'draft': _draft == null
          ? null
          : {
              'localAudioPath': _draft!.localAudioPath,
              'siteId': _draft!.siteId,
              'projectId': _draft!.projectId,
              'attachedPhotoPaths': _draft!.attachedPhotoPaths,
              'createdAt': _draft!.createdAt.toIso8601String(),
            }
    };
    await file.writeAsString(jsonEncode(body));
  }

  Future<String?> startProcessing({
    required VoiceMemoDraft draft,
    required bool queueIfOffline,
  }) async {
    _draft = draft;
    try {
      final upload = await StorageService.uploadAudio(File(draft.localAudioPath));
      final photoUrls = <String>[];
      for (final p in draft.attachedPhotoPaths) {
        final photo = await StorageService.uploadPhoto(File(p));
        photoUrls.add(photo.publicUrl);
      }
      final res = await FunctionsService.startVoiceMemoProcessing(
        audioUrl: upload.publicUrl,
        storagePath: upload.objectPath,
        projectId: draft.projectId,
        siteId: draft.siteId,
        mimeType: upload.mimeType,
        photoUrls: photoUrls,
      );
      _requestId = res['requestId'] as String?;
      await _persistDraft();
      _startPolling();
      return _requestId;
    } catch (e) {
      final err = e.toString();
      final canQueue = queueIfOffline && _isLikelyOfflineError(err);
      if (canQueue) {
        await ref.read(electricianQueueProvider.notifier).enqueue(
              QueuedSubmission(
                id: const Uuid().v4(),
                type: QueueSubmissionType.audioUpload,
                status: QueueStatus.queued,
                createdAt: DateTime.now(),
                attempts: 0,
                payload: {
                  'localAudioPath': draft.localAudioPath,
                  'projectId': draft.projectId,
                  'siteId': draft.siteId,
                },
                error: e.toString(),
              ),
            );
        throw Exception('queued_offline:$err');
      }
      rethrow;
    }
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

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_requestId == null) return;
      try {
        final res = await FunctionsService.pollVoiceMemoProcessing(
          requestId: _requestId!,
        );
        final status = res['status'] as String? ?? 'processing';
        if (status == 'completed') {
          final itemsRaw = (res['items'] as List? ?? const []);
          final parsed = itemsRaw
              .map((e) => _fromServerItem(Map<String, dynamic>.from(e)))
              .toList();
          state = AsyncValue.data(parsed);
          await _persistDraft();
          _pollTimer?.cancel();
        } else if (status == 'failed') {
          state = AsyncValue.error(
            Exception(res['error'] ?? 'AI processing failed'),
            StackTrace.current,
          );
          _pollTimer?.cancel();
        }
      } catch (_) {
        // Keep polling; transient network failures are expected.
      }
    });
  }

  AiExtractedItem _fromServerItem(Map<String, dynamic> m) {
    ElectricianCategory category = ElectricianCategory.generalReport;
    final cat = (m['category'] as String? ?? '').toLowerCase();
    if (cat.contains('blocker')) category = ElectricianCategory.blocker;
    if (cat.contains('material')) category = ElectricianCategory.materialRequest;
    if (cat.contains('work')) category = ElectricianCategory.workOrder;
    if (cat.contains('schedule')) category = ElectricianCategory.scheduleIssue;
    if (cat.contains('site')) category = ElectricianCategory.siteIssue;
    if (cat.contains('update')) category = ElectricianCategory.taskUpdate;

    ElectricianPriority priority = ElectricianPriority.medium;
    final p = (m['priority'] as String? ?? 'medium').toLowerCase();
    if (p == 'critical') priority = ElectricianPriority.critical;
    if (p == 'high') priority = ElectricianPriority.high;
    if (p == 'low') priority = ElectricianPriority.low;

    return AiExtractedItem(
      id: m['id'] as String? ?? const Uuid().v4(),
      transcriptSegment: m['transcriptSegment'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      category: category,
      priority: priority,
      location: m['location'] as String? ?? '',
      relatedTrade: m['relatedTrade'] as String? ?? _defaultTrade(),
      dueDate: m['dueDate'] == null
          ? null
          : DateTime.tryParse(m['dueDate'] as String),
      notes: m['notes'] as String? ?? '',
      isBlocker: m['isBlocker'] as bool? ?? false,
      isMaterialRequest: m['isMaterialRequest'] as bool? ?? false,
      attachedPhotos: List<String>.from(m['attachedPhotos'] as List? ?? []),
      routePreview: m['routePreview'] as String?,
      expanded: true,
    );
  }

  void updateItem(AiExtractedItem next) {
    final list = [...(state.valueOrNull ?? const <AiExtractedItem>[])];
    final idx = list.indexWhere((e) => e.id == next.id);
    if (idx < 0) return;
    list[idx] = next;
    state = AsyncValue.data(list);
    _persistDraft();
  }

  void deleteItem(String id) {
    final list = [...(state.valueOrNull ?? const <AiExtractedItem>[])];
    list.removeWhere((e) => e.id == id);
    state = AsyncValue.data(list);
    _persistDraft();
  }

  void addManualItem() {
    final list = [...(state.valueOrNull ?? const <AiExtractedItem>[])];
    list.add(
      AiExtractedItem(
        id: const Uuid().v4(),
        transcriptSegment: '',
        summary: '',
        category: ElectricianCategory.taskUpdate,
        priority: ElectricianPriority.medium,
        location: '',
        relatedTrade: _defaultTrade(),
        notes: '',
        isBlocker: false,
        isMaterialRequest: false,
        attachedPhotos: const [],
        expanded: true,
      ),
    );
    state = AsyncValue.data(list);
    _persistDraft();
  }

  Future<void> submitAll({
    required String projectId,
    required String siteId,
  }) async {
    final items = state.valueOrNull ?? const [];
    if (items.isEmpty) {
      throw Exception('No items to submit.');
    }
    final payload = items.map((e) => e.toJson()).toList();
    try {
      await FunctionsService.submitReviewedItems(
        requestId: _requestId ?? 'manual_${DateTime.now().millisecondsSinceEpoch}',
        projectId: projectId,
        siteId: siteId,
        items: payload.cast<Map<String, dynamic>>(),
      );
      await clearDraft();
    } catch (e) {
      await ref.read(electricianQueueProvider.notifier).enqueue(
            QueuedSubmission(
              id: const Uuid().v4(),
              type: QueueSubmissionType.finalSubmission,
              status: QueueStatus.queued,
              createdAt: DateTime.now(),
              attempts: 0,
              payload: {
                'requestId': _requestId ?? 'queued-${DateTime.now().millisecondsSinceEpoch}',
                'projectId': projectId,
                'siteId': siteId,
                'items': payload,
              },
              error: e.toString(),
            ),
          );
      rethrow;
    }
  }

  Future<void> clearDraft() async {
    _requestId = null;
    _draft = null;
    state = const AsyncValue.data([]);
    final file = await _draftFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final recordFlowProvider =
    AsyncNotifierProvider<RecordFlowController, List<AiExtractedItem>>(
  RecordFlowController.new,
);

final selectedSiteSummaryProvider = Provider<JobsiteSummary?>((ref) {
  final siteId = ref.watch(selectedElectricianSiteProvider).valueOrNull;
  final sites = ref.watch(electricianJobsitesProvider).valueOrNull ?? const [];
  final tasks = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
  if (siteId == null) return null;
  JobSiteModel? site;
  for (final s in sites) {
    if (s.id == siteId) {
      site = s;
      break;
    }
  }
  if (site == null) return null;

  final dueToday = tasks.where((t) {
    final due = t.assignment.dueDate;
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }).length;
  return JobsiteSummary(
    site: site,
    highPriorityCount: tasks
        .where((t) =>
            t.priority == ElectricianPriority.high ||
            t.priority == ElectricianPriority.critical)
        .length,
    blockerCount:
        tasks.where((t) => t.item.tier == TierType.issueOrBlocker).length,
    dueTodayCount: dueToday,
    materialPendingCount:
        tasks.where((t) => t.item.tier == TierType.materialRequest).length,
  );
});
