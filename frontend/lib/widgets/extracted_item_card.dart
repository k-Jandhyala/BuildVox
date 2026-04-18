import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/extracted_item_model.dart';
import '../theme.dart';
import 'tier_badge.dart';
import 'urgency_chip.dart';

class ExtractedItemCard extends StatelessWidget {
  final ExtractedItemModel item;
  final VoidCallback? onTap;
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
    final leftColor = _tierColor(item.tier);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left tier color bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: leftColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          TierBadge(tier: item.tier),
                          const SizedBox(width: 6),
                          UrgencyChip(urgency: item.urgency),
                          const Spacer(),
                          if (item.trade.isNotEmpty)
                            _TradeTag(trade: item.trade),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Summary
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

                      // Location
                      if (item.unitOrArea != null &&
                          item.unitOrArea!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: BVColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              item.unitOrArea!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: BVColors.textSecondary),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Footer row
                      Row(
                        children: [
                          _StatusPill(status: item.status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: BVColors.textMuted),
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _tierColor(TierType tier) {
  return switch (tier) {
    TierType.issueOrBlocker => BVColors.danger,
    TierType.materialRequest => BVColors.info,
    TierType.scheduleChange => BVColors.primary,
    TierType.progressUpdate => BVColors.success,
  };
}

class _TradeTag extends StatelessWidget {
  final String trade;
  const _TradeTag({required this.trade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BVColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(999),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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
