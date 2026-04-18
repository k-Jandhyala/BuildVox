import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
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
    SizedBox.shrink(), // FAB slot
  ];

  void _onFabTap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubmitMemoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final roleLabel = user?.roleLabel ?? 'BuildVox';

    Color c(int i) => _selectedIndex == i ? BVColors.primary : BVColors.textSecondary;

    return Scaffold(
      backgroundColor: BVColors.background,
      appBar: AppBar(
        title: Text(roleLabel),
        actions: const [AccountMenuButton()],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: _RecordFab(onTap: _onFabTap),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64,
        color: BVColors.surface,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.assignment_outlined,
                label: 'My Tasks',
                color: c(0),
                onTap: () => setState(() => _selectedIndex = 0),
              ),
            ),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _RecordFab extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordFab({required this.onTap});

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
              color: BVColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
