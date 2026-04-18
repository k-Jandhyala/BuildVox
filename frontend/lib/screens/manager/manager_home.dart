import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/electrician_provider.dart';
import '../electrician/electrician_record_screen.dart';
import '../worker/trade_field_note_config.dart';
import '../../theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/account_menu_button.dart';
import '../../widgets/bv_modal_sheet.dart';
import '../../widgets/role_pill.dart';

/// Manager shell — multi-jobsite oversight (no center hump).
class ManagerHome extends ConsumerStatefulWidget {
  const ManagerHome({super.key});

  @override
  ConsumerState<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends ConsumerState<ManagerHome> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(managerShellTabProvider);

    return Scaffold(
      backgroundColor: BVColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('BuildVox · '),
            RolePill(
              label: 'Manager',
              backgroundColor: BVRoleColors.manager,
              foregroundColor: Colors.white,
            ),
          ],
        ),
        actions: const [AccountMenuButton()],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          const _ManagerDashboardBody(),
          const ElectricianRecordScreen(
            layout: TradeFieldNoteLayout.manager,
            host: FieldNoteHost.managerShell,
          ),
          const _ManagerJobsitesBody(),
          const _ManagerApprovalsBody(),
          const _ManagerReportsBody(),
          const _ManagerProfileBody(),
        ],
      ),
      bottomNavigationBar: _ManagerBottomNav(
        selected: tab,
        onSelect: (i) {
          ref.read(managerShellTabProvider.notifier).state = i;
          if (i == 1) {
            ref.read(recordScreenAutofocusTriggerProvider.notifier).state++;
          }
        },
      ),
    );
  }
}

class _ManagerBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _ManagerBottomNav({required this.selected, required this.onSelect});

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
                  Badge(
                    isLabelVisible: i == 3,
                    label: Text('${mockStatsManager.pendingApprovals}'),
                    backgroundColor: BVColors.blocker,
                    child: Icon(icon, color: c(i), size: 24),
                  ),
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
            item(Icons.dashboard_customize_outlined, 'Dashboard', 0),
            item(Icons.edit_note_rounded, 'Updates', 1),
            item(Icons.map_outlined, 'Jobsites', 2),
            item(Icons.fact_check_outlined, 'Approvals', 3),
            item(Icons.bar_chart_rounded, 'Reports', 4),
            item(Icons.person_outline_rounded, 'Profile', 5),
          ],
        ),
      ),
    );
  }
}

class _ManagerDashboardBody extends ConsumerWidget {
  const _ManagerDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = mockStatsManager;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: BVSpacing.screenHorizontal, vertical: BVSpacing.sectionGap),
      children: [
        const Text('All Sites', style: TextStyle(color: BVColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _KpiCard('Total Jobsites', '${m.totalJobsites}', Icons.map_outlined, BVColors.accent),
              _KpiCard('Open Blockers', '${m.openBlockers}', Icons.block_rounded, BVColors.blocker, onTap: () {}),
              _KpiCard('Pending Approvals', '${m.pendingApprovals}', Icons.fact_check_outlined, BVColors.primary, onTap: () {
                ref.read(managerShellTabProvider.notifier).state = 3;
              }),
              _KpiCard('Workers Active', '${m.workersActive}', Icons.groups_2_outlined, BVColors.done),
              _KpiCard('Safety Alerts', '${m.safetyAlerts}', Icons.shield_outlined, BVColors.blocker),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Jobsites', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...mockJobsites.map((s) => _JobsiteSummaryCard(site: s)),
        const SizedBox(height: 16),
        const Text('Recent activity', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...mockFieldNotesAllRecent(limit: 5).map((n) => _ManagerActivityCard(note: n)),
      ],
    );
  }
}

class _ManagerActivityCard extends StatelessWidget {
  final MockFieldNote note;

