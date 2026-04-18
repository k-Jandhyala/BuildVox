import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/electrician_models.dart';
import '../../providers/electrician_provider.dart';

class AiReviewScreen extends ConsumerWidget {
  const AiReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(recordFlowProvider);
    final items = asyncItems.valueOrNull ?? const [];
    final isPolling = ref.watch(recordFlowProvider.notifier).isPolling;
    final selected = ref.watch(selectedSiteSummaryProvider)?.site;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        title: const Text('AI Review'),
        actions: [
          TextButton(
            onPressed: () => ref.read(recordFlowProvider.notifier).addManualItem(),
            child: const Text('Add Item'),
          ),
        ],
      ),
      body: selected == null
          ? const Center(child: Text('No selected jobsite'))
          : asyncItems.isLoading || isPolling
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI is extracting action items…',
                          style: TextStyle(color: Color(0xFFCBD5E1))),
                    ],
                  ),
                )
          : asyncItems.hasError
              ? Center(child: Text('Error: ${asyncItems.error}',
                  style: const TextStyle(color: Colors.redAccent)))
          : items.isEmpty
              ? const _EmptyReviewState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Review ${items.length} extracted item(s) for ${selected.name}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    ...items.map((item) => _ReviewItemCard(item: item)),
                    const SizedBox(height: 80),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: selected == null
              ? null
              : () async {
                  try {
                    await ref.read(recordFlowProvider.notifier).submitAll(
                          projectId: selected.projectId,
                          siteId: selected.id,
                        );
                    if (!context.mounted) return;
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Submitted successfully. Routed to project team.'),
                    ));
                    Navigator.of(context).pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Queued for sync: $e')),
                    );
                  }
                },
          icon: const Icon(Icons.send_rounded),
          label: const Text('Submit Reviewed Items'),
        ),
      ),
    );
  }
}

class _ReviewItemCard extends ConsumerWidget {
  final AiExtractedItem item;
  const _ReviewItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryCtrl = TextEditingController(text: item.summary);
    final notesCtrl = TextEditingController(text: item.notes);
    final locCtrl = TextEditingController(text: item.location);

    AiExtractedItem update(AiExtractedItem next) {
      ref.read(recordFlowProvider.notifier).updateItem(next);
      return next;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: ExpansionTile(
        initiallyExpanded: item.expanded,
        onExpansionChanged: (v) => update(item.copyWith(expanded: v)),
        title: Text(
          item.summary.isEmpty ? 'Untitled item' : item.summary,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.category.name} · ${item.priority.name}',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        trailing: IconButton(
          onPressed: () => ref.read(recordFlowProvider.notifier).deleteItem(item.id),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: summaryCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Summary'),
                  onChanged: (v) => update(item.copyWith(summary: v)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ElectricianCategory>(
                        initialValue: item.category,
                        dropdownColor: const Color(0xFF111827),
                        items: ElectricianCategory.values
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) update(item.copyWith(category: v));
                        },
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<ElectricianPriority>(
                        initialValue: item.priority,
                        dropdownColor: const Color(0xFF111827),
                        items: ElectricianPriority.values
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) update(item.copyWith(priority: v));
                        },
                        decoration: const InputDecoration(labelText: 'Priority'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Location'),
                  onChanged: (v) => update(item.copyWith(location: v)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: item.relatedTrade,
                  dropdownColor: const Color(0xFF111827),
                  items: const [
                    DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                    DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                    DropdownMenuItem(value: 'framing', child: Text('Framing')),
                    DropdownMenuItem(value: 'drywall', child: Text('Drywall')),
                    DropdownMenuItem(value: 'general', child: Text('General')),
                  ],
                  onChanged: (v) {
                    if (v != null) update(item.copyWith(relatedTrade: v));
                  },
                  decoration: const InputDecoration(labelText: 'Related Trade'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.dueDate == null
                            ? 'No due date'
                            : 'Due: ${DateFormat.yMMMd().format(item.dueDate!)}',
                        style: const TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) update(item.copyWith(dueDate: date));
                      },
                      child: const Text('Set Due Date'),
                    ),
                  ],
                ),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onChanged: (v) => update(item.copyWith(notes: v)),
                ),
                SwitchListTile(
                  value: item.isBlocker,
                  onChanged: (v) => update(item.copyWith(isBlocker: v)),
                  title: const Text('Mark as blocker'),
                  dense: true,
                ),
                SwitchListTile(
                  value: item.isMaterialRequest,
                  onChanged: (v) => update(item.copyWith(isMaterialRequest: v)),
                  title: const Text('Mark as material request'),
                  dense: true,
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                            type: FileType.image, allowMultiple: true);
                        if (result == null) return;
                        final paths = result.files
                            .where((f) => f.path != null)
                            .map((f) => f.path!)
                            .toList();
                        update(item.copyWith(
                            attachedPhotos: [...item.attachedPhotos, ...paths]));
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Attach photos'),
                    ),
                    const SizedBox(width: 10),
                    Text('${item.attachedPhotos.length} attached',
                        style: const TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
                if (item.attachedPhotos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.attachedPhotos
                        .map((p) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                File(p).uri.pathSegments.last,
                                style: const TextStyle(
                                    color: Color(0xFFCBD5E1), fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                if (item.transcriptSegment.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Transcript context: ${item.transcriptSegment}',
                      style: const TextStyle(color: Color(0xFF93C5FD)),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'AI found zero actionable items. Add a manual item and submit.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
