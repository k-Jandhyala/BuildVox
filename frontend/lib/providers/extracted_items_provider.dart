import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/extracted_item_model.dart';
import '../models/task_assignment_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

// ── GC providers ──────────────────────────────────────────────────────────────

final gcBlockersProvider = StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return FirestoreService.gcBlockersStream(user.assignedProjectIds);
});

final gcScheduleChangesProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return FirestoreService.gcScheduleChangesStream(user.assignedProjectIds);
});

final gcProjectFeedProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return FirestoreService.gcItemsStream(user.assignedProjectIds);
});

// ── Manager providers ─────────────────────────────────────────────────────────

final managerItemsProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.companyId == null) return Stream.value([]);
  return FirestoreService.managerItemsStream(user!.companyId!);
});

// ── Worker providers ──────────────────────────────────────────────────────────

final workerTasksProvider =
    StreamProvider<List<TaskAssignmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return FirestoreService.workerTasksStream(user.uid);
});

// ── Admin providers ───────────────────────────────────────────────────────────

final allItemsProvider =
    StreamProvider<List<ExtractedItemModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.role.name != 'admin') return Stream.value([]);
  return FirestoreService.allItemsStream();
});

// ── Company tasks (manager task board) ───────────────────────────────────────

final companyTasksProvider =
    StreamProvider<List<TaskAssignmentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.companyId == null) return Stream.value([]);
  return FirestoreService.companyTasksStream(user!.companyId!);
});
