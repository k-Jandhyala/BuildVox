import '../../models/electrician_models.dart';

/// Which shell hosts the field note screen (focus + visibility rules).
enum FieldNoteHost {
  tradeWorker,
  gcShell,
}

/// Describes one quick-tag chip on the field note screen.
class FieldNoteTagDefinition {
  final String chipLabel;
  final String shortTypeLabel;
  final ElectricianCategory category;
  final bool isBlocker;
  final bool isMaterialRequest;

  const FieldNoteTagDefinition({
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
  /// Default selected chip index (usually “Progress”).
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
        'Describe the electrical work update...\n(Tip: tap 🎤 on your keyboard to speak)',
    tags: const [
      FieldNoteTagDefinition(
        chipLabel: '🔌 Wiring',
        shortTypeLabel: 'Wiring',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipLabel: '🚧 Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipLabel: '📦 Materials',
        shortTypeLabel: 'Materials',
        category: ElectricianCategory.materialRequest,
        isMaterialRequest: true,
      ),
      FieldNoteTagDefinition(
        chipLabel: '✅ Progress',
        shortTypeLabel: 'Progress',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipLabel: '⚠️ Safety',
        shortTypeLabel: 'Safety',
        category: ElectricianCategory.siteIssue,
      ),
    ],
  );

  static const TradeFieldNoteLayout plumber = TradeFieldNoteLayout(
    title: 'Field Note',
    defaultTagIndex: 3,
    placeholder:
        'Describe the plumbing update or issue...\n(Tip: tap 🎤 on your keyboard to speak)',
    tags: const [
      FieldNoteTagDefinition(
        chipLabel: '🔩 Pipe Work',
        shortTypeLabel: 'Pipe Work',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipLabel: '🚧 Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipLabel: '📦 Materials',
        shortTypeLabel: 'Materials',
        category: ElectricianCategory.materialRequest,
        isMaterialRequest: true,
      ),
      FieldNoteTagDefinition(
        chipLabel: '✅ Progress',
        shortTypeLabel: 'Progress',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipLabel: '💧 Leak/Issue',
        shortTypeLabel: 'Leak/Issue',
        category: ElectricianCategory.siteIssue,
      ),
    ],
  );

  /// GC “Post Update” tab — site-wide notices.
  static const TradeFieldNoteLayout gc = TradeFieldNoteLayout(
    title: 'Post Update',
    defaultTagIndex: 0,
    placeholder:
        'Post a site-wide update or notice...\n(Tip: tap 🎤 on your keyboard to speak)',
    tags: const [
      FieldNoteTagDefinition(
        chipLabel: '📢 Site Notice',
        shortTypeLabel: 'Site Notice',
        category: ElectricianCategory.generalReport,
      ),
      FieldNoteTagDefinition(
        chipLabel: '🚧 Blocker',
        shortTypeLabel: 'Blocker',
        category: ElectricianCategory.blocker,
        isBlocker: true,
      ),
      FieldNoteTagDefinition(
        chipLabel: '✅ Milestone',
        shortTypeLabel: 'Milestone',
        category: ElectricianCategory.taskUpdate,
      ),
      FieldNoteTagDefinition(
        chipLabel: '⚠️ Safety',
        shortTypeLabel: 'Safety',
        category: ElectricianCategory.siteIssue,
      ),
      FieldNoteTagDefinition(
        chipLabel: '📋 Inspection',
        shortTypeLabel: 'Inspection',
        category: ElectricianCategory.generalReport,
      ),
    ],
  );
}
