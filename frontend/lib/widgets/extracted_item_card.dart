import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/extracted_item_model.dart';
import '../theme.dart';
import 'tier_badge.dart';
import 'urgency_chip.dart';

/// A card that renders a single extracted item.
/// Used across GC, manager, and admin screens.
class ExtractedItemCard extends StatelessWidget {
  final ExtractedItemModel item;
  final VoidCallback? onTap;
  /// Extra trailing action (e.g. "Assign" button for managers).
  final Widget? trailing;

  const ExtractedItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = item.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(item.createdAt!)
        : '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────────────
              Row(
                children: [
                  TierBadge(tier: item.tier),
                  const SizedBox(width: 8),
                  UrgencyChip(urgency: item.urgency),
                  const Spacer(),
                  if (item.trade.isNotEmpty)
                    _TradeTag(trade: item.trade),
                ],
              ),
              const SizedBox(height: 10),

              // ── Summary ───────────────────────────────────────────────────
              Text(
                item.normalizedSummary,
                style: const TextStyle(
                  fontSize: 14,
                  color: BVColors.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Location ──────────────────────────────────────────────────
              if (item.unitOrArea != null && item.unitOrArea!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: BVColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      item.unitOrArea!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BVColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // ── Footer row ────────────────────────────────────────────────
              Row(
                children: [
                  // Status pill
                  _StatusPill(status: item.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: BVColors.textSecondary,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
          ),
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
    if (trade.isEmpty) return const SizedBox.shrink();
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
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ItemStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
