import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/electrician_models.dart';
import '../../models/extracted_item_model.dart';
import '../../providers/electrician_provider.dart';
import '../../services/database_service.dart';
import '../../services/functions_service.dart';
import '../../services/storage_service.dart';

class ElectricianTaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  final String extractedItemId;

  const ElectricianTaskDetailScreen({
    super.key,
    required this.taskId,
    required this.extractedItemId,
  });

  @override
  ConsumerState<ElectricianTaskDetailScreen> createState() =>
      _ElectricianTaskDetailScreenState();
}

class _ElectricianTaskDetailScreenState
    extends ConsumerState<ElectricianTaskDetailScreen> {
  ExtractedItemModel? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await DatabaseService.getExtractedItem(widget.extractedItemId);
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _status(String status) async {
    await FunctionsService.updateTaskStatus(taskId: widget.taskId, status: status);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task set to $status')),
    );
  }

  Future<void> _addUpdate() async {
    final textCtrl = TextEditingController();
    String mode = 'text';
    final photos = <String>[];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Text'),
                      selected: mode == 'text',
                      onSelected: (_) => setModal(() => mode = 'text'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Voice'),
                      selected: mode == 'voice',
                      onSelected: (_) => setModal(() => mode = 'voice'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (mode == 'text')
                  TextField(
                    controller: textCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Update text'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform
                        .pickFiles(type: FileType.image, allowMultiple: true);
                    if (result == null) return;
                    setModal(() {
                      photos.addAll(result.files
                          .where((f) => f.path != null)
                          .map((f) => f.path!));
                    });
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text('Attach photos (${photos.length})'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit Update'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true) return;

    final uploaded = <String>[];
    for (final p in photos) {
      final photo = await StorageService.uploadPhoto(File(p));
      uploaded.add(photo.publicUrl);
    }
    await FunctionsService.addTaskUpdate(
      taskId: widget.taskId,
      updateType: mode,
      text: mode == 'text' ? textCtrl.text.trim() : null,
      photoUrls: uploaded,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update submitted')),
    );
  }

  Future<void> _escalate() async {
    final reasons = [
      'wrong_assignee',
      'blocked',
      'need_approval',
      'safety_issue',
      'waiting_other_trade',
      'need_materials',
      'other'
    ];
    String reason = reasons.first;
    final detailsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: reason,
              items: reasons
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => reason = v ?? reason,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Escalate')),
        ],
      ),
    );
    if (ok != true || detailsCtrl.text.trim().isEmpty) return;
    await FunctionsService.escalateTask(
      taskId: widget.taskId,
      reason: reason,
      details: detailsCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escalation sent to manager/GC')),
    );
  }

  Future<void> _materialRequest() async {
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final supplierCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Materials'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item name')),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
              TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Supplier/Vendor')),
              TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    final summary = ref.read(selectedSiteSummaryProvider);
    if (summary == null) return;
    await FunctionsService.requestMaterials(
      projectId: summary.site.projectId,
      siteId: summary.site.id,
      itemName: itemCtrl.text.trim(),
      quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
      supplier: supplierCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      taskId: widget.taskId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Material request routed to manager'),
    ));
  }

  Future<void> _blocker() async {
    final blockedCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    WarningSeverity severity = WarningSeverity.high;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flag Blocker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: blockedCtrl, decoration: const InputDecoration(labelText: 'What is blocked')),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
            DropdownButtonFormField<WarningSeverity>(
              initialValue: severity,
              items: WarningSeverity.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => severity = v ?? severity,
              decoration: const InputDecoration(labelText: 'Severity'),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Flag')),
        ],
      ),
    );
    if (ok != true) return;
    final summary = ref.read(selectedSiteSummaryProvider);
    if (summary == null) return;
    await FunctionsService.flagBlocker(
      projectId: summary.site.projectId,
      siteId: summary.site.id,
      blockedWork: blockedCtrl.text.trim(),
      location: locCtrl.text.trim(),
      severity: severity.name,
      taskId: widget.taskId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Blocker routed for downstream impact processing'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _item == null) {
      return Scaffold(body: Center(child: Text('Failed to load task: $_error')));
    }

    final item = _item!;
    return Scaffold(
      appBar: AppBar(title: const Text('Task Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.normalizedSummary,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(item.urgency.label),
              _tag(item.status.label),
              _tag(item.unitOrArea ?? 'No location'),
              _tag(item.tier.label),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.sourceText,
            style: const TextStyle(color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _action('Mark In Progress', () => _status('in_progress')),
              _action('Mark Complete', () => _status('done')),
              _action('Add Update', _addUpdate),
              _action('Escalate', _escalate),
              _action('Request Materials', _materialRequest),
              _action('Flag Blocker', _blocker),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) {
    return SizedBox(
      width: 170,
      child: ElevatedButton(onPressed: onTap, child: Text(label)),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
    );
  }
}
