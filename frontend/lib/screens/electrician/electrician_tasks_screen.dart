import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/electrician_models.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/electrician_provider.dart';

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
    final all = ref.watch(electricianTasksProvider).valueOrNull ?? const [];
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
        const Text(
          'Task Queue',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Due today'),
              selected: _dueTodayOnly,
              onSelected: (v) => setState(() => _dueTodayOnly = v),
            ),
            FilterChip(
              label: const Text('Blockers'),
              selected: _blockersOnly,
              onSelected: (v) => setState(() => _blockersOnly = v),
            ),
            FilterChip(
              label: const Text('Material related'),
              selected: _materialOnly,
              onSelected: (v) => setState(() => _materialOnly = v),
            ),
            PopupMenuButton<ItemStatus?>(
              onSelected: (v) => setState(() => _statusFilter = v),
              itemBuilder: (c) => [
                const PopupMenuItem<ItemStatus?>(value: null, child: Text('All Status')),
                for (final s in ItemStatus.values)
                  PopupMenuItem<ItemStatus?>(value: s, child: Text(s.label)),
              ],
              child: Chip(
                label: Text(_statusFilter == null
                    ? 'Status: All'
                    : 'Status: ${_statusFilter!.label}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const _EmptyCard(text: 'No tasks at this jobsite with current filters.')
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

class _TaskCard extends StatelessWidget {
  final ElectricianTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = task.assignment.dueDate;
    return InkWell(
      onTap: () => context.push('/${task.item.trade == 'plumbing' ? 'plumber' : 'electrician'}/task/${task.assignment.id}',
          extra: {'extractedItemId': task.item.id}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
              task.item.normalizedSummary,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _meta(task.assignment.status.label),
                _meta(task.item.urgency.label),
                _meta(task.item.unitOrArea ?? 'No location'),
                _meta('Assigned by ${task.assignedByLabel}'),
                _meta(due == null ? 'No due date' : DateFormat('MMM d').format(due)),
              ],
            ),
          ],
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
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8))),
    );
  }
}
