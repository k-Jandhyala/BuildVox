import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/functions_service.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';

class DailyDigestScreen extends ConsumerStatefulWidget {
  const DailyDigestScreen({super.key});

  @override
  ConsumerState<DailyDigestScreen> createState() =>
      _DailyDigestScreenState();
}

class _DailyDigestScreenState extends ConsumerState<DailyDigestScreen> {
  bool _generating = false;
  String? _digestText;
  String? _errorMessage;
  int? _itemCount;

  Future<void> _generateDigest() async {
    final projectId = ref.read(selectedProjectIdProvider);
    if (projectId == null) {
      setState(() => _errorMessage = 'No project selected.');
      return;
    }

    setState(() {
      _generating = true;
      _errorMessage = null;
      _digestText = null;
    });

    try {
      final result = await FunctionsService.generateDailyDigest(
        projectId: projectId,
      );
      setState(() {
        _digestText = result['summary'] as String?;
        _itemCount = result['itemCount'] as int?;
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not generate digest: $e';
        _generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(userProjectsProvider);
    final selectedProjectId = ref.watch(selectedProjectIdProvider);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              const Text(
                'Daily Digest',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BVColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Aggregates all activity from today into a summary.',
                style: TextStyle(
                    fontSize: 13, color: BVColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),

              // ── Project selector ─────────────────────────────────────────
              const Text(
                'PROJECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: BVColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (projects) => DropdownButtonFormField<String>(
                  value: selectedProjectId,
                  hint: const Text('Select a project'),
                  items: projects
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      ref.read(selectedProjectIdProvider.notifier).state = v,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Generate button ──────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _generating ? null : _generateDigest,
                icon: const Icon(Icons.summarize_rounded, size: 18),
                label: const Text('Generate Digest for Today'),
              ),

              // ── Error ────────────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BVColors.blocker.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: BVColors.blocker.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: BVColors.blocker, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 13, color: BVColors.blocker),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Digest result ────────────────────────────────────────────
              if (_digestText != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.article_outlined,
                        color: BVColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Digest — $_itemCount item${_itemCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BVColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BVColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BVColors.divider),
                  ),
                  child: SelectableText(
                    _digestText!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: BVColors.onSurface,
                      height: 1.7,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (_generating)
          const LoadingOverlay(message: 'Generating digest…'),
      ],
    );
  }
}
