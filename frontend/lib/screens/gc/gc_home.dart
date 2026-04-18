import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/account_menu_button.dart';
import '../../widgets/bv_modal_sheet.dart';
import '../../widgets/role_pill.dart';
import '../../widgets/skeleton_shimmer.dart';
import '../electrician/electrician_record_screen.dart';
import '../electrician/electrician_warnings_screen.dart';
import '../worker/trade_field_note_config.dart';

/// General Contractor shell — site-wide oversight (no center hump).
class GcHome extends ConsumerStatefulWidget {
  const GcHome({super.key});

  @override
  ConsumerState<GcHome> createState() => _GcHomeState();
}

class _GcHomeState extends ConsumerState<GcHome> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(gcShellTabProvider);
    final jobsites = ref.watch(electricianJobsitesProvider);
    final selectedSiteId = ref.watch(selectedElectricianSiteProvider).valueOrNull;

    return Scaffold(
      backgroundColor: BVColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('BuildVox · '),
            RolePill(
              label: 'GC',
              backgroundColor: BVRoleColors.gc,
              foregroundColor: BVColors.onPrimary,
            ),
          ],
        ),
        actions: const [AccountMenuButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: jobsites.when(
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (e, _) => Text('Jobsites: $e', style: const TextStyle(color: BVColors.blocker)),
              data: (sites) {
                if (sites.isEmpty) {
                  return const Text('No jobsites assigned', style: TextStyle(color: BVColors.textSecondary));
                }
                final selected = sites.any((s) => s.id == selectedSiteId) ? selectedSiteId : sites.first.id;
                if (selected != selectedSiteId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedElectricianSiteProvider.notifier).setSite(selected!);
                  });
                }
                final current = sites.firstWhere((s) => s.id == selected);
                return InkWell(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: BVColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        children: sites
                            .map((s) => ListTile(
                                  title: Text(s.name),
                                  subtitle: Text(s.address),
                                  onTap: () {
                                    ref.read(selectedElectricianSiteProvider.notifier).setSite(s.id);
                                    Navigator.pop(ctx);
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BVColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BVRoleColors.gc),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: BVRoleColors.gc),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${current.name} · ${current.address}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: tab,
        children: const [
          _GcOverviewBody(),
          _GcTradesBody(),
          _GcUpdatesBody(),
          _GcWarningsBody(),
          _GcProfileBody(),
        ],
      ),
      bottomNavigationBar: _GcBottomNav(
        selected: tab,
        onSelect: (i) {
          ref.read(gcShellTabProvider.notifier).state = i;
          if (i == 2) ref.read(recordScreenAutofocusTriggerProvider.notifier).state++;
        },
      ),
    );
  }
}

class _GcBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _GcBottomNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Color c(int i) => selected == i ? BVColors.primary : BVColors.textSecondary;
    Widget item(IconData icon, String label, int i) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(i),
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: c(i), size: 24),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: c(i), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: BVColors.surface,
          border: Border(top: BorderSide(color: BVColors.divider)),
        ),
        child: Row(
          children: [
            item(Icons.dashboard_outlined, 'Overview', 0),
            item(Icons.engineering_outlined, 'Trades', 1),
            item(Icons.edit_note_rounded, 'Updates', 2),
            item(Icons.warning_amber_rounded, 'Warnings', 3),
            item(Icons.person_outline_rounded, 'Profile', 4),
          ],
        ),
      ),
    );
  }
}

