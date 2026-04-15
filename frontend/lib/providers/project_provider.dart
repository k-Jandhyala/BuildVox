import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';
import '../models/job_site_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Streams the projects assigned to the current user.
final userProjectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.assignedProjectIds.isEmpty) {
    return Stream.value([]);
  }
  return FirestoreService.projectsStream(user.assignedProjectIds);
});

/// All projects — admin view.
final allProjectsProvider = FutureProvider<List<ProjectModel>>((ref) {
  return FirestoreService.getAllProjects();
});

/// The currently selected project ID (used on submit-memo screen, etc.)
final selectedProjectIdProvider = StateProvider<String?>((ref) {
  // Auto-select the first project when projects load
  ref.listen(userProjectsProvider, (_, next) {
    if (next.valueOrNull?.isNotEmpty == true) {
      final current = ref.read(selectedProjectIdProvider);
      if (current == null) {
        ref.read(selectedProjectIdProvider.notifier).state =
            next.valueOrNull!.first.id;
      }
    }
  });
  return null;
});

/// Sites for the currently selected project.
final selectedProjectSitesProvider =
    FutureProvider<List<JobSiteModel>>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null) return [];
  return FirestoreService.getSitesForProject(projectId);
});

/// The currently selected site ID.
final selectedSiteIdProvider = StateProvider<String?>((ref) {
  ref.listen(selectedProjectSitesProvider, (_, next) {
    if (next.valueOrNull?.isNotEmpty == true) {
      final current = ref.read(selectedSiteIdProvider);
      if (current == null) {
        ref.read(selectedSiteIdProvider.notifier).state =
            next.valueOrNull!.first.id;
      }
    }
  });
  return null;
});
