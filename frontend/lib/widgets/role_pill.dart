import 'package:flutter/material.dart';

import '../theme.dart';

/// Solid role / trade badge for app bars (48dp min height via padding).
class RolePill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const RolePill({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.foregroundColor = BVColors.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
