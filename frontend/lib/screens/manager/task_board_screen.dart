import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../models/task_assignment_model.dart';
import '../../models/user_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../services/database_service.dart';
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
        child: Text('Error: $e', style: const TextStyle(color: BVColors.danger)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.view_kanban_outlined,
            title: 'No tasks yet',
            subtitle: 'Assign tasks from the Requests tab.\nThey will appear here.',
          );
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueSoonCutoff = today.add(const Duration(days: 3));

        final open = tasks.where((t) => t.status != ItemStatus.done).toList();
        final done = tasks.where((t) => t.status == ItemStatus.done).toList();

        final overdue = <TaskAssignmentModel>[];
        final dueSoon = <TaskAssignmentModel>[];
        final dueLater = <TaskAssignmentModel>[];

        for (final t in open) {
          final due = t.dueDate;
          if (due == null) { dueLater.add(t); continue; }
          final dueDay = DateTime(due.year, due.month, due.day);
          if (dueDay.isBefore(today)) {
            overdue.add(t);
          } else if (!dueDay.isAfter(dueSoonCutoff)) {
            dueSoon.add(t);
          } else {
            dueLater.add(t);
          }
        }

        int cmp(TaskAssignmentModel a, TaskAssignmentModel b) {
          final byDue = (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999));
          if (byDue != 0) return byDue;
          return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
        }
        overdue.sort(cmp);
        dueSoon.sort(cmp);
        dueLater.sort(cmp);
        done.sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyTasksProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _DueSection(label: 'Overdue', color: BVColors.danger, tasks: overdue),
              _DueSection(label: 'Due Soon', color: BVColors.primary, tasks: dueSoon),
              _DueSection(label: 'Due Later', color: BVColors.textSecondary, tasks: dueLater),
              _DueSection(label: 'Done', color: BVColors.success, tasks: done),
            ],
          ),
        );
      },
    );
  }
}

class _DueSection extends StatelessWidget {
  final String label;
  final Color color;
  final List<TaskAssignmentModel> tasks;
  const _DueSection({required this.label, required this.color, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${label.toUpperCase()}  ·  ${tasks.length}',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: BVColors.textSecondary, letterSpacing: 0.8,
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
      future: DatabaseService.getExtractedItem(task.extractedItemId),
      builder: (context, itemSnap) {
        final item = itemSnap.data;
        return FutureBuilder<UserModel?>(
          future: DatabaseService.getUser(task.assignedToUserId),
          builder: (context, userSnap) {
            final worker = userSnap.data;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: BoxDecoration(
                color: BVColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item != null)
                      Row(
                        children: [
                          TierBadge(tier: item.tier, compact: true),
                          const SizedBox(width: 6),
                          UrgencyChip(urgency: item.urgency),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      item?.normalizedSummary ?? '…',
                      style: const TextStyle(
                        fontSize: 13, color: BVColors.onSurface,
                        fontWeight: FontWeight.w500, height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (worker != null) ...[
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: BVColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              worker.initials,
                              style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: BVColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 12, color: BVColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (task.createdAt != null)
                          Text(
                            DateFormat('MMM d').format(task.createdAt!),
                            style: const TextStyle(
                              fontSize: 11, color: BVColors.textMuted,
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
