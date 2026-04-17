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
    final warningCount =
        queue.where((q) => q.status != QueueStatus.completed).length;

    return Scaffold(
      backgroundColor: BVColors.background,
      appBar: AppBar(
        title: const Text('BuildVox'),
        actions: const [AccountMenuButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: jobsites.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => const Text(
                'Failed to load jobsites',
                style: TextStyle(color: BVColors.danger, fontSize: 13),
              ),
              data: (sites) {
                if (sites.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: BVColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No assigned jobsites — contact your manager.',
                      style: TextStyle(color: BVColors.textSecondary, fontSize: 13),
                    ),
                  );
                }
                final selected = sites.any((s) => s.id == selectedSiteId)
                    ? selectedSiteId
                    : sites.first.id;
                if (selected != selectedSiteId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(selectedElectricianSiteProvider.notifier).setSite(selected!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switched to your first assigned jobsite.'),
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
                    builder: (ctx) => _JobsiteSheet(
                      sites: sites,
                      selectedSiteId: selected,
                      onSelect: (id) {
                        ref.read(selectedElectricianSiteProvider.notifier).setSite(id);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: BVColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: BVColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentSite.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: BVColors.onSurface,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: BVColors.textSecondary, size: 20),
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
      floatingActionButton: _RecordFab(
        active: _tab == 2,
        onTap: () => setState(() => _tab = 2),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        selectedIndex: _tab,
        warningCount: warningCount,
        onSelect: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _RecordFab extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _RecordFab({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [BVColors.primaryLight, BVColors.primary],
            radius: 0.85,
          ),
          boxShadow: [
            BoxShadow(
              color: BVColors.primary.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: active
              ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)
              : null,
        ),
        child: const Icon(Icons.mic_rounded, size: 30, color: Colors.white),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selectedIndex;
  final int warningCount;
  final ValueChanged<int> onSelect;

  const _BottomBar({
    required this.selectedIndex,
    required this.warningCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: BVColors.background,
      elevation: 0,
      height: 64,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _item(0, Icons.home_outlined, 'Home'),
          _item(1, Icons.assignment_outlined, 'Tasks'),
          const Expanded(child: SizedBox()),
          _warningItem(),
          _item(4, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _item(int idx, IconData icon, String label) {
    final selected = selectedIndex == idx;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(idx),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? BVColors.primary : BVColors.textMuted,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? BVColors.primary : BVColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningItem() {
    final selected = selectedIndex == 3;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(3),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: warningCount > 0,
              label: Text('$warningCount',
                  style: const TextStyle(fontSize: 9, color: Colors.white)),
              backgroundColor: BVColors.danger,
              child: Icon(Icons.warning_amber_rounded,
                  color: selected ? BVColors.primary : BVColors.textMuted,
                  size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              'Warnings',
              style: TextStyle(
                color: selected ? BVColors.primary : BVColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsiteSheet extends StatelessWidget {
  final dynamic sites;
  final String? selectedSiteId;
  final ValueChanged<String> onSelect;

  const _JobsiteSheet({
    required this.sites,
    required this.selectedSiteId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BVColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Jobsite',
              style: TextStyle(
                  color: BVColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...sites.map<Widget>((s) {
              final selected = s.id == selectedSiteId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(Icons.location_on_outlined,
                    color: selected ? BVColors.primary : BVColors.textMuted),
                title: Text(s.name,
                    style: TextStyle(
                        color: selected ? BVColors.primary : BVColors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(s.address,
                    style: const TextStyle(
                        color: BVColors.textSecondary, fontSize: 12)),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: BVColors.primary)
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
