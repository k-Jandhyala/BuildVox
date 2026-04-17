import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/extracted_item_model.dart';
import '../models/task_assignment_model.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

// ── GC providers ──────────────────────────────────────────────────────────────

final gcBlockersProvider = StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return DatabaseService.gcBlockersStream(user.assignedProjectIds);
});

final gcScheduleChangesProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return DatabaseService.gcScheduleChangesStream(user.assignedProjectIds);
});

final gcProjectFeedProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return DatabaseService.gcItemsStream(user.assignedProjectIds);
});

// ── Manager providers ─────────────────────────────────────────────────────────

final managerItemsProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.companyId == null) return Stream.value([]);
  return DatabaseService.managerItemsStream(user!.companyId!);
});

// ── Worker providers ──────────────────────────────────────────────────────────

final workerTasksProvider =
    StreamProvider<List<TaskAssignmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return DatabaseService.workerTasksStream(user.uid);
});

// ── Admin providers ───────────────────────────────────────────────────────────

final allItemsProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.role.name != 'admin') return Stream.value([]);
  return DatabaseService.allItemsStream();
});

// ── Company tasks (manager task board) ───────────────────────────────────────

final companyTasksProvider =
    StreamProvider<List<TaskAssignmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.companyId == null) return Stream.value([]);
  return DatabaseService.companyTasksStream(user!.companyId!);
});
