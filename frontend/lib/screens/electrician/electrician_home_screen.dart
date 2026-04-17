import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/electrician_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';

class ElectricianHomeScreen extends ConsumerWidget {
  const ElectricianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(selectedSiteSummaryProvider);
    final tasks = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
    final warnings = ref.watch(electricianWarningsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hi ${user?.name.split(' ').first ?? 'Electrician'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          summary == null ? 'No active jobsite selected' : summary.site.name,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (summary != null)
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _StatCard('High Priority', '${summary.highPriorityCount}',
                  const Icon(Icons.priority_high_rounded)),
              _StatCard('Blockers', '${summary.blockerCount}',
                  const Icon(Icons.block_rounded)),
              _StatCard('Due Today', '${summary.dueTodayCount}',
                  const Icon(Icons.today_rounded)),
              _StatCard('Material Pending', '${summary.materialPendingCount}',
                  const Icon(Icons.inventory_2_rounded)),
            ],
          ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Quick Actions',
          actionLabel: null,
          onAction: null,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _QuickActionChip(icon: Icons.edit_note_rounded, label: 'Add Update'),
            _QuickActionChip(icon: Icons.inventory_2_rounded, label: 'Request Materials'),
            _QuickActionChip(icon: Icons.assignment_late_rounded, label: 'Raise Work Order'),
            _QuickActionChip(icon: Icons.report_problem_rounded, label: 'Flag Blocker'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Assigned to Me',
          actionLabel: 'View all',
          onAction: () => DefaultTabController.of(context),
        ),
        ..._priorityBuckets(tasks).entries.map((entry) {
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return _PrioritySection(priority: entry.key, tasks: entry.value);
        }),
        const SizedBox(height: 10),
        _SectionTitle(
          title: 'Site Warnings',
          actionLabel: warnings.isEmpty ? null : 'Open',
          onAction: warnings.isEmpty ? null : () {},
        ),
        if (warnings.isEmpty)
          const _EmptyDarkCard(message: 'No active site warnings.')
        else
          ...warnings.take(3).map((w) => _WarningPreviewCard(warning: w)),
      ],
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

class _PrioritySection extends StatelessWidget {
  final ElectricianPriority priority;
  final List<ElectricianTask> tasks;
  const _PrioritySection({required this.priority, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final label = priority.name[0].toUpperCase() + priority.name.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label (${tasks.length})',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...tasks.take(3).map((t) => InkWell(
                onTap: () => context.push('/${t.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${t.assignment.id}',
                    extra: {'extractedItemId': t.item.id}),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.item.normalizedSummary,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${t.item.unitOrArea ?? 'No location'} · ${t.assignment.status.label}',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ))
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget icon;
  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: const IconThemeData(color: Color(0xFF60A5FA)),
            child: icon,
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF93C5FD)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _WarningPreviewCard extends StatelessWidget {
  final SiteWarning warning;
  const _WarningPreviewCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warningSeverityColor(warning.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            warning.title,
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(warning.description,
              style: const TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _EmptyDarkCard extends StatelessWidget {
  final String message;
  const _EmptyDarkCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF94A3B8))),
    );
  }
}
