import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/electrician_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';
import '../../widgets/skeleton_shimmer.dart';

class ElectricianHomeScreen extends ConsumerWidget {
  const ElectricianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(selectedSiteSummaryProvider);
    final tasks = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
    final warnings = ref.watch(electricianWarningsProvider);
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(selectedSiteSummaryProvider);
        ref.invalidate(electricianTasksProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Text(
            'Hi ${user?.name.split(' ').first ?? 'there'} 👋',
            style: const TextStyle(
              color: BVColors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM d').format(now),
            style: const TextStyle(color: BVColors.textSecondary, fontSize: 14),
          ),
          if (summary != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: BVColors.textMuted, size: 14),
                const SizedBox(width: 4),
                Text(
                  summary.site.name,
                  style: const TextStyle(
                      color: BVColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Stat cards ──────────────────────────────────────────────────
          if (summary != null)
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _StatCard(
                  label: 'High Priority',
                  value: summary.highPriorityCount,
                  dot: BVColors.danger,
                  bg: summary.highPriorityCount > 0 ? BVColors.dangerBg : null,
                ),
                _StatCard(
                  label: 'Blockers',
                  value: summary.blockerCount,
                  dot: BVColors.danger,
                  bg: summary.blockerCount > 0 ? BVColors.dangerBg : null,
                ),
                _StatCard(
                  label: 'Due Today',
                  value: summary.dueTodayCount,
                  dot: BVColors.primary,
                  bg: summary.dueTodayCount > 0 ? BVColors.warningBg : null,
                ),
                _StatCard(
                  label: 'Material Pending',
                  value: summary.materialPendingCount,
                  dot: BVColors.info,
                  bg: summary.materialPendingCount > 0 ? BVColors.infoBg : null,
                ),
              ],
            )
          else
            const SkeletonShimmer(height: 200),

          const SizedBox(height: 28),

          // ── Quick Actions ────────────────────────────────────────────────
          _SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: const [
              _QuickAction(
                  icon: Icons.edit_note_rounded, label: 'Add Update'),
              _QuickAction(
                  icon: Icons.inventory_2_outlined,
                  label: 'Request Materials'),
              _QuickAction(
                  icon: Icons.assignment_outlined,
                  label: 'Raise Work Order'),
              _QuickAction(
                  icon: Icons.report_problem_outlined,
                  label: 'Flag Blocker',
                  danger: true),
            ],
          ),

          const SizedBox(height: 28),

          // ── Site Warnings ────────────────────────────────────────────────
          _SectionHeader(
            title: 'Site Warnings',
            action: warnings.isNotEmpty ? 'View all' : null,
            onAction: warnings.isNotEmpty ? () {} : null,
          ),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            _AllClearBanner()
          else
            ...warnings.take(3).map((w) => _WarningCard(warning: w)),

          const SizedBox(height: 28),

          // ── Assigned to Me ───────────────────────────────────────────────
          _SectionHeader(
            title: 'Assigned to Me',
            action: 'View all',
            onAction: () {},
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            _EmptyAssigned()
          else
            ..._priorityBuckets(tasks).entries.expand((entry) {
              if (entry.value.isEmpty) return const <Widget>[];
              return entry.value
                  .take(3)
                  .map((t) => _TaskCard(task: t));
            }),
        ],
      ),
    );
  }
}

Map<ElectricianPriority, List<ElectricianTask>> _priorityBuckets(
    List<ElectricianTask> tasks) {
  return {
    ElectricianPriority.critical:
        tasks.where((t) => t.priority == ElectricianPriority.critical).toList(),
    ElectricianPriority.high:
        tasks.where((t) => t.priority == ElectricianPriority.high).toList(),
    ElectricianPriority.medium:
        tasks.where((t) => t.priority == ElectricianPriority.medium).toList(),
    ElectricianPriority.low:
        tasks.where((t) => t.priority == ElectricianPriority.low).toList(),
  };
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: BVColors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                  color: BVColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color dot;
  final Color? bg;

  const _StatCard({
    required this.label,
    required this.value,
    required this.dot,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg ?? BVColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              color: value > 0 ? dot : BVColors.textMuted,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                color: BVColors.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _QuickAction(
      {required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final accent = danger ? BVColors.danger : BVColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: danger ? BVColors.danger : BVColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllClearBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BVColors.successBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: BVColors.success, size: 18),
          SizedBox(width: 10),
          Text(
            'All clear — no active site warnings',
            style: TextStyle(color: BVColors.success, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final SiteWarning warning;
  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warningSeverityColor(warning.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning.title,
                      style: const TextStyle(
                          color: BVColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      warning.description,
                      style: const TextStyle(
                          color: BVColors.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ElectricianTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);
    return GestureDetector(
      onTap: () => context.push(
          '/${task.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${task.assignment.id}',
          extra: {'extractedItemId': task.item.id}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: BVColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.item.normalizedSummary,
                        style: const TextStyle(
                            color: BVColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${task.item.unitOrArea ?? 'No location'} · ${task.assignment.status.label}',
                        style: const TextStyle(
                            color: BVColors.textSecondary, fontSize: 12),
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

class _EmptyAssigned extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                color: BVColors.textMuted, size: 48),
            SizedBox(height: 10),
            Text(
              "You're all caught up",
              style: TextStyle(
                  color: BVColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'No tasks assigned to you right now',
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
