import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../models/task_assignment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/extracted_items_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/urgency_chip.dart';

class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(workerTasksProvider);

    return tasksAsync.when(
      loading: () => const InlineLoader(message: 'Loading your tasks…'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No tasks assigned yet',
            subtitle: 'When your manager assigns you work,\nit will appear here.',
          );
        }

        // Group by status
        final active = tasks
            .where((t) =>
                t.status != ItemStatus.done &&
                t.status != ItemStatus.cancelled)
            .toList();
        final completed = tasks
            .where((t) =>
                t.status == ItemStatus.done ||
                t.status == ItemStatus.cancelled)
            .toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workerTasksProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Active (${active.length})',
                    color: BVColors.primary),
                ...active.map((t) => _TaskTile(task: t)),
              ],
              if (completed.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Completed (${completed.length})',
                    color: BVColors.textSecondary),
                ...completed.map((t) => _TaskTile(task: t)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final TaskAssignmentModel task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ExtractedItemModel?>(
      future: DatabaseService.getExtractedItem(task.extractedItemId),
      builder: (context, snapshot) {
        final item = snapshot.data;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              context.go(
                '/worker/task/${task.id}',
                extra: {'extractedItemId': task.extractedItemId},
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (item != null) TierBadge(tier: item.tier),
                      const SizedBox(width: 8),
                      if (item != null) UrgencyChip(urgency: item.urgency),
                      const Spacer(),
                      _StatusBadge(status: task.status),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Summary
                  Text(
                    item?.normalizedSummary ?? 'Loading…',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BVColors.onSurface,
                      height: 1.45,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (item?.unitOrArea != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: BVColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item!.unitOrArea!,
                          style: const TextStyle(
                              fontSize: 12, color: BVColors.textSecondary),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Date
                  if (task.createdAt != null)
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.createdAt!),
                      style: const TextStyle(
                          fontSize: 11, color: BVColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ItemStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
