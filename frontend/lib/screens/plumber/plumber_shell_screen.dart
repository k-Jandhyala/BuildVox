import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/electrician_models.dart';
import '../../providers/electrician_provider.dart';
import '../../theme.dart';
import '../../widgets/account_menu_button.dart';
import 'plumber_home_screen.dart';
import 'plumber_profile_screen.dart';
import 'plumber_record_screen.dart';
import 'plumber_tasks_screen.dart';
import 'plumber_warnings_screen.dart';

class PlumberShellScreen extends ConsumerStatefulWidget {
  const PlumberShellScreen({super.key});

  @override
  ConsumerState<PlumberShellScreen> createState() => _PlumberShellScreenState();
}

class _PlumberShellScreenState extends ConsumerState<PlumberShellScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final jobsites = ref.watch(electricianJobsitesProvider);
    final selectedSiteId = ref.watch(selectedElectricianSiteProvider).valueOrNull;
    final queue = ref.watch(electricianQueueProvider).valueOrNull ?? const [];
    final queuedCount =
        queue.where((q) => q.status != QueueStatus.completed).length;

    return Scaffold(
      backgroundColor: BVColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('BuildVox'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BVColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Plumber'),
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
              error: (e, _) => Text(
                'Failed to load jobsites: $e',
                style: const TextStyle(color: BVColors.blocker),
              ),
              data: (sites) {
                if (sites.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BVColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No assigned jobsites. Contact your manager to get assigned before using plumber workflow.',
                    ),
                  );
                }
                final selected = sites.any((s) => s.id == selectedSiteId)
                    ? selectedSiteId
                    : sites.first.id;
                if (selected != selectedSiteId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(selectedElectricianSiteProvider.notifier)
                        .setSite(selected!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Your previous jobsite is unavailable. Switched to first assigned site.'),
                      ),
                    );
                  });
                }
                final currentSite = sites.firstWhere((s) => s.id == selected);
                return InkWell(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: BVColors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => _PlumberJobsiteSheet(
                      sites: sites,
                      selectedSiteId: selected,
                      onSelect: (id) {
                        ref.read(selectedElectricianSiteProvider.notifier).setSite(id);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BVColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BVColors.primary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: BVColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${currentSite.name} · ${currentSite.address}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        index: _tab,
        children: const [
          PlumberHomeScreen(),
          PlumberTasksScreen(),
          PlumberRecordScreen(),
          PlumberWarningsScreen(),
          PlumberProfileScreen(),
        ],
      ),
      bottomNavigationBar: _PlumberBottomBar(
        selectedIndex: _tab,
        warningCount: queuedCount,
        onSelect: (index) => setState(() => _tab = index),
      ),
    );
  }
}

class _PlumberJobsiteSheet extends StatelessWidget {
  final dynamic sites;
  final String? selectedSiteId;
  final ValueChanged<String> onSelect;

  const _PlumberJobsiteSheet({
    required this.sites,
    required this.selectedSiteId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: BVColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            ...sites.map<Widget>((s) {
              final selected = s.id == selectedSiteId;
              return ListTile(
                leading: Icon(Icons.location_on_outlined,
                    color: selected ? BVColors.primary : BVColors.textSecondary),
                title: Text(s.name),
                subtitle: Text(s.address),
                trailing: selected
                    ? const Icon(Icons.check_circle_rounded, color: BVColors.primary)
                    : null,
                onTap: () => onSelect(s.id as String),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _PlumberBottomBar extends StatelessWidget {
  final int selectedIndex;
  final int warningCount;
  final ValueChanged<int> onSelect;
  const _PlumberBottomBar({
    required this.selectedIndex,
    required this.warningCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = (int i) => selectedIndex == i ? BVColors.primary : BVColors.textSecondary;
    return Container(
      height: 86,
      decoration: const BoxDecoration(
        color: BVColors.surface,
        border: Border(top: BorderSide(color: BVColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(Icons.home_outlined, 'Home', color(0), () => onSelect(0)),
          _item(Icons.assignment_outlined, 'Tasks', color(1), () => onSelect(1)),
          GestureDetector(
            onTap: () => onSelect(2),
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: BVColors.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 8))],
              ),
              child: const Icon(Icons.mic_rounded, size: 30, color: Colors.white),
            ),
          ),
          Badge(
            isLabelVisible: warningCount > 0,
            label: Text('$warningCount'),
            backgroundColor: BVColors.blocker,
            child: _item(Icons.warning_amber_rounded, 'Warnings', color(3), () => onSelect(3)),
          ),
          _item(Icons.person_outline_rounded, 'Profile', color(4), () => onSelect(4)),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 21),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
