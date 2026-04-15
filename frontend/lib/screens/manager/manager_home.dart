import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import 'incoming_requests_screen.dart';
import 'task_board_screen.dart';

class ManagerHome extends ConsumerStatefulWidget {
  const ManagerHome({super.key});

  @override
  ConsumerState<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends ConsumerState<ManagerHome> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    IncomingRequestsScreen(),
    TaskBoardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildVox  ·  Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: BVColors.accent,
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban_rounded),
            label: 'Task Board',
          ),
        ],
      ),
    );
  }
}
