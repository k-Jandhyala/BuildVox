import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';

// Filter state provider
final _feedFilterProvider = StateProvider<TierType?>((ref) => null);

class ProjectFeedScreen extends ConsumerWidget {
  const ProjectFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(gcProjectFeedProvider);
    final filter = ref.watch(_feedFilterProvider);

    return Column(
      children: [
        // ── Filter chips ─────────────────────────────────────────────────
        _FilterBar(
          selected: filter,
          onSelected: (t) =>
              ref.read(_feedFilterProvider.notifier).state = t,
        ),

        // ── Feed list ────────────────────────────────────────────────────
        Expanded(
          child: feedAsync.when(
            loading: () =>
                const InlineLoader(message: 'Loading project feed…'),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: BVColors.blocker)),
            ),
            data: (items) {
              final filtered = filter == null
                  ? items
                  : items.where((i) => i.tier == filter).toList();

              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.feed_outlined,
                  title: filter == null
                      ? 'No items in the feed yet'
                      : 'No ${filter.label} items',
                  subtitle: 'Items will appear as workers submit voice memos.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(gcProjectFeedProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      ExtractedItemCard(item: filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TierType? selected;
  final void Function(TierType?) onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BVColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: selected == null,
              color: BVColors.primary,
              onTap: () => onSelected(null),
            ),
            const SizedBox(width: 6),
            ...TierType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: t.label,
                    isSelected: selected == t,
                    color: t.color,
                    onTap: () => onSelected(selected == t ? null : t),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : BVColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : BVColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : BVColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
