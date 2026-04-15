import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extracted_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/extracted_items_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/functions_service.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(managerItemsProvider);

    return itemsAsync.when(
      loading: () =>
          const InlineLoader(message: 'Loading incoming requests…'),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No incoming requests',
            subtitle:
                'Work items routed to your company\nwill appear here.',
          );
        }

        // Separate unassigned (pending) from others
        final unassigned =
            items.where((i) => i.status == ItemStatus.pending).toList();
        final inProgress =
            items.where((i) => i.status != ItemStatus.pending).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(managerItemsProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (unassigned.isNotEmpty) ...[
                _SectionHeader(
                    label: 'Needs Assignment (${unassigned.length})',
                    color: BVColors.blocker),
                ...unassigned.map((item) => ExtractedItemCard(
                      item: item,
                      trailing: _AssignButton(item: item),
                    )),
              ],
              if (inProgress.isNotEmpty) ...[
                _SectionHeader(
                    label: 'In Progress (${inProgress.length})',
                    color: BVColors.textSecondary),
                ...inProgress.map((item) => ExtractedItemCard(item: item)),
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

class _AssignButton extends ConsumerStatefulWidget {
  final ExtractedItemModel item;
  const _AssignButton({required this.item});

  @override
  ConsumerState<_AssignButton> createState() => _AssignButtonState();
}

class _AssignButtonState extends ConsumerState<_AssignButton> {
  bool _assigning = false;

  Future<void> _showAssignDialog() async {
    final user = ref.read(currentUserProvider);
    if (user?.companyId == null) return;

    // Load workers for this company
    List<UserModel> workers = [];
    try {
      workers =
          await FirestoreService.getWorkersForCompany(user!.companyId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load workers: $e'),
              backgroundColor: BVColors.blocker),
        );
      }
      return;
    }

    if (!mounted) return;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No workers found in your company.'),
            backgroundColor: BVColors.textSecondary),
      );
      return;
    }

    // Show worker picker dialog
    final selectedWorker = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => _WorkerPickerDialog(workers: workers),
    );

    if (selectedWorker == null || !mounted) return;

    setState(() => _assigning = true);
    try {
      await FunctionsService.assignTask(
        extractedItemId: widget.item.id,
        assignedToUserId: selectedWorker.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task assigned to ${selectedWorker.name}'),
            backgroundColor: BVColors.done,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Assignment failed: $e'),
              backgroundColor: BVColors.blocker),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _assigning
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: BVColors.primary),
          )
        : TextButton(
            onPressed: _showAssignDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Assign',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BVColors.primary),
            ),
          );
  }
}

class _WorkerPickerDialog extends StatelessWidget {
  final List<UserModel> workers;
  const _WorkerPickerDialog({required this.workers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign to Worker'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: workers.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final w = workers[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: BVColors.primary.withOpacity(0.15),
                child: Text(w.initials,
                    style: const TextStyle(
                        color: BVColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              title: Text(w.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: w.trade != null
                  ? Text(w.trade!.displayName,
                      style: const TextStyle(
                          fontSize: 12, color: BVColors.textSecondary))
                  : null,
              onTap: () => Navigator.of(ctx).pop(w),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
