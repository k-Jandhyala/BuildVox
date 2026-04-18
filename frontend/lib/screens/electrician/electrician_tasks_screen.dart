import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/mock_data.dart';
import '../../models/electrician_models.dart';
import '../../models/extracted_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

class ElectricianTasksScreen extends ConsumerStatefulWidget {
  const ElectricianTasksScreen({super.key});

  @override
  ConsumerState<ElectricianTasksScreen> createState() =>
      _ElectricianTasksScreenState();
}

class _ElectricianTasksScreenState extends ConsumerState<ElectricianTasksScreen> {
  ItemStatus? _statusFilter;
  bool _dueTodayOnly = false;
  bool _blockersOnly = false;
  bool _materialOnly = false;

  @override
  Widget build(BuildContext context) {
    final isPlumber = ref.watch(currentUserProvider)?.trade == TradeType.plumbing;
    final all = mockElectricianTasksForCurrentTradeWorker(isPlumber: isPlumber);
    final now = DateTime.now();
    final filtered = all.where((t) {
      if (_statusFilter != null && t.assignment.status != _statusFilter) return false;
      if (_dueTodayOnly) {
        final due = t.assignment.dueDate;
        if (due == null ||
            due.year != now.year ||
            due.month != now.month ||
            due.day != now.day) {
          return false;
        }
      }
      if (_blockersOnly && t.item.tier != TierType.issueOrBlocker) return false;
      if (_materialOnly && t.item.tier != TierType.materialRequest) return false;
      return true;
    }).toList();

    final grouped = <ElectricianPriority, List<ElectricianTask>>{
      ElectricianPriority.critical:
          filtered.where((t) => t.priority == ElectricianPriority.critical).toList(),
      ElectricianPriority.high:
          filtered.where((t) => t.priority == ElectricianPriority.high).toList(),
      ElectricianPriority.medium:
          filtered.where((t) => t.priority == ElectricianPriority.medium).toList(),
      ElectricianPriority.low:
          filtered.where((t) => t.priority == ElectricianPriority.low).toList(),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'My Tasks (${filtered.length})',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: !_dueTodayOnly && !_blockersOnly && !_materialOnly && _statusFilter == null,
              onSelected: (_) => setState(() {
                _dueTodayOnly = false;
                _blockersOnly = false;
                _materialOnly = false;
                _statusFilter = null;
              }),
            ),
            FilterChip(
              label: const Text('Due Today'),
              selected: _dueTodayOnly,
              onSelected: (v) => setState(() => _dueTodayOnly = v),
            ),
            FilterChip(
              label: const Text('Blockers'),
              selected: _blockersOnly,
              onSelected: (v) => setState(() => _blockersOnly = v),
            ),
            FilterChip(
              label: const Text('Material Related'),
              selected: _materialOnly,
              onSelected: (v) => setState(() => _materialOnly = v),
            ),
            ChoiceChip(
              label: const Text('In Progress'),
              selected: _statusFilter == ItemStatus.inProgress,
              onSelected: (_) => setState(() => _statusFilter = ItemStatus.inProgress),
            ),
            ChoiceChip(
              label: const Text('Completed'),
              selected: _statusFilter == ItemStatus.done,
              onSelected: (_) => setState(() => _statusFilter = ItemStatus.done),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const _EmptyCard(text: 'No tasks match this filter')
        else
          ...grouped.entries.map((entry) {
            if (entry.value.isEmpty) return const SizedBox.shrink();
            return _TaskGroup(priority: entry.key, tasks: entry.value);
          }),
      ],
    );
  }
}

class _TaskGroup extends StatelessWidget {
  final ElectricianPriority priority;
  final List<ElectricianTask> tasks;
  const _TaskGroup({required this.priority, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final title = priority.name[0].toUpperCase() + priority.name.substring(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${tasks.length})',
              style: const TextStyle(
                  color: Color(0xFF93C5FD), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...tasks.map((task) => _TaskCard(task: task)),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final ElectricianTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = task.assignment.dueDate;
    final isPlumber = ref.watch(currentUserProvider)?.trade == TradeType.plumbing;
    return InkWell(
      onTap: () => context.push('/${task.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${task.assignment.id}',
          extra: {'extractedItemId': task.item.id}),
      child: Dismissible(
        key: ValueKey(task.assignment.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: BVColors.done.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _SwipeAction(label: 'Complete', color: BVColors.done),
              SizedBox(width: 10),
              _SwipeAction(label: 'Flag', color: BVColors.blocker),
            ],
          ),
        ),
        confirmDismiss: (_) async => false,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BVColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BVColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: task.item.urgency.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.item.normalizedSummary,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _meta(task.assignment.status.label),
                        _meta(task.item.trade),
                        if (isPlumber)
                          _meta('Zone: ${task.item.unitOrArea ?? '—'}')
                        else if (task.item.unitOrArea != null)
                          _meta(task.item.unitOrArea!),
                        _meta(due == null
                            ? 'No due date'
                            : DateFormat('MMM d, h:mm a').format(due)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BVColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(value, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.construction_rounded, color: BVColors.textSecondary, size: 36),
          SizedBox(height: 8),
          Text('No tasks match this filter', style: TextStyle(color: BVColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final String label;
  final Color color;
  const _SwipeAction({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
