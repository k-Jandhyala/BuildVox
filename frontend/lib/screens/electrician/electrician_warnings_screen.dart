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
    final grouped = <WarningCategory, List<SiteWarning>>{};
    for (final c in WarningCategory.values) {
      grouped[c] = warnings.where((w) => w.category == c).toList();
    }

    const tabs = [
      WarningCategory.safety,
      WarningCategory.inspection,
      WarningCategory.materialShortage,
      WarningCategory.schedule,
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: BVColors.primary,
            tabs: [
              for (final c in tabs)
                Tab(
                  text: c.name.replaceAllMapped(
                    RegExp(r'([A-Z])'),
                    (m) => ' ${m.group(1)}',
                  ).trim(),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final c in tabs)
                  _WarningList(warnings: grouped[c] ?? const [])
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
            Icon(Icons.shield_outlined, color: BVColors.done, size: 34),
            SizedBox(height: 8),
            Text('No active safety warnings', style: TextStyle(color: BVColors.textSecondary)),
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
                          color: Colors.white, fontWeight: FontWeight.w700),
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