class _GcOverviewBody extends ConsumerWidget {
  const _GcOverviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(selectedSiteSummaryProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: BVSpacing.screenHorizontal, vertical: BVSpacing.sectionGap),
      children: [
        const Text(
          'Site overview',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: BVSpacing.sectionGap),
        if (summary != null)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _GcStat('Total Active Tasks', '12', Icons.list_alt_rounded, BVColors.accent),
              _GcStat('Open Blockers', '${summary.blockerCount}', Icons.block_rounded, BVColors.blocker),
              _GcStat('Pending Materials', '${summary.materialPendingCount}', Icons.inventory_2_rounded, BVColors.primary),
              _GcStat('Workers On-Site', '8', Icons.groups_2_outlined, BVColors.done),
              _GcStat('Inspections Due', '3', Icons.assignment_turned_in_outlined, BVColors.managerPurple),
              _GcStat('Safety Warnings', '${ref.watch(electricianWarningsProvider).length}', Icons.shield_outlined, BVColors.blocker),
            ],
          )
        else
          const SkeletonShimmer(height: 280),
        const SizedBox(height: BVSpacing.sectionGap),
        const Text(
          'Site activity',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _feedFilterRow(context),
        const SizedBox(height: 8),
        const _GcFeedEmpty(),
        const SizedBox(height: BVSpacing.sectionGap),
        const Text('Quick actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _GcQuick(Icons.block_rounded, 'Review Blockers', BVColors.blocker, () {}),
            _GcQuick(Icons.inventory_2_outlined, 'Approve Materials', BVColors.primary, () {}),
            _GcQuick(Icons.campaign_outlined, 'Post Site Notice', BVColors.accent, () {
              ref.read(gcShellTabProvider.notifier).state = 2;
              ref.read(recordScreenAutofocusTriggerProvider.notifier).state++;
            }),
            _GcQuick(Icons.map_outlined, 'View Site Plan', BVColors.textSecondary, () {}),
          ],
        ),
      ],
    );
  }

  Widget _feedFilterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All Trades', 'Electrical', 'Plumbing']
            .map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e),
                    selected: e == 'All Trades',
                    onSelected: (_) {},
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _GcStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _GcStat(this.label, this.value, this.icon, this.accent);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BVColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const Spacer(),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: BVColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _GcFeedEmpty extends StatelessWidget {
  const _GcFeedEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: const Text(
        'No site updates yet today',
        textAlign: TextAlign.center,
        style: TextStyle(color: BVColors.textSecondary),
      ),
    );
  }
}

class _GcQuick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _GcQuick(this.icon, this.label, this.accent, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: BVSpacing.minTapTarget),
          decoration: BoxDecoration(
            color: BVColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BVColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GcTradesBody extends ConsumerWidget {
  const _GcTradesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(BVSpacing.screenHorizontal),
      children: const [
        Text('Trades on site', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Text(
          'Drill into each trade’s workload. (Demo list — connect to live data later.)',
          style: TextStyle(color: BVColors.textSecondary),
        ),
        SizedBox(height: 16),
        _TradeRow(name: 'Electrical', workers: 4, tasks: 9, blockers: 1),
        _TradeRow(name: 'Plumbing', workers: 3, tasks: 6, blockers: 0),
      ],
    );
  }
}

class _TradeRow extends StatelessWidget {
  final String name;
  final int workers;
  final int tasks;
  final int blockers;

  const _TradeRow({
    required this.name,
    required this.workers,
    required this.tasks,
    required this.blockers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                Text('$workers workers · $tasks open tasks', style: const TextStyle(color: BVColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (blockers > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: BVColors.blocker.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$blockers', style: const TextStyle(color: BVColors.blocker, fontWeight: FontWeight.w700)),
            ),
          const Icon(Icons.chevron_right_rounded, color: BVColors.primary),
        ],
      ),
    );
  }
}

class _GcUpdatesBody extends StatelessWidget {
  const _GcUpdatesBody();

  @override
  Widget build(BuildContext context) {
    return const ElectricianRecordScreen(
      layout: TradeFieldNoteLayout.gc,
      host: FieldNoteHost.gcShell,
    );
  }
}

class _GcWarningsBody extends ConsumerWidget {
  const _GcWarningsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const ElectricianWarningsScreen(),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: BVColors.primary,
            foregroundColor: BVColors.onPrimary,
            onPressed: () {
              showBvModalSheet(
                context,
                builder: (ctx) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Create warning — form coming soon.',
                    style: TextStyle(color: BVColors.textSecondary),
                  ),
                ),
              );
            },
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _GcProfileBody extends ConsumerWidget {
  const _GcProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Name'),
          trailing: Text(ref.watch(currentUserProvider)?.name ?? '-'),
        ),
        const ListTile(title: Text('Role'), trailing: Text('General Contractor')),
        ListTile(
          title: const Text('Assigned Jobsites'),
          trailing: Text('${ref.watch(electricianJobsitesProvider).valueOrNull?.length ?? 0}'),
        ),
        OutlinedButton(
          onPressed: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: BVColors.blocker,
            side: const BorderSide(color: BVColors.blocker),
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
