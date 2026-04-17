import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';
import '../models/job_site_model.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

/// Streams the projects assigned to the current user.
final userProjectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.assignedProjectIds.isEmpty) {
    return Stream.value([]);
  }
  return DatabaseService.projectsStream(user.assignedProjectIds);
});

/// All projects — admin view.
final allProjectsProvider = FutureProvider<List<ProjectModel>>((ref) {
  return DatabaseService.getAllProjects();
});

/// The currently selected project ID (used on submit-memo screen, etc.)
final StateProvider<String?> selectedProjectIdProvider =
    StateProvider<String?>((ref) => null);

/// Sites for the currently selected project.
final selectedProjectSitesProvider =
    FutureProvider<List<JobSiteModel>>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null) return [];
  return DatabaseService.getSitesForProject(projectId);
});

/// The currently selected site ID.
final StateProvider<String?> selectedSiteIdProvider =
    StateProvider<String?>((ref) => null);
