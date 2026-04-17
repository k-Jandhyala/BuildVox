import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/electrician_models.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';

class ElectricianWarningsScreen extends ConsumerWidget {
  const ElectricianWarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(electricianWarningsProvider);

    const tabs = [
      null, // "All"
      WarningCategory.safety,
      WarningCategory.inspection,
      WarningCategory.materialShortage,
      WarningCategory.schedule,
    ];

    const tabLabels = [
      'All',
      'Safety',
      'Inspection',
      'Material Shortage',
      'Schedule',
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final label in tabLabels) Tab(text: label),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final cat in tabs)
                  _WarningList(
                    warnings: cat == null
                        ? warnings
                        : warnings
                            .where((w) => w.category == cat)
                            .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningList extends StatelessWidget {
  final List<SiteWarning> warnings;
  const _WarningList({required this.warnings});

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: BVColors.success, size: 56),
            SizedBox(height: 12),
            Text(
              'All Clear',
              style: TextStyle(
                color: BVColors.success,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'No active warnings for this jobsite',
              style:
                  TextStyle(color: BVColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: warnings.length,
      itemBuilder: (context, i) => _WarningCard(warning: warnings[i]),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final SiteWarning warning;
  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = warningSeverityColor(warning.severity);
    final severityLabel = warning.severity.name[0].toUpperCase() +
        warning.severity.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left severity bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + severity pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            warning.title,
                            style: const TextStyle(
                              color: BVColors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            severityLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      warning.description,
                      style: const TextStyle(
                        color: BVColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionBtn(
                            label: 'Acknowledge',
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionBtn(
                            label: 'View Details',
                            color: BVColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  const _ActionBtn({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
