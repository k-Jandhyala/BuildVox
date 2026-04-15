import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../models/task_assignment_model.dart';
import '../../services/firestore_service.dart';
import '../../services/functions_service.dart';
import '../../theme.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/urgency_chip.dart';
import '../../widgets/loading_overlay.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  final String extractedItemId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.extractedItemId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  TaskAssignmentModel? _task;
  ExtractedItemModel? _item;
  bool _loading = true;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        FirestoreService.getExtractedItem(widget.extractedItemId),
      ]);
      // Also watch task via stream for live status updates
      setState(() {
        _item = results[0] as ExtractedItemModel?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(ItemStatus newStatus) async {
    setState(() => _updating = true);
    try {
      await FunctionsService.updateTaskStatus(
        taskId: widget.taskId,
        status: _statusToString(newStatus),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.label}'),
          backgroundColor: BVColors.done,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: BVColors.blocker,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  String _statusToString(ItemStatus s) {
    switch (s) {
      case ItemStatus.pending:
        return 'pending';
      case ItemStatus.acknowledged:
        return 'acknowledged';
      case ItemStatus.inProgress:
        return 'in_progress';
      case ItemStatus.done:
        return 'done';
      case ItemStatus.cancelled:
        return 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: Stack(
        children: [
          if (_loading)
            const InlineLoader(message: 'Loading task…')
          else if (_error != null)
            Center(
              child: Text('Error: $_error',
                  style: const TextStyle(color: BVColors.blocker)),
            )
          else if (_item == null)
            const Center(child: Text('Task not found'))
          else
            _buildContent(),
          if (_updating) const LoadingOverlay(message: 'Updating status…'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final item = _item!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tier + urgency ──────────────────────────────────────────────
          Row(
            children: [
              TierBadge(tier: item.tier),
              const SizedBox(width: 8),
              UrgencyChip(urgency: item.urgency),
              const Spacer(),
              _TradeTag(trade: item.trade),
            ],
          ),
          const SizedBox(height: 16),

          // ── Summary ─────────────────────────────────────────────────────
          _Section(
            label: 'Summary',
            child: Text(
              item.normalizedSummary,
              style: const TextStyle(
                  fontSize: 15, color: BVColors.onSurface, height: 1.5),
            ),
          ),

          // ── Source text ─────────────────────────────────────────────────
          _Section(
            label: 'Original Quote',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BVColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BVColors.divider),
              ),
              child: Text(
                '"${item.sourceText}"',
                style: const TextStyle(
                  fontSize: 13,
                  color: BVColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
          ),

          // ── Suggested next step ─────────────────────────────────────────
          if (item.suggestedNextStep.isNotEmpty)
            _Section(
              label: 'Suggested Next Step',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BVColors.primaryLight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: BVColors.primaryLight.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: BVColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.suggestedNextStep,
                        style: const TextStyle(
                            fontSize: 13, color: BVColors.onSurface, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Meta info ───────────────────────────────────────────────────
          _Section(
            label: 'Details',
            child: Column(
              children: [
                if (item.unitOrArea != null)
                  _MetaRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: item.unitOrArea!),
                _MetaRow(
                    icon: Icons.build_outlined,
                    label: 'Trade',
                    value: item.trade[0].toUpperCase() +
                        item.trade.substring(1)),
                if (item.createdAt != null)
                  _MetaRow(
                    icon: Icons.access_time,
                    label: 'Reported',
                    value:
                        DateFormat('MMM d, yyyy h:mm a').format(item.createdAt!),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Status update ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'UPDATE STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BVColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _StatusButton(
            label: 'Mark Acknowledged',
            status: ItemStatus.acknowledged,
            color: BVColors.acknowledged,
            icon: Icons.thumb_up_outlined,
            onTap: () => _updateStatus(ItemStatus.acknowledged),
          ),
          const SizedBox(height: 8),
          _StatusButton(
            label: 'Mark In Progress',
            status: ItemStatus.inProgress,
            color: BVColors.inProgress,
            icon: Icons.timelapse_rounded,
            onTap: () => _updateStatus(ItemStatus.inProgress),
          ),
          const SizedBox(height: 8),
          _StatusButton(
            label: 'Mark Done',
            status: ItemStatus.done,
            color: BVColors.done,
            icon: Icons.check_circle_outline_rounded,
            onTap: () => _updateStatus(ItemStatus.done),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: BVColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: BVColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 13,
                color: BVColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: BVColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final ItemStatus status;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.status,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.centerLeft,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

class _TradeTag extends StatelessWidget {
  final String trade;
  const _TradeTag({required this.trade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BVColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BVColors.divider),
      ),
      child: Text(
        trade[0].toUpperCase() + trade.substring(1),
        style: const TextStyle(
            fontSize: 11,
            color: BVColors.textSecondary,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
