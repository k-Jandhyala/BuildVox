import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';

class AdminSummaryScreen extends ConsumerWidget {
  const AdminSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allItemsProvider);
    return itemsAsync.when(
      loading: () => const InlineLoader(message: 'Loading summary…'),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: BVColors.blocker)),
      ),
      data: (items) {
        int countTier(TierType tier) => items.where((i) => i.tier == tier).length;
        int countUrg(UrgencyLevel u) => items.where((i) => i.urgency == u).length;

        final blockers = countTier(TierType.issueOrBlocker);
        final materials = countTier(TierType.materialRequest);
        final schedule = countTier(TierType.scheduleChange);
        final progress = countTier(TierType.progressUpdate);

        final critical = countUrg(UrgencyLevel.critical);
        final high = countUrg(UrgencyLevel.high);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _SummaryCard(
              title: 'Project pulse',
              subtitle: 'High-level counts from extracted items',
              rows: [
                _SummaryRow('Blockers', blockers, BVColors.blocker),
                _SummaryRow('Material requests', materials, BVColors.materialRequest),
                _SummaryRow('Schedule changes', schedule, BVColors.scheduleChange),
                _SummaryRow('Progress updates', progress, BVColors.progressUpdate),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Urgency',
              subtitle: 'Where attention is needed most',
              rows: [
                _SummaryRow('Critical', critical, BVColors.critical),
                _SummaryRow('High', high, BVColors.high),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Total extracted items',
              subtitle: 'Across all projects in the system',
              rows: [
                _SummaryRow('Total', items.length, BVColors.primary),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SummaryRow {
  final String label;
  final int value;
  final Color color;
  const _SummaryRow(this.label, this.value, this.color);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_SummaryRow> rows;
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: BVColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: BVColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: r.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: BVColors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${r.value}',
                      style: TextStyle(
                        color: r.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

