import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/account_menu_button.dart';
import 'blockers_screen.dart';
import 'schedule_changes_screen.dart';
import 'project_feed_screen.dart';
import 'daily_digest_screen.dart';

class GcHome extends ConsumerStatefulWidget {
  const GcHome({super.key});

  @override
  ConsumerState<GcHome> createState() => _GcHomeState();
}

class _GcHomeState extends ConsumerState<GcHome> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    BlockersScreen(),
    ScheduleChangesScreen(),
    ProjectFeedScreen(),
    DailyDigestScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildVox  ·  GC'),
        actions: const [AccountMenuButton()],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.block_outlined),
            selectedIcon: Icon(Icons.block_rounded),
            label: 'Blockers',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.feed_outlined),
            selectedIcon: Icon(Icons.feed_rounded),
            label: 'Project Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize_rounded),
            label: 'Digest',
          ),
        ],
      ),
    );
  }
}
