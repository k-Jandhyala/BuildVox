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
        child: Text('Error: $e', style: const TextStyle(color: BVColors.danger)),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _SummaryCard(
              title: 'Project Pulse',
              subtitle: 'High-level counts from extracted items',
              rows: [
                _Row('Blockers', blockers, BVColors.danger),
                _Row('Material Requests', materials, BVColors.info),
                _Row('Schedule Changes', schedule, BVColors.primary),
                _Row('Progress Updates', progress, BVColors.success),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryCard(
              title: 'Urgency',
              subtitle: 'Where attention is needed most',
              rows: [
                _Row('Critical', critical, BVColors.danger),
                _Row('High', high, BVColors.primary),
              ],
            ),
            const SizedBox(height: 16),
            _SummaryCard(
              title: 'Total Extracted Items',
              subtitle: 'Across all projects in the system',
              rows: [
                _Row('Total', items.length, BVColors.primary),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Row {
  final String label;
  final int value;
  final Color color;
  const _Row(this.label, this.value, this.color);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_Row> rows;
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: BVColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13, color: BVColors.textSecondary, height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: BVColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${r.value}',
                      style: TextStyle(
                        color: r.value > 0 ? r.color : BVColors.textMuted,
                        fontSize: 15, fontWeight: FontWeight.w700,
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
