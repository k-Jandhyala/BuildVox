import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';

class BlockersScreen extends ConsumerWidget {
  const BlockersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockersAsync = ref.watch(gcBlockersProvider);

    return blockersAsync.when(
      loading: () => const InlineLoader(message: 'Loading blockers…'),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'No active blockers',
            subtitle: 'All clear on the project.\nBlockers reported by workers will appear here.',
          );
        }

        // Sort: critical first, then by date
        final sorted = [...items];
        sorted.sort((a, b) {
          final urgencyOrder = {
            UrgencyLevel.critical: 0,
            UrgencyLevel.high: 1,
            UrgencyLevel.medium: 2,
            UrgencyLevel.low: 3,
          };
          final ua = urgencyOrder[a.urgency] ?? 4;
          final ub = urgencyOrder[b.urgency] ?? 4;
          if (ua != ub) return ua.compareTo(ub);
          return (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0));
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(gcBlockersProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SummaryBanner(count: items.length),
              ...sorted.map((item) => ExtractedItemCard(item: item)),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int count;
  const _SummaryBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BVColors.blocker.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BVColors.blocker.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: BVColors.blocker, size: 18),
          const SizedBox(width: 8),
          Text(
            '$count active blocker${count != 1 ? 's' : ''} — attention required',
            style: const TextStyle(
              fontSize: 13,
              color: BVColors.blocker,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
