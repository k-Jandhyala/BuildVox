import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../models/task_assignment_model.dart';
import '../../models/user_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/urgency_chip.dart';

class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(companyTasksProvider);

    return tasksAsync.when(
      loading: () => const InlineLoader(message: 'Loading task board…'),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.view_kanban_outlined,
            title: 'No tasks yet',
            subtitle:
                'Assign tasks from the Requests tab.\nThey will appear here.',
          );
        }

        // Group by status
        final grouped = <ItemStatus, List<TaskAssignmentModel>>{};
        for (final status in [
          ItemStatus.pending,
          ItemStatus.acknowledged,
          ItemStatus.inProgress,
          ItemStatus.done,
        ]) {
          grouped[status] =
              tasks.where((t) => t.status == status).toList();
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyTasksProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: grouped.entries
                .where((e) => e.value.isNotEmpty)
                .map((e) => _StatusColumn(
                      status: e.key,
                      tasks: e.value,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _StatusColumn extends StatelessWidget {
  final ItemStatus status;
  final List<TaskAssignmentModel> tasks;

  const _StatusColumn({required this.status, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${status.label.toUpperCase()}  ·  ${tasks.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BVColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _TaskBoardCard(task: t)),
      ],
    );
  }
}

class _TaskBoardCard extends StatelessWidget {
  final TaskAssignmentModel task;
  const _TaskBoardCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExtractedItemModel?>(
      future: FirestoreService.getExtractedItem(task.extractedItemId),
      builder: (context, itemSnap) {
        final item = itemSnap.data;
        return FutureBuilder<UserModel?>(
          future: FirestoreService.getUser(task.assignedToUserId),
          builder: (context, userSnap) {
            final worker = userSnap.data;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier + urgency
                    if (item != null)
                      Row(
                        children: [
                          TierBadge(tier: item.tier, compact: true),
                          const SizedBox(width: 6),
                          UrgencyChip(urgency: item.urgency),
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Summary
                    Text(
                      item?.normalizedSummary ?? 'Loading…',
                      style: const TextStyle(
                        fontSize: 13,
                        color: BVColors.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Worker + date
                    Row(
                      children: [
                        if (worker != null) ...[
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                BVColors.primary.withOpacity(0.15),
                            child: Text(
                              worker.initials,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: BVColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: BVColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (task.createdAt != null)
                          Text(
                            DateFormat('MMM d').format(task.createdAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: BVColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
