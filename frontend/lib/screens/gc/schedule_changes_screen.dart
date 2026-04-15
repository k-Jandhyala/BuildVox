import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';

class ScheduleChangesScreen extends ConsumerWidget {
  const ScheduleChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changesAsync = ref.watch(gcScheduleChangesProvider);

    return changesAsync.when(
      loading: () => const InlineLoader(message: 'Loading schedule changes…'),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.schedule_rounded,
            title: 'No schedule changes',
            subtitle: 'Schedule changes reported by trades\nwill appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(gcScheduleChangesProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _InfoBanner(count: items.length),
              ...items.map((item) => ExtractedItemCard(
                    item: item,
                    trailing: item.downstreamTrades.isNotEmpty
                        ? _DownstreamTag(
                            trades: item.downstreamTrades,
                          )
                        : null,
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final int count;
  const _InfoBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BVColors.scheduleChange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: BVColors.scheduleChange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              color: BVColors.scheduleChange, size: 18),
          const SizedBox(width: 8),
          Text(
            '$count schedule change${count != 1 ? 's' : ''} — downstream notified',
            style: const TextStyle(
              fontSize: 13,
              color: BVColors.scheduleChange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownstreamTag extends StatelessWidget {
  final List<String> trades;
  const _DownstreamTag({required this.trades});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BVColors.scheduleChange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '↓ ${trades.take(2).join(', ')}${trades.length > 2 ? '+${trades.length - 2}' : ''}',
        style: const TextStyle(
          fontSize: 10,
          color: BVColors.scheduleChange,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
