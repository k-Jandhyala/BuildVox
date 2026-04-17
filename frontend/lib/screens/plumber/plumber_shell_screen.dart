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
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('BuildVox  ·  Plumber'),
        actions: const [AccountMenuButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: jobsites.when(
              loading: () => const LinearProgressIndicator(minHeight: 3),
              error: (e, _) => Text(
                'Failed to load jobsites: $e',
                style: const TextStyle(color: Colors.redAccent),
              ),
              data: (sites) {
                if (sites.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
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
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Current Jobsite',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    fillColor: Color(0xFF1E293B),
                  ),
                  items: [
                    for (final s in sites)
                      DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${s.name} · ${s.address}',
                            overflow: TextOverflow.ellipsis),
                      )
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(selectedElectricianSiteProvider.notifier).setSite(v);
                  },
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: BVColors.primary.withValues(alpha: 0.25),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.assignment_outlined), label: 'Tasks'),
          const NavigationDestination(
              icon: Icon(Icons.mic_rounded), label: 'Record'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: queuedCount > 0,
              label: Text('$queuedCount'),
              child: const Icon(Icons.warning_amber_rounded),
            ),
            label: 'Warnings',
          ),
          const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
