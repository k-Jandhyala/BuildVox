import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/account_menu_button.dart';
import 'my_tasks_screen.dart';
import 'submit_memo_screen.dart';

class WorkerHome extends ConsumerStatefulWidget {
  const WorkerHome({super.key});

  @override
  ConsumerState<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends ConsumerState<WorkerHome> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    MyTasksScreen(),
    SubmitMemoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildVox'),
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
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Voice Memo',
          ),
        ],
      ),
    );
  }
}
