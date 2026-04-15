import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/extracted_item_model.dart';
import '../models/task_assignment_model.dart';
import '../models/notification_model.dart';
import '../models/project_model.dart';
import '../models/job_site_model.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── Projects ──────────────────────────────────────────────────────────────

  static Stream<List<ProjectModel>> projectsStream(List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    // Firestore whereIn supports max 10; MVP projects per user is small
    return _db
        .collection('projects')
        .where(FieldPath.documentId, whereIn: projectIds.take(10).toList())
        .snapshots()
        .map((snap) =>
            snap.docs.map(ProjectModel.fromFirestore).toList());
  }

  static Future<List<ProjectModel>> getAllProjects() async {
    final snap = await _db.collection('projects').get();
    return snap.docs.map(ProjectModel.fromFirestore).toList();
  }

  static Future<ProjectModel?> getProject(String id) async {
    final doc = await _db.collection('projects').doc(id).get();
    return doc.exists ? ProjectModel.fromFirestore(doc) : null;
  }

  // ── Job Sites ─────────────────────────────────────────────────────────────

  static Future<List<JobSiteModel>> getSitesForProject(
      String projectId) async {
    final snap = await _db
        .collection('job_sites')
        .where('projectId', isEqualTo: projectId)
        .get();
    return snap.docs.map(JobSiteModel.fromFirestore).toList();
  }

  static Stream<List<JobSiteModel>> sitesStream(String projectId) {
    return _db
        .collection('job_sites')
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snap) => snap.docs.map(JobSiteModel.fromFirestore).toList());
  }

  // ── Companies ─────────────────────────────────────────────────────────────

  static Future<CompanyModel?> getCompany(String id) async {
    final doc = await _db.collection('companies').doc(id).get();
    return doc.exists ? CompanyModel.fromFirestore(doc) : null;
  }

  static Future<List<CompanyModel>> getCompaniesForProject(
      String projectId) async {
    final snap = await _db
        .collection('companies')
        .where('activeProjectIds', arrayContains: projectId)
        .get();
    return snap.docs.map(CompanyModel.fromFirestore).toList();
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  static Future<List<UserModel>> getWorkersForCompany(
      String companyId) async {
    final snap = await _db
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'worker')
        .get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  // ── Extracted Items ───────────────────────────────────────────────────────

  /// Items visible to the GC: all items for their projects.
  static Stream<List<ExtractedItemModel>> gcItemsStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    return _db
        .collection('extracted_items')
        .where('projectId', whereIn: projectIds.take(10).toList())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ExtractedItemModel.fromFirestore).toList());
  }

  /// Blockers for GC.
  static Stream<List<ExtractedItemModel>> gcBlockersStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    return _db
        .collection('extracted_items')
        .where('projectId', whereIn: projectIds.take(10).toList())
        .where('tier', isEqualTo: 'issue_or_blocker')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ExtractedItemModel.fromFirestore).toList());
  }

  /// Schedule changes for GC.
  static Stream<List<ExtractedItemModel>> gcScheduleChangesStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    return _db
        .collection('extracted_items')
        .where('projectId', whereIn: projectIds.take(10).toList())
        .where('tier', isEqualTo: 'schedule_change')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ExtractedItemModel.fromFirestore).toList());
  }

  /// Items visible to a trade manager: items addressed to their company.
  static Stream<List<ExtractedItemModel>> managerItemsStream(
      String companyId) {
    return _db
        .collection('extracted_items')
        .where('recipientCompanyIds', arrayContains: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ExtractedItemModel.fromFirestore).toList());
  }

  /// All items (admin view).
  static Stream<List<ExtractedItemModel>> allItemsStream() {
    return _db
        .collection('extracted_items')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ExtractedItemModel.fromFirestore).toList());
  }

  static Future<ExtractedItemModel?> getExtractedItem(String id) async {
    final doc = await _db.collection('extracted_items').doc(id).get();
    return doc.exists ? ExtractedItemModel.fromFirestore(doc) : null;
  }

  // ── Task Assignments ──────────────────────────────────────────────────────

  /// Tasks assigned to a specific worker.
  static Stream<List<TaskAssignmentModel>> workerTasksStream(String userId) {
    return _db
        .collection('task_assignments')
        .where('assignedToUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(TaskAssignmentModel.fromFirestore).toList());
  }

  /// Tasks for a company (manager view).
  static Stream<List<TaskAssignmentModel>> companyTasksStream(
      String companyId) {
    return _db
        .collection('task_assignments')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(TaskAssignmentModel.fromFirestore).toList());
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  static Stream<List<NotificationModel>> notificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map(NotificationModel.fromFirestore).toList());
  }

  static Future<void> markNotificationRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({'read': true});
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── FCM token management ──────────────────────────────────────────────────

  static Future<void> upsertFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }
}
