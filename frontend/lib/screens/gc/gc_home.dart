import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/account_menu_button.dart';
import 'blockers_screen.dart';
import 'schedule_changes_screen.dart';
import 'project_feed_screen.dart';
import 'daily_digest_screen.dart';
import '../worker/submit_memo_screen.dart';
import 'gc_task_board_screen.dart';
import '../../theme.dart';

class GcHome extends ConsumerStatefulWidget {
  const GcHome({super.key});

  @override
  ConsumerState<GcHome> createState() => _GcHomeState();
}

class _GcHomeState extends ConsumerState<GcHome> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    ProjectFeedScreen(),
    GcTaskBoardScreen(),
    SubmitMemoScreen(),
    BlockersScreen(),
    ScheduleChangesScreen(),
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
      bottomNavigationBar: _GcBottomBar(
        selectedIndex: _selectedIndex,
        onSelect: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _GcBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _GcBottomBar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final color =
        (int i) => selectedIndex == i ? BVColors.primary : BVColors.textSecondary;
    return SafeArea(
      top: false,
      child: Container(
        height: 102,
        decoration: const BoxDecoration(
          color: BVColors.surface,
          border: Border(top: BorderSide(color: BVColors.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _item(Icons.feed_outlined, 'Home', color(0), () => onSelect(0)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _item(Icons.view_kanban_outlined, 'Tasks', color(1),
                  () => onSelect(1)),
            ),
            GestureDetector(
              onTap: () => onSelect(2),
              child: Container(
                width: 72,
                height: 72,
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
                child: const Icon(Icons.mic_rounded, size: 32, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _item(Icons.block_outlined, 'Blockers', color(3),
                  () => onSelect(3)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _item(Icons.summarize_outlined, 'Digest', color(5),
                  () => onSelect(5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 70,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
