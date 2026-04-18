import 'package:flutter/material.dart';
import '../models/extracted_item_model.dart';

class TierBadge extends StatelessWidget {
  final TierType tier;
  final bool compact;

  const TierBadge({super.key, required this.tier, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: compact ? 10 : 12, color: tier.color),
          const SizedBox(width: 4),
          Text(
            tier.label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: tier.color,
            ),
          ),
        ],
      ),
    );
  }
}
