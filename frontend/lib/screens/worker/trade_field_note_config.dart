import 'package:flutter/material.dart';

import '../../models/electrician_models.dart';

/// Which shell hosts the field note screen (focus + visibility rules).
enum FieldNoteHost {
  tradeWorker,
  gcShell,
  managerShell,
}

/// Describes one quick-tag chip on the field note screen (text + icon, no emoji).
class FieldNoteTagDefinition {
  final IconData chipIcon;
  final String chipLabel;
  final String shortTypeLabel;
  final ElectricianCategory category;
  final bool isBlocker;
  final bool isMaterialRequest;

  const FieldNoteTagDefinition({
    required this.chipIcon,
    required this.chipLabel,
    required this.shortTypeLabel,
    required this.category,
    this.isBlocker = false,
    this.isMaterialRequest = false,
  });
}

/// Copy, chips, and defaults for trade-worker vs GC “post update” flows.
class TradeFieldNoteLayout {
  final String title;
  final String placeholder;
  final List<FieldNoteTagDefinition> tags;
  final int defaultTagIndex;

  const TradeFieldNoteLayout({
    required this.title,
    required this.placeholder,
    required this.tags,
    this.defaultTagIndex = 3,
  });

  static const TradeFieldNoteLayout electrician = TradeFieldNoteLayout(
    title: 'Field Note',
    defaultTagIndex: 3,
    placeholder:
        'Describe the electrical work update, materials, and any blockers.',
    tags: [
      FieldNoteTagDefinition(
        chipIcon: Icons.bolt_rounded,
        chipLabel: 'Wiring',
        shortTypeLabel: 'Wiring',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.block_rounded,
        chipLabel: 'Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.inventory_2_outlined,
        chipLabel: 'Materials',
        shortTypeLabel: 'Materials',
        category: ElectricianCategory.materialRequest,
        isMaterialRequest: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.check_circle_outline_rounded,
        chipLabel: 'Progress',
        shortTypeLabel: 'Progress',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.shield_outlined,
        chipLabel: 'Safety',
        shortTypeLabel: 'Safety',
        category: ElectricianCategory.siteIssue,
      ),
    ],
  );

  static const TradeFieldNoteLayout plumber = TradeFieldNoteLayout(
    title: 'Field Note',
    defaultTagIndex: 3,
    placeholder:
        'Describe the plumbing update or issue, location, and severity.',
    tags: [
      FieldNoteTagDefinition(
        chipIcon: Icons.home_repair_service_outlined,
        chipLabel: 'Pipe Work',
        shortTypeLabel: 'Pipe Work',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.block_rounded,
        chipLabel: 'Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.inventory_2_outlined,
        chipLabel: 'Materials',
        shortTypeLabel: 'Materials',
        category: ElectricianCategory.materialRequest,
        isMaterialRequest: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.check_circle_outline_rounded,
        chipLabel: 'Progress',
        shortTypeLabel: 'Progress',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.water_drop_outlined,
        chipLabel: 'Leak/Issue',
        shortTypeLabel: 'Leak/Issue',
        category: ElectricianCategory.siteIssue,
      ),
    ],
  );

  static const TradeFieldNoteLayout gc = TradeFieldNoteLayout(
    title: 'Post Update',
    defaultTagIndex: 0,
    placeholder:
        'Post a site-wide update or notice for all trades.',
    tags: [
      FieldNoteTagDefinition(
        chipIcon: Icons.campaign_outlined,
        chipLabel: 'Site Notice',
        shortTypeLabel: 'Site Notice',
        category: ElectricianCategory.generalReport,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.block_rounded,
        chipLabel: 'Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.flag_outlined,
        chipLabel: 'Milestone',
        shortTypeLabel: 'Milestone',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.shield_outlined,
        chipLabel: 'Safety',
        shortTypeLabel: 'Safety',
        category: ElectricianCategory.siteIssue,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.assignment_outlined,
        chipLabel: 'Inspection',
        shortTypeLabel: 'Inspection',
        category: ElectricianCategory.generalReport,
      ),
    ],
  );

  /// Same tags as [gc] — Manager site-wide updates.
  static const TradeFieldNoteLayout manager = TradeFieldNoteLayout(
    title: 'Post Update',
    defaultTagIndex: 0,
    placeholder: 'Post a site-wide update or notice for all trades.',
    tags: [
      FieldNoteTagDefinition(
        chipIcon: Icons.campaign_outlined,
        chipLabel: 'Site Notice',
        shortTypeLabel: 'Site Notice',
        category: ElectricianCategory.generalReport,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.block_rounded,
        chipLabel: 'Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.flag_outlined,
        chipLabel: 'Milestone',
        shortTypeLabel: 'Milestone',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.shield_outlined,
        chipLabel: 'Safety',
        shortTypeLabel: 'Safety',
        category: ElectricianCategory.siteIssue,
      ),
      FieldNoteTagDefinition(
        chipIcon: Icons.assignment_outlined,
        chipLabel: 'Inspection',
        shortTypeLabel: 'Inspection',
        category: ElectricianCategory.generalReport,
      ),
    ],
  );
}
