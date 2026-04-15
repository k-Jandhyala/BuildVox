import 'package:flutter/material.dart';
import '../models/extracted_item_model.dart';

class UrgencyChip extends StatelessWidget {
  final UrgencyLevel urgency;

  const UrgencyChip({super.key, required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgency.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        urgency.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: urgency.color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
