import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/account_menu_button.dart';
import '../../theme.dart';
import 'incoming_requests_screen.dart';
import 'task_board_screen.dart';
import '../worker/submit_memo_screen.dart';

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
    SubmitMemoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildVox  ·  Manager'),
        actions: const [AccountMenuButton()],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _ManagerBottomBar(
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _ManagerBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _ManagerBottomBar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final color =
        (int i) => selectedIndex == i ? Colors.white : BVColors.textSecondary;
    return SafeArea(
      top: false,
      child: Container(
        height: 86,
        decoration: const BoxDecoration(
          color: BVColors.surface,
          border: Border(top: BorderSide(color: BVColors.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left side
            _item(
              icon: Icons.inbox_outlined,
              label: 'Requests',
              color: color(0),
              onTap: () => onSelect(0),
              selected: selectedIndex == 0,
            ),
            _item(
              icon: Icons.view_kanban_outlined,
              label: 'Task Board',
              color: color(1),
              onTap: () => onSelect(1),
              selected: selectedIndex == 1,
            ),

            // Center mic button (always middle)
            GestureDetector(
              onTap: () => onSelect(2),
              child: Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: BVColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.mic_rounded, size: 28, color: Colors.white),
              ),
            ),

            // Right side placeholders (keeps mic centered between 2 and 2)
            _item(
              icon: Icons.analytics_outlined,
              label: 'Overview',
              color: BVColors.textSecondary,
              onTap: () {},
              selected: false,
            ),
            _item(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              color: BVColors.textSecondary,
              onTap: () {},
              selected: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool selected,
  }) {
    return SizedBox(
      width: 92,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
