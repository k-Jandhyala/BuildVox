import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/extracted_items_provider.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';

final _feedFilterProvider = StateProvider<TierType?>((ref) => null);

class ProjectFeedScreen extends ConsumerWidget {
  const ProjectFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(gcProjectFeedProvider);
    final filter = ref.watch(_feedFilterProvider);

    return Column(
      children: [
        _FilterBar(
          selected: filter,
          onSelected: (t) => ref.read(_feedFilterProvider.notifier).state = t,
        ),
        Expanded(
          child: feedAsync.when(
            loading: () => const InlineLoader(message: 'Loading project feed…'),
            error: (e, _) => Center(
              child: Text('Error: $e', style: const TextStyle(color: BVColors.danger)),
            ),
            data: (items) {
              final filtered = filter == null
                  ? items
                  : items.where((i) => i.tier == filter).toList();

              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.feed_outlined,
                  title: filter == null ? 'No items in the feed yet' : 'No ${filter.label} items',
                  subtitle: 'Items will appear as workers submit voice memos.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(gcProjectFeedProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => ExtractedItemCard(item: filtered[i]),
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
      color: BVColors.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Pill(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelected(null),
            ),
            const SizedBox(width: 8),
            ...TierType.values.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Pill(
                    label: t.label,
                    selected: selected == t,
                    onTap: () => onSelected(selected == t ? null : t),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BVColors.primary : BVColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? BVColors.onPrimary : BVColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
