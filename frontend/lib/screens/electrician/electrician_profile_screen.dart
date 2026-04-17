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
    final queue =
        ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final sites =
        ref.watch(electricianJobsitesProvider).valueOrNull ?? const [];
    final pending =
        queue.where((q) => q.status != QueueStatus.completed).length;

    final initials = (user?.name ?? 'U')
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();

    final companyDisplay = _formatCompany(user?.companyId ?? '');
    final tradeDisplay = user?.trade?.displayName ?? '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      children: [
        // ── Avatar ──────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: BVColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: BVColors.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.name ?? '—',
                style: const TextStyle(
                  color: BVColors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tradeDisplay,
                style: const TextStyle(
                    color: BVColors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Work Info group ──────────────────────────────────────────────
        const _GroupLabel(label: 'Work Info'),
        const SizedBox(height: 8),
        _InfoGroup(
          rows: [
            _InfoRow(label: 'Company', value: companyDisplay),
            _InfoRow(
                label: 'Assigned Jobsites',
                value: '${sites.length}'),
            _InfoRow(
              label: 'Pending Submissions',
              value: '$pending',
              valueColor:
                  pending > 0 ? BVColors.primary : BVColors.onSurface,
              onTap: () => context.go('/electrician'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Settings group ───────────────────────────────────────────────
        const _GroupLabel(label: 'Settings'),
        const SizedBox(height: 8),
        _InfoGroup(
          rows: [
            _InfoRow(
              label: 'Notifications',
              value: '',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: BVColors.textMuted, size: 18),
            ),
            _InfoRow(
              label: 'Help & Support',
              value: '',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: BVColors.textMuted, size: 18),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // ── Sign out — danger text button, understated ───────────────────
        TextButton(
          onPressed: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
            if (!context.mounted) return;
            context.go('/login');
          },
          style: TextButton.styleFrom(
            foregroundColor: BVColors.danger,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text(
            'Sign Out',
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 16),
        const Center(
          child: Text(
            'v1.0.0',
            style: TextStyle(color: BVColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _formatCompany(String raw) {
  if (raw.isEmpty) return '—';
  final s =
      raw.replaceFirst(RegExp(r'^company_', caseSensitive: false), '');
  return s
      .replaceAll(RegExp(r'[_\-]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: BVColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: BVColors.divider,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: BVColors.textSecondary, fontSize: 14),
            ),
            const Spacer(),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? BVColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
