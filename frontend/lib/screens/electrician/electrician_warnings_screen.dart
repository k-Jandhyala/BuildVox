import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/electrician_models.dart';
import '../../providers/electrician_provider.dart';

class ElectricianWarningsScreen extends ConsumerWidget {
  const ElectricianWarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(electricianWarningsProvider);
    final grouped = <WarningCategory, List<SiteWarning>>{};
    for (final c in WarningCategory.values) {
      grouped[c] = warnings.where((w) => w.category == c).toList();
    }

    return DefaultTabController(
      length: WarningCategory.values.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              for (final c in WarningCategory.values) Tab(text: c.name),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final c in WarningCategory.values)
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
        child: Text('No active site warnings', style: TextStyle(color: Color(0xFF94A3B8))),
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
            color: const Color(0xFF111827),
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
            ],
          ),
        );
      },
    );
  }
}
