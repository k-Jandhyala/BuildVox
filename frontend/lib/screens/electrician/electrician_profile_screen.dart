import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/electrician_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';

class ElectricianProfileScreen extends ConsumerWidget {
  const ElectricianProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final queue = ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final sites = ref.watch(electricianJobsitesProvider).valueOrNull ?? const [];
    final pending = queue.where((q) => q.status != QueueStatus.completed).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _InfoCard(label: 'Name', value: user?.name ?? '-'),
        _InfoCard(label: 'Trade', value: user?.trade?.displayName ?? '-'),
        _InfoCard(label: 'Company', value: user?.companyId ?? '-'),
        _InfoCard(label: 'Assigned Jobsites', value: '${sites.length}'),
        _InfoCard(label: 'Queue Pending', value: '$pending'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
            if (!context.mounted) return;
            context.go('/login');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
