import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';

class ManagerOverviewScreen extends ConsumerWidget {
  const ManagerOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(companyTasksProvider);

    return tasksAsync.when(
      loading: () => const InlineLoader(message: 'Loading overview…'),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: const TextStyle(color: BVColors.blocker))),
      data: (tasks) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueSoonCutoff = today.add(const Duration(days: 3));

        final open = tasks.where((t) => t.status != ItemStatus.done).toList();
        final done = tasks.where((t) => t.status == ItemStatus.done).toList();

        int overdue = 0, dueSoon = 0, dueLater = 0;
        for (final t in open) {
          final due = t.dueDate;
          if (due == null) {
            dueLater++;
            continue;
          }
          final dueDay = DateTime(due.year, due.month, due.day);
          if (dueDay.isBefore(today)) {
            overdue++;
          } else if (!dueDay.isAfter(dueSoonCutoff)) {
            dueSoon++;
          } else {
            dueLater++;
          }
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyTasksProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Text(
                'Overview',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BVColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d').format(now),
                style: const TextStyle(fontSize: 13, color: BVColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Task Summary'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Overdue',
                      value: overdue,
                      color: BVColors.blocker,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Due Soon',
                      value: dueSoon,
                      color: BVColors.primary,
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Due Later',
                      value: dueLater,
                      color: BVColors.textSecondary,
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Done',
                      value: done.length,
                      color: BVColors.done,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Total Tasks'),
              const SizedBox(height: 12),
              _TotalCard(total: tasks.length, open: open.length, done: done.length),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: BVColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: BVColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int total, open, done;
  const _TotalCard({required this.total, required this.open, required this.done});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total tasks total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BVColors.onSurface,
                ),
              ),
              Text(
                '${(pct * 100).round()}% complete',
                style: const TextStyle(
                  fontSize: 13,
                  color: BVColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: BVColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(BVColors.done),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Dot(color: BVColors.done),
              const SizedBox(width: 4),
              Text('$done done', style: const TextStyle(fontSize: 12, color: BVColors.textSecondary)),
              const SizedBox(width: 16),
              _Dot(color: BVColors.primary),
              const SizedBox(width: 4),
              Text('$open open', style: const TextStyle(fontSize: 12, color: BVColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
