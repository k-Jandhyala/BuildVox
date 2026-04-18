import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/electrician_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/bv_modal_sheet.dart';
import '../../widgets/skeleton_shimmer.dart';

/// Shared home for Electrician and Plumber trade workers.
class TradeWorkerHomeScreen extends ConsumerWidget {
  final bool isPlumber;

  const TradeWorkerHomeScreen({super.key, required this.isPlumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(selectedSiteSummaryProvider);
    final tasks = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
    final warnings = ref.watch(electricianWarningsProvider);
    final tradeName = isPlumber ? 'Plumber' : 'Electrician';

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: BVSpacing.screenHorizontal,
        vertical: BVSpacing.sectionGap,
      ),
      children: [
        Text(
          'Hi ${user?.name.split(' ').first ?? tradeName}',
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
        const SizedBox(height: BVSpacing.sectionGap),
        if (summary != null)
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _StatCard(
                'High Priority Tasks',
                '${summary.highPriorityCount}',
                icon: Icons.priority_high_rounded,
                accent: BVColors.primary,
              ),
              _StatCard(
                'Blockers',
                '${summary.blockerCount}',
                icon: Icons.block_rounded,
                accent: BVColors.blocker,
              ),
              _StatCard(
                'Due Today',
                '${summary.dueTodayCount}',
                icon: Icons.today_rounded,
                accent: BVColors.accent,
              ),
              _StatCard(
                'Material Pending',
                '${summary.materialPendingCount}',
                icon: Icons.inventory_2_rounded,
                accent: BVColors.done,
              ),
            ],
          )
        else
          const SkeletonShimmer(height: 230),
        const SizedBox(height: BVSpacing.sectionGap),
        const _SectionTitle(title: 'Quick Actions'),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            Consumer(
              builder: (context, ref, _) {
                return _QuickActionChip(
                  icon: Icons.edit_note_rounded,
                  label: 'Add Update',
                  onTap: () {
                    ref.read(tradeWorkerShellTabProvider.notifier).state = 2;
                    ref.read(recordScreenAutofocusTriggerProvider.notifier).state++;
                  },
                );
              },
            ),
            _QuickActionChip(
              icon: Icons.inventory_2_rounded,
              label: 'Request Materials',
              onTap: () => _showMaterialRequestSheet(context),
            ),
            if (isPlumber)
              _QuickActionChip(
                icon: Icons.water_damage_rounded,
                label: 'Report Leak/Issue',
                urgency: true,
                onTap: () => _showLeakIssueSheet(context),
              )
            else
              _QuickActionChip(
                icon: Icons.assignment_late_rounded,
                label: 'Raise Work Order',
                onTap: () => _showWorkOrderStub(context),
              ),
            _QuickActionChip(
              icon: Icons.report_problem_rounded,
              label: 'Flag Blocker',
              danger: true,
              onTap: () => _showBlockerStub(context),
            ),
            const _QuickActionChip(
              icon: Icons.map_outlined,
              label: 'View Site Plan',
            ),
          ],
        ),
        const SizedBox(height: BVSpacing.sectionGap),
        _SectionTitle(
          title: 'Site Warnings',
          actionLabel: warnings.isEmpty ? null : 'Open',
          onAction: warnings.isEmpty ? null : () {},
        ),
        if (warnings.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BVColors.done.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BVColors.done.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: BVColors.done),
                SizedBox(width: 8),
                Text('All clear - no active warnings'),
              ],
            ),
          )
        else
          ...warnings.take(3).map((w) => _WarningPreviewCard(warning: w)),
        const SizedBox(height: 10),
        _SectionTitle(
          title: 'Assigned to Me',
          actionLabel: 'View all',
          onAction: () => DefaultTabController.of(context),
        ),
        ..._priorityBuckets(tasks).entries.map((entry) {
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return _PrioritySection(
            priority: entry.key,
            tasks: entry.value,
            showZone: isPlumber,
          );
        }),
        if (tasks.isEmpty)
          const _EmptyDarkCard(message: 'No tasks assigned yet'),
      ],
    );
  }

  void _showMaterialRequestSheet(BuildContext context) {
    showBvModalSheet(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Materials',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Material request form — connect to backend when ready.',
              style: TextStyle(color: BVColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkOrderStub(BuildContext context) {
    showBvModalSheet(
      context,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Work order form — coming soon.',
          style: TextStyle(color: BVColors.textSecondary),
        ),
      ),
    );
  }

  void _showBlockerStub(BuildContext context) {
    showBvModalSheet(
      context,
      builder: (ctx) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Flag blocker — form coming soon.',
          style: TextStyle(color: BVColors.textSecondary),
        ),
      ),
    );
  }

  void _showLeakIssueSheet(BuildContext context) {
    showBvModalSheet(
      context,
      builder: (ctx) => const _LeakIssueSheetContent(),
    );
  }
}

class _LeakIssueSheetContent extends StatefulWidget {
  const _LeakIssueSheetContent();

  @override
  State<_LeakIssueSheetContent> createState() => _LeakIssueSheetContentState();
}

class _LeakIssueSheetContentState extends State<_LeakIssueSheetContent> {
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _issueType = 'Leak';
  String _severity = 'Med';

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Leak / Issue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (floor / zone)',
                hintText: 'e.g. Basement / Floor 2',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _issueType,
              decoration: const InputDecoration(labelText: 'Issue type'),
              items: const [
                DropdownMenuItem(value: 'Leak', child: Text('Leak')),
                DropdownMenuItem(value: 'Blockage', child: Text('Blockage')),
                DropdownMenuItem(value: 'Pressure', child: Text('Pressure')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _issueType = v ?? 'Leak'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Med', child: Text('Med')),
                DropdownMenuItem(value: 'High', child: Text('High')),
              ],
              onChanged: (v) => setState(() => _severity = v ?? 'Med'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Submit (demo)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<ElectricianPriority, List<ElectricianTask>> _priorityBuckets(
  List<ElectricianTask> tasks,
) {
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
  final bool showZone;

  const _PrioritySection({
    required this.priority,
    required this.tasks,
    this.showZone = false,
  });

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
          ...tasks.take(3).map(
                (t) => InkWell(
                  onTap: () => context.push(
                    '/${t.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${t.assignment.id}',
                    extra: {'extractedItemId': t.item.id},
                  ),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          showZone
                              ? 'Zone: ${t.item.unitOrArea ?? '—'} · ${t.assignment.status.label}'
                              : '${t.item.unitOrArea ?? 'No location'} · ${t.assignment.status.label}',
                          style: const TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatCard(this.label, this.value, {required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
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
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
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
  final bool danger;
  final bool urgency;
  final VoidCallback? onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    this.danger = false,
    this.urgency = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = danger
        ? BVColors.blocker
        : urgency
            ? BVColors.high
            : BVColors.divider;
    final iconColor = danger
        ? BVColors.blocker
        : urgency
            ? BVColors.high
            : BVColors.primary;
    final textColor = danger
        ? BVColors.blocker
        : urgency
            ? BVColors.high
            : Colors.white;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minHeight: BVSpacing.minTapTarget),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            warning.description,
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
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
