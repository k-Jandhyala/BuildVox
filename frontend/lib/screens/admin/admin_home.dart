import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/extracted_items_provider.dart';
import '../../services/auth_service.dart';
import '../../services/functions_service.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/extracted_item_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/tier_badge.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildVox  ·  Admin'),
        actions: [
          TextButton(
            onPressed: () => AuthService.signOut(),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _SeedTab(),
          _AllItemsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Setup',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'All Items',
          ),
        ],
      ),
    );
  }
}

// ── Seed & Setup tab ──────────────────────────────────────────────────────────

class _SeedTab extends ConsumerStatefulWidget {
  const _SeedTab();

  @override
  ConsumerState<_SeedTab> createState() => _SeedTabState();
}

class _SeedTabState extends ConsumerState<_SeedTab> {
  bool _seeding = false;
  String? _seedResult;
  String? _seedError;

  Future<void> _seed() async {
    setState(() {
      _seeding = true;
      _seedResult = null;
      _seedError = null;
    });
    try {
      final result = await FunctionsService.seedDemoData();
      setState(() {
        _seedResult = result['message'] as String? ?? 'Seed complete.';
      });
    } catch (e) {
      setState(() {
        _seedError =
            'Seed failed: $e\n\nMake sure you are signed in as admin@demo.com\n'
            'or use the HTTP endpoint: POST /seedDemoDataHttp with body {"secret":"BuildVoxSeed2024"}';
      });
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Demo data ────────────────────────────────────────────────
              _AdminCard(
                icon: Icons.people_outline_rounded,
                title: 'Seed Demo Data',
                description:
                    'Creates 5 demo users, 2 companies, 1 project, and 2 job sites.\n\n'
                    'Demo accounts:\n'
                    '  • gc@demo.com\n'
                    '  • electrician@demo.com\n'
                    '  • plumber@demo.com\n'
                    '  • manager@demo.com\n'
                    '  • admin@demo.com\n\n'
                    'Password for all: BuildVox2024!',
                actionLabel: 'Run Seed',
                onAction: _seed,
              ),

              if (_seedResult != null) ...[
                const SizedBox(height: 14),
                _ResultBanner(
                    message: _seedResult!,
                    color: BVColors.done,
                    icon: Icons.check_circle_rounded),
              ],
              if (_seedError != null) ...[
                const SizedBox(height: 14),
                _ResultBanner(
                    message: _seedError!,
                    color: BVColors.blocker,
                    icon: Icons.error_outline_rounded),
              ],

              const SizedBox(height: 24),

              // ── Emulator tip ─────────────────────────────────────────────
              _AdminCard(
                icon: Icons.developer_mode_outlined,
                title: 'Local Emulator Setup',
                description:
                    'If using the Firebase emulator, uncomment the emulator\n'
                    'config in main.dart:\n\n'
                    '  FunctionsService.useEmulator("10.0.2.2", 5001);\n\n'
                    'Run emulators with:\n'
                    '  firebase emulators:start',
                actionLabel: null,
                onAction: null,
              ),

              const SizedBox(height: 24),

              // ── Sign out ─────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: AuthService.signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BVColors.blocker,
                  side: const BorderSide(color: BVColors.blocker),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_seeding)
          const LoadingOverlay(message: 'Seeding demo data…'),
      ],
    );
  }
}

// ── All Items tab ─────────────────────────────────────────────────────────────

class _AllItemsTab extends ConsumerWidget {
  const _AllItemsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(allItemsProvider);

    return itemsAsync.when(
      loading: () =>
          const InlineLoader(message: 'Loading all extracted items…'),
      error: (e, _) =>
          Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.list_alt_outlined,
            title: 'No extracted items yet',
            subtitle:
                'Submit a voice memo as a worker\nto see items extracted here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allItemsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _AdminCountBanner(count: items.length);
              }
              return ExtractedItemCard(item: items[i - 1]);
            },
          ),
        );
      },
    );
  }
}

class _AdminCountBanner extends StatelessWidget {
  final int count;
  const _AdminCountBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BVColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BVColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded,
              color: BVColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            '$count total extracted item${count != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              color: BVColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: BVColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BVColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: BVColors.textSecondary,
              height: 1.6,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _ResultBanner(
      {required this.message, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
