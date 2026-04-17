import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_model.dart';
import '../models/extracted_item_model.dart';
import '../models/notification_model.dart';
import '../models/project_model.dart';
import '../models/job_site_model.dart';
import '../models/task_assignment_model.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

/// App data in Supabase Postgres (replaces Firestore).
class DatabaseService {
  static SupabaseClient get _c => SupabaseService.client;

  static int _cmpCreated<T>(T a, T b, DateTime? Function(T x) getT) {
    return (getT(b) ?? DateTime(0)).compareTo(getT(a) ?? DateTime(0));
  }

  // ── Projects ──────────────────────────────────────────────────────────────

  static Stream<List<ProjectModel>> projectsStream(List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    final want = projectIds.toSet();
    return _c.from('projects').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) => want.contains(r['id'] as String))
          .map((r) => ProjectModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Future<List<ProjectModel>> getAllProjects() async {
    final res = await _c.from('projects').select();
    final list = (res as List)
        .map((e) => ProjectModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
    return list;
  }

  static Future<ProjectModel?> getProject(String id) async {
    final row =
        await _c.from('projects').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return ProjectModel.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Job Sites ─────────────────────────────────────────────────────────────

  static Future<List<JobSiteModel>> getSitesForProject(String projectId) async {
    final res =
        await _c.from('job_sites').select().eq('project_id', projectId);
    final list = (res as List)
        .map((e) => JobSiteModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
    return list;
  }

  static Stream<List<JobSiteModel>> sitesStream(String projectId) {
    return _c.from('job_sites').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) => r['project_id'] == projectId)
          .map((r) => JobSiteModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  // ── Companies ─────────────────────────────────────────────────────────────

  static Future<CompanyModel?> getCompany(String id) async {
    final row =
        await _c.from('companies').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return CompanyModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<CompanyModel>> getCompaniesForProject(
      String projectId) async {
    final res = await _c
        .from('companies')
        .select()
        .filter('active_project_ids', 'cs', '{$projectId}');
    return (res as List)
        .map((e) => CompanyModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  static Future<List<UserModel>> getWorkersForCompany(String companyId) async {
    final res = await _c
        .from('app_users')
        .select()
        .eq('company_id', companyId)
        .eq('role', 'worker');
    return (res as List)
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<UserModel?> getUser(String uid) async {
    final row = await _c.from('app_users').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Extracted Items ───────────────────────────────────────────────────────

  static Stream<List<ExtractedItemModel>> gcItemsStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    final want = projectIds.toSet();
    return _c.from('extracted_items').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) => want.contains(r['project_id'] as String?))
          .map((r) =>
              ExtractedItemModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Stream<List<ExtractedItemModel>> gcBlockersStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    final want = projectIds.toSet();
    return _c.from('extracted_items').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) =>
              want.contains(r['project_id'] as String?) &&
              r['tier'] == 'issue_or_blocker')
          .map((r) =>
              ExtractedItemModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Stream<List<ExtractedItemModel>> gcScheduleChangesStream(
      List<String> projectIds) {
    if (projectIds.isEmpty) return Stream.value([]);
    final want = projectIds.toSet();
    return _c.from('extracted_items').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) =>
              want.contains(r['project_id'] as String?) &&
              r['tier'] == 'schedule_change')
          .map((r) =>
              ExtractedItemModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Stream<List<ExtractedItemModel>> managerItemsStream(
      String companyId) {
    return _c.from('extracted_items').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) {
            final arr = r['recipient_company_ids'];
            if (arr is! List) return false;
            return arr.contains(companyId);
          })
          .map((r) =>
              ExtractedItemModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Stream<List<ExtractedItemModel>> allItemsStream() {
    return _c.from('extracted_items').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .map((r) =>
              ExtractedItemModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list.take(100).toList();
    });
  }

  static Future<ExtractedItemModel?> getExtractedItem(String id) async {
    final row =
        await _c.from('extracted_items').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return ExtractedItemModel.fromJson(Map<String, dynamic>.from(row));
  }

  // ── Task Assignments ──────────────────────────────────────────────────────

  static Stream<List<TaskAssignmentModel>> workerTasksStream(String userId) {
    return _c.from('task_assignments').stream(primaryKey: ['id']).eq(
        'assigned_to_user_id', userId).map((rows) {
      final list = rows
          .map((r) =>
              TaskAssignmentModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Stream<List<TaskAssignmentModel>> companyTasksStream(
      String companyId) {
    return _c.from('task_assignments').stream(primaryKey: ['id']).map((rows) {
      final list = rows
          .where((r) => r['company_id'] == companyId)
          .map((r) =>
              TaskAssignmentModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  static Stream<List<NotificationModel>> notificationsStream(String userId) {
    return _c.from('notifications').stream(primaryKey: ['id']).eq(
        'user_id', userId).map((rows) {
      final list = rows
          .map((r) =>
              NotificationModel.fromJson(Map<String, dynamic>.from(r)))
          .toList()
        ..sort((a, b) => _cmpCreated(a, b, (x) => x.createdAt));
      return list;
    });
  }

  static Future<void> markNotificationRead(String notifId) async {
    await _c.from('notifications').update({'read': true}).eq('id', notifId);
  }

  static Future<int> getUnreadNotificationCount(String userId) async {
    final res = await _c
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('read', false);
    return (res as List).length;
  }

  // ── FCM token management ──────────────────────────────────────────────────

  static Future<void> upsertFcmToken(String uid, String token) async {
    final row =
        await _c.from('app_users').select('fcm_tokens').eq('id', uid).maybeSingle();
    if (row == null) return;
    final tokens = List<String>.from(row['fcm_tokens'] as List? ?? []);
    if (tokens.contains(token)) return;
    tokens.add(token);
    await _c.from('app_users').update({'fcm_tokens': tokens}).eq('id', uid);
  }
}