  const _ManagerActivityCard({required this.note});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 18, color: BVColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.author,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                note.type,
                style: const TextStyle(color: BVColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note.text,
            style: const TextStyle(color: BVColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '${mockJobsites.firstWhere((j) => j.id == note.jobsite, orElse: () => mockPrimaryJobsite).name} · ${note.floor} · ${note.submittedAt}',
            style: const TextStyle(color: BVColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _KpiCard(this.label, this.value, this.icon, this.accent, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BVColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 22),
                const Spacer(),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(color: BVColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobsiteSummaryCard extends StatelessWidget {
  final MockJobSite site;

  const _JobsiteSummaryCard({required this.site});

  @override
  Widget build(BuildContext context) {
    final p = site.progressPercent / 100.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BVColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BVColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(site.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Chip(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                label: Text(site.status, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(site.address, style: const TextStyle(color: BVColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: p, color: BVColors.primary, backgroundColor: BVColors.divider),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${site.progressPercent}% complete', style: const TextStyle(color: BVColors.textSecondary, fontSize: 11)),
              const Spacer(),
              Text('${site.openBlockers} blockers', style: const TextStyle(color: BVColors.blocker, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagerJobsitesBody extends ConsumerWidget {
  const _ManagerJobsitesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Jobsites', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...mockJobsites.map(
          (s) => ListTile(
            title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(s.address, style: const TextStyle(color: BVColors.textSecondary)),
            trailing: Chip(label: Text(s.status)),
          ),
        ),
      ],
    );
  }
}

class _ManagerApprovalsBody extends StatefulWidget {
  const _ManagerApprovalsBody();

  @override
  State<_ManagerApprovalsBody> createState() => _ManagerApprovalsBodyState();
}

class _ManagerApprovalsBodyState extends State<_ManagerApprovalsBody> with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tc,
          labelColor: BVColors.primary,
          unselectedLabelColor: BVColors.textSecondary,
          tabs: const [
            Tab(text: 'Material Requests'),
            Tab(text: 'Work Orders'),
            Tab(text: 'All'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: [
              _ApprovalsList(
                mockApprovals.where((a) => a.type == 'Material Request').toList(),
              ),
              _ApprovalsList(
                mockApprovals.where((a) => a.type == 'Work Order').toList(),
              ),
              _ApprovalsList(mockApprovals),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalsList extends StatelessWidget {
  final List<MockApproval> items;

  const _ApprovalsList(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No items', style: TextStyle(color: BVColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BVColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BVColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    a.type == 'Work Order' ? Icons.assignment_outlined : Icons.inventory_2_outlined,
                    size: 20,
                    color: BVColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    a.estimatedCost,
                    style: const TextStyle(color: BVColors.accent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${a.requestedBy} · ${a.trade}',
                style: const TextStyle(color: BVColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${mockJobsites.firstWhere((j) => j.id == a.jobsite, orElse: () => mockPrimaryJobsite).name} · ${a.submittedAt}',
                style: const TextStyle(color: BVColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Reject')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () {}, child: const Text('Approve')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerReportsBody extends StatefulWidget {
  const _ManagerReportsBody();

  @override
  State<_ManagerReportsBody> createState() => _ManagerReportsBodyState();
}

class _ManagerReportsBodyState extends State<_ManagerReportsBody> {
  String _range = 'This Week';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text('Reports', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const Spacer(),
            DropdownButton<String>(
              value: _range,
              dropdownColor: BVColors.surface,
              items: const [
                DropdownMenuItem(value: 'Today', child: Text('Today')),
                DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                DropdownMenuItem(value: 'Custom', child: Text('Custom Range')),
              ],
              onChanged: (v) => setState(() => _range = v ?? 'This Week'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _ReportTile(icon: Icons.analytics_outlined, label: 'Weekly Summary'),
            _ReportTile(icon: Icons.block_rounded, label: 'Blocker Report'),
            _ReportTile(icon: Icons.inventory_2_outlined, label: 'Materials Usage'),
            _ReportTile(icon: Icons.groups_2_outlined, label: 'Worker Activity'),
          ],
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReportTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BVColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          showBvModalSheet(
            context,
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: BVColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'This report is being processed',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Coming soon', style: TextStyle(color: BVColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BVColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: BVColors.primary),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerProfileBody extends ConsumerWidget {
  const _ManagerProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(electricianJobsitesProvider).valueOrNull ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Name'),
          trailing: Text(ref.watch(currentUserProvider)?.name ?? '-'),
        ),
        const ListTile(title: Text('Role'), trailing: Text('Manager')),
        ListTile(
          title: const Text('Managed Jobsites'),
          trailing: Text('${sites.length}'),
        ),
        ListTile(
          title: const Text('Pending Approvals'),
          trailing: Text('${mockStatsManager.pendingApprovals}'),
          onTap: () => ref.read(managerShellTabProvider.notifier).state = 3,
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
