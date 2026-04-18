import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/electrician_models.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';

class ElectricianWarningsScreen extends ConsumerWidget {
  /// Plumber shell passes `true` to insert the Leak Alerts tab.
  final bool showLeakAlertsTab;

  const ElectricianWarningsScreen({super.key, this.showLeakAlertsTab = false});

  static String _label(WarningCategory c) {
    switch (c) {
      case WarningCategory.safety:
        return 'Safety';
      case WarningCategory.inspection:
        return 'Inspection';
      case WarningCategory.materialShortage:
        return 'Material Shortage';
      case WarningCategory.schedule:
        return 'Schedule';
      case WarningCategory.access:
        return 'Access';
      case WarningCategory.weather:
        return 'Weather';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(electricianWarningsProvider);
    final grouped = <WarningCategory, List<SiteWarning>>{};
    for (final c in WarningCategory.values) {
      grouped[c] = warnings.where((w) => w.category == c).toList();
    }

    const order = [
      WarningCategory.safety,
      WarningCategory.inspection,
      WarningCategory.materialShortage,
      WarningCategory.schedule,
    ];

    if (!showLeakAlertsTab) {
      return DefaultTabController(
        length: order.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              indicatorColor: BVColors.primary,
              labelColor: BVColors.primary,
              unselectedLabelColor: BVColors.textSecondary,
              tabs: [for (final c in order) Tab(text: _label(c))],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final c in order)
                    _WarningList(
                      warnings: grouped[c] ?? const [],
                      emptyHint: 'No ${_label(c).toLowerCase()} warnings',
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Plumber: Leak Alerts between Inspection and Material Shortage
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: BVColors.primary,
            labelColor: BVColors.primary,
            unselectedLabelColor: BVColors.textSecondary,
            tabs: const [
              Tab(text: 'Safety'),
              Tab(text: 'Inspection'),
              Tab(text: 'Leak Alerts'),
              Tab(text: 'Material Shortage'),
              Tab(text: 'Schedule'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _WarningList(
                  warnings: grouped[WarningCategory.safety] ?? const [],
                  emptyHint: 'No safety warnings',
                ),
                _WarningList(
                  warnings: grouped[WarningCategory.inspection] ?? const [],
                  emptyHint: 'No inspection warnings',
                ),
                const _LeakAlertsPlaceholder(),
                _WarningList(
                  warnings: grouped[WarningCategory.materialShortage] ?? const [],
                  emptyHint: 'No material shortage warnings',
                ),
                _WarningList(
                  warnings: grouped[WarningCategory.schedule] ?? const [],
                  emptyHint: 'No schedule warnings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeakAlertsPlaceholder extends StatelessWidget {
  const _LeakAlertsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop_outlined, color: BVColors.accent, size: 48),
          SizedBox(height: 12),
          Text(
            'No active leak alerts',
            style: TextStyle(color: BVColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _WarningList extends StatelessWidget {
  final List<SiteWarning> warnings;
  final String emptyHint;

  const _WarningList({
    required this.warnings,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, color: BVColors.done, size: 34),
            const SizedBox(height: 8),
            Text(emptyHint, style: const TextStyle(color: BVColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: warnings.length,
      itemBuilder: (context, i) {
        final w = warnings[i];
        final color = warningSeverityColor(w.severity);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BVColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(w.description, style: const TextStyle(color: Color(0xFFCBD5E1))),
              const SizedBox(height: 8),
              const Row(
                children: [
                  _ActionButton(label: 'Acknowledge'),
                  SizedBox(width: 8),
                  _ActionButton(label: 'View Details'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  const _ActionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {},
        child: Text(label),
      ),
    );
  }
}
