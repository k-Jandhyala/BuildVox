import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/electrician_models.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';

class ElectricianTasksScreen extends ConsumerStatefulWidget {
  const ElectricianTasksScreen({super.key});

  @override
  ConsumerState<ElectricianTasksScreen> createState() =>
      _ElectricianTasksScreenState();
}

class _ElectricianTasksScreenState
    extends ConsumerState<ElectricianTasksScreen> {
  ItemStatus? _statusFilter;
  bool _dueTodayOnly = false;
  bool _blockersOnly = false;
  bool _materialOnly = false;

  bool get _isAllFilter =>
      !_dueTodayOnly &&
      !_blockersOnly &&
      !_materialOnly &&
      _statusFilter == null;

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(electricianTasksProvider).valueOrNull ?? const [];
    final now = DateTime.now();

    final filtered = all.where((t) {
      if (_statusFilter != null &&
          t.assignment.status != _statusFilter) return false;
      if (_dueTodayOnly) {
        final due = t.assignment.dueDate;
        if (due == null ||
            due.year != now.year ||
            due.month != now.month ||
            due.day != now.day) return false;
      }
      if (_blockersOnly && t.item.tier != TierType.issueOrBlocker)
        return false;
      if (_materialOnly && t.item.tier != TierType.materialRequest)
        return false;
      return true;
    }).toList();

    final grouped = <ElectricianPriority, List<ElectricianTask>>{
      ElectricianPriority.critical: filtered
          .where((t) => t.priority == ElectricianPriority.critical)
          .toList(),
      ElectricianPriority.high: filtered
          .where((t) => t.priority == ElectricianPriority.high)
          .toList(),
      ElectricianPriority.medium: filtered
          .where((t) => t.priority == ElectricianPriority.medium)
          .toList(),
      ElectricianPriority.low: filtered
          .where((t) => t.priority == ElectricianPriority.low)
          .toList(),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── Title ──────────────────────────────────────────────────────
        Row(
          children: [
            const Text(
              'My Tasks',
              style: TextStyle(
                  color: BVColors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: BVColors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${filtered.length}',
                style: const TextStyle(
                    color: BVColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Filter chips ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterPill(
                label: 'All',
                selected: _isAllFilter,
                onTap: () => setState(() {
                  _dueTodayOnly = false;
                  _blockersOnly = false;
                  _materialOnly = false;
                  _statusFilter = null;
                }),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Due Today',
                selected: _dueTodayOnly,
                onTap: () =>
                    setState(() => _dueTodayOnly = !_dueTodayOnly),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Blockers',
                selected: _blockersOnly,
                onTap: () =>
                    setState(() => _blockersOnly = !_blockersOnly),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Materials',
                selected: _materialOnly,
                onTap: () =>
                    setState(() => _materialOnly = !_materialOnly),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'In Progress',
                selected: _statusFilter == ItemStatus.inProgress,
                onTap: () => setState(() => _statusFilter =
                    _statusFilter == ItemStatus.inProgress
                        ? null
                        : ItemStatus.inProgress),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'Completed',
                selected: _statusFilter == ItemStatus.done,
                onTap: () => setState(() => _statusFilter =
                    _statusFilter == ItemStatus.done
                        ? null
                        : ItemStatus.done),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Task list ───────────────────────────────────────────────────
        if (filtered.isEmpty)
          _EmptyState()
        else
          ...grouped.entries.expand((entry) {
            if (entry.value.isEmpty) return const <Widget>[];
            return [_TaskGroup(priority: entry.key, tasks: entry.value)];
          }),
      ],
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BVColors.primary : BVColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? BVColors.onPrimary : BVColors.textSecondary,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final ElectricianPriority priority;
  final List<ElectricianTask> tasks;
  const _TaskGroup({required this.priority, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final label =
        priority.name[0].toUpperCase() + priority.name.substring(1);
    final color = _priorityColor(priority);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$label  ·  ${tasks.length}',
                style: const TextStyle(
                  color: BVColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _TaskCard(task: t, priorityColor: color)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ElectricianTask task;
  final Color priorityColor;
  const _TaskCard(
      {required this.task, required this.priorityColor});

  @override
  Widget build(BuildContext context) {
    final due = task.assignment.dueDate;
    final now = DateTime.now();
    final isOverdue =
        due != null && due.isBefore(DateTime(now.year, now.month, now.day));
    final isToday = due != null &&
        due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;

    final dueColor = isOverdue
        ? BVColors.danger
        : isToday
            ? BVColors.primary
            : BVColors.textMuted;

    return GestureDetector(
      onTap: () => context.push(
          '/${task.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${task.assignment.id}',
          extra: {'extractedItemId': task.item.id}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: BVColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left priority bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + status chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.item.normalizedSummary,
                              style: const TextStyle(
                                color: BVColors.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(status: task.assignment.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Meta row
                      Row(
                        children: [
                          if (task.item.unitOrArea != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: BVColors.surfaceElevated,
                                borderRadius:
                                    BorderRadius.circular(999),
                              ),
                              child: Text(
                                task.item.unitOrArea!,
                                style: const TextStyle(
                                    color: BVColors.textSecondary,
                                    fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (due != null)
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    color: dueColor, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  isToday
                                      ? 'Due today'
                                      : isOverdue
                                          ? 'Overdue'
                                          : DateFormat('MMM d')
                                              .format(due),
                                  style: TextStyle(
                                      color: dueColor, fontSize: 11),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded,
                    color: BVColors.textMuted, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ItemStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      ItemStatus.done => (BVColors.success, BVColors.successBg),
      ItemStatus.inProgress => (BVColors.primary, BVColors.warningBg),
      ItemStatus.pending =>
        (BVColors.textSecondary, BVColors.surfaceElevated),
      _ => (BVColors.textSecondary, BVColors.surfaceElevated),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined,
                color: BVColors.textMuted, size: 56),
            SizedBox(height: 14),
            Text(
              'No tasks match your filters',
              style: TextStyle(
                  color: BVColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 6),
            Text(
              'Try adjusting your filters',
              style:
                  TextStyle(color: BVColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

Color _priorityColor(ElectricianPriority p) => switch (p) {
      ElectricianPriority.critical => BVColors.danger,
      ElectricianPriority.high => BVColors.primary,
      ElectricianPriority.medium => BVColors.info,
      ElectricianPriority.low => BVColors.success,
    };
