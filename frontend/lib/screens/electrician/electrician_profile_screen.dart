import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/electrician_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';

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
        CircleAvatar(
          radius: 36,
          backgroundColor: BVColors.surface,
          child: Text(
            (user?.name ?? 'U').split(' ').take(2).map((e) => e[0]).join(),
            style: const TextStyle(
              color: BVColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _InfoCard(label: 'Name', value: user?.name ?? '-', icon: Icons.person_outline_rounded),
        _InfoCard(label: 'Trade', value: user?.trade?.displayName ?? '-', icon: Icons.handyman_rounded),
        _InfoCard(label: 'Company', value: user?.companyId ?? '-', icon: Icons.business_outlined),
        _InfoCard(label: 'Assigned Jobsites', value: '${sites.length}', icon: Icons.location_on_outlined),
        _InfoCard(
          label: 'Queue Pending',
          value: '$pending',
          icon: Icons.schedule_rounded,
          onTap: () => context.go('/electrician'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
            if (!context.mounted) return;
            context.go('/login');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: BVColors.blocker,
            side: const BorderSide(color: BVColors.blocker),
          ),
          icon: const Icon(Icons.logout_rounded, color: BVColors.blocker),
          label: const Text('Sign Out', style: TextStyle(color: BVColors.blocker)),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('v1.0.0', style: TextStyle(color: BVColors.textSecondary)),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BVColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: BVColors.primary),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: BVColors.textSecondary)),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
