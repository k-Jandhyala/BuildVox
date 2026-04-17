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

class GcTaskBoardScreen extends ConsumerWidget {
  const GcTaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(gcAssignedTasksProvider);
    return tasksAsync.when(
      loading: () => const InlineLoader(message: 'Loading your tasks…'),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.task_outlined,
            title: 'No tasks yet',
            subtitle:
                'Tasks you assign (including to yourself) will show up here.',
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
          if (due == null) {
            dueLater.add(t);
            continue;
          }
          final dueDay = DateTime(due.year, due.month, due.day);
          if (dueDay.isBefore(today)) {
            overdue.add(t);
          } else if (dueDay.isBefore(dueSoonCutoff) ||
              dueDay.isAtSameMomentAs(dueSoonCutoff)) {
            dueSoon.add(t);
          } else {
            dueLater.add(t);
          }
        }

        int cmp(TaskAssignmentModel a, TaskAssignmentModel b) {
          final ad = a.dueDate ?? DateTime(9999);
          final bd = b.dueDate ?? DateTime(9999);
          final byDue = ad.compareTo(bd);
          if (byDue != 0) return byDue;
          return (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0));
        }

        overdue.sort(cmp);
        dueSoon.sort(cmp);
        dueLater.sort(cmp);
        done.sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0)));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(gcAssignedTasksProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (overdue.isNotEmpty)
                _DueSection(
                    label: 'Overdue', color: BVColors.blocker, tasks: overdue),
              if (dueSoon.isNotEmpty)
                _DueSection(
                    label: 'Due soon', color: BVColors.primary, tasks: dueSoon),
              if (dueLater.isNotEmpty)
                _DueSection(
                    label: 'Due later',
                    color: BVColors.textSecondary,
                    tasks: dueLater),
              if (done.isNotEmpty)
                _DueSection(label: 'Done', color: BVColors.done, tasks: done),
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
  const _DueSection({
    required this.label,
    required this.color,
    required this.tasks,
  });

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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${label.toUpperCase()}  ·  ${tasks.length}',
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
      future: DatabaseService.getExtractedItem(task.extractedItemId),
      builder: (context, itemSnap) {
        final item = itemSnap.data;
        return FutureBuilder<UserModel?>(
          future: DatabaseService.getUser(task.assignedToUserId),
          builder: (context, userSnap) {
            final assignee = userSnap.data;
            return Card(
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
                          const Spacer(),
                          if (task.dueDate != null)
                            Text(
                              'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: BVColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
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
                    Row(
                      children: [
                        if (assignee != null) ...[
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: BVColors.primary.withOpacity(0.15),
                            child: Text(
                              assignee.initials,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: BVColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            assignee.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: BVColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          task.status.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: task.status.color,
                            fontWeight: FontWeight.w700,
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

