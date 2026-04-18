// Demo / preview data for all roles. Single source for placeholder UI (no inline literals).
import '../models/electrician_models.dart';
import '../models/extracted_item_model.dart';
import '../models/task_assignment_model.dart';

// ── Jobsites ────────────────────────────────────────────────────────────────

class MockJobSite {
  final String id;
  final String name;
  final String address;
  final String status;
  final int progressPercent;
  final int activeWorkers;
  final int openBlockers;
  final String lastUpdated;

  const MockJobSite({
    required this.id,
    required this.name,
    required this.address,
    required this.status,
    required this.progressPercent,
    required this.activeWorkers,
    required this.openBlockers,
    required this.lastUpdated,
  });
}

const List<MockJobSite> mockJobsites = [
  MockJobSite(
    id: 'site_001',
    name: 'Floors 6-10',
    address: '123 Main St, Downtown',
    status: 'Active',
    progressPercent: 62,
    activeWorkers: 14,
    openBlockers: 3,
    lastUpdated: '10 mins ago',
  ),
  MockJobSite(
    id: 'site_002',
    name: 'Parking Structure B',
    address: '456 Harbor Blvd',
    status: 'Active',
    progressPercent: 38,
    activeWorkers: 9,
    openBlockers: 1,
    lastUpdated: '1 hr ago',
  ),
  MockJobSite(
    id: 'site_003',
    name: 'Retail Fit-Out Unit 4',
    address: '789 Commerce Ave',
    status: 'On Hold',
    progressPercent: 15,
    activeWorkers: 0,
    openBlockers: 2,
    lastUpdated: '3 hrs ago',
  ),
];

MockJobSite get mockPrimaryJobsite =>
    mockJobsites.firstWhere((j) => j.id == 'site_001');

// ── Workers (reference) ─────────────────────────────────────────────────────

class MockWorkerRef {
  final String id;
  final String name;
  final String trade;
  final String company;
  final List<String> jobsites;

  const MockWorkerRef({
    required this.id,
    required this.name,
    required this.trade,
    required this.company,
    required this.jobsites,
  });
}

const String mockElectricianWorkerId = 'w_001';
const String mockPlumberWorkerId = 'w_003';

// ── Tasks ─────────────────────────────────────────────────────────────────────

class MockWorkerTask {
  final String id;
  final String title;
  final String trade;
  final String assignedTo;
  final String jobsite;
  final String floor;
  final String priority;
  final String status;
  final String dueDate;
  final bool isMaterialRelated;
  final bool isBlocker;

  const MockWorkerTask({
    required this.id,
    required this.title,
    required this.trade,
    required this.assignedTo,
    required this.jobsite,
    required this.floor,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.isMaterialRelated,
    required this.isBlocker,
  });
}

const List<MockWorkerTask> mockTasks = [
  MockWorkerTask(
    id: 'task_001',
    title: 'Run conduit from panel B to junction box 12',
    trade: 'Electrician',
    assignedTo: 'w_001',
    jobsite: 'site_001',
    floor: 'Floor 7',
    priority: 'High',
    status: 'In Progress',
    dueDate: 'Today, 3:00 PM',
    isMaterialRelated: false,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_002',
    title: 'Install outlet clusters in east corridor',
    trade: 'Electrician',
    assignedTo: 'w_001',
    jobsite: 'site_001',
    floor: 'Floor 8',
    priority: 'Medium',
    status: 'Not Started',
    dueDate: 'Today, 5:00 PM',
    isMaterialRelated: true,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_003',
    title: 'Terminate wiring for HVAC units 3 and 4',
    trade: 'Electrician',
    assignedTo: 'w_002',
    jobsite: 'site_001',
    floor: 'Floor 9',
    priority: 'High',
    status: 'Blocked',
    dueDate: 'Today, 2:00 PM',
    isMaterialRelated: false,
    isBlocker: true,
  ),
  MockWorkerTask(
    id: 'task_004',
    title: 'Replace corroded pipe section in west riser',
    trade: 'Plumber',
    assignedTo: 'w_003',
    jobsite: 'site_001',
    floor: 'Basement',
    priority: 'High',
    status: 'In Progress',
    dueDate: 'Today, 1:00 PM',
    isMaterialRelated: true,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_005',
    title: 'Install pressure relief valve — boiler room',
    trade: 'Plumber',
    assignedTo: 'w_003',
    jobsite: 'site_001',
    floor: 'Basement',
    priority: 'Medium',
    status: 'Not Started',
    dueDate: 'Today, 4:00 PM',
    isMaterialRelated: false,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_006',
    title: 'Flush and test floor 6 supply lines',
    trade: 'Plumber',
    assignedTo: 'w_004',
    jobsite: 'site_002',
    floor: 'Floor 6',
    priority: 'Low',
    status: 'Not Started',
    dueDate: 'Tomorrow, 9:00 AM',
    isMaterialRelated: false,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_007',
    title: 'Coordinate concrete pour — column grid C',
    trade: 'GC',
    assignedTo: 'w_005',
    jobsite: 'site_001',
    floor: 'Floor 10',
    priority: 'High',
    status: 'In Progress',
    dueDate: 'Today, 12:00 PM',
    isMaterialRelated: false,
    isBlocker: false,
  ),
  MockWorkerTask(
    id: 'task_008',
    title: 'Verify subcontractor safety induction — new crew',
    trade: 'GC',
    assignedTo: 'w_005',
    jobsite: 'site_002',
    floor: 'Site-Wide',
    priority: 'High',
    status: 'Not Started',
    dueDate: 'Today, 8:00 AM',
    isMaterialRelated: false,
    isBlocker: false,
  ),
];

List<MockWorkerTask> mockTasksForElectrician() => mockTasks
    .where((t) => t.trade == 'Electrician' && t.assignedTo == mockElectricianWorkerId)
    .toList();

List<MockWorkerTask> mockTasksForPlumber() => mockTasks
    .where((t) => t.trade == 'Plumber' && t.assignedTo == mockPlumberWorkerId)
    .toList();

List<MockWorkerTask> mockTasksAssignedHome({
  required String workerId,
  required String siteId,
}) =>
    mockTasks
        .where((t) => t.assignedTo == workerId && t.jobsite == siteId)
        .toList();

UrgencyLevel _mockUrgency(String p) {
  switch (p) {
    case 'High':
      return UrgencyLevel.high;
    case 'Medium':
      return UrgencyLevel.medium;
    case 'Low':
      return UrgencyLevel.low;
    default:
      return UrgencyLevel.medium;
  }
}

ItemStatus _mockAssignmentStatus(String s) {
  switch (s) {
    case 'In Progress':
      return ItemStatus.inProgress;
    case 'Not Started':
      return ItemStatus.pending;
    case 'Blocked':
      return ItemStatus.acknowledged;
    case 'Completed':
      return ItemStatus.done;
    default:
      return ItemStatus.pending;
  }
}

String _mockTradeKey(String trade) {
  switch (trade) {
    case 'Plumber':
      return 'plumbing';
    case 'Electrician':
      return 'electrician';
    case 'GC':
      return 'gc';
    default:
      return 'other';
  }
}

TierType _mockTier(MockWorkerTask m) {
  if (m.isBlocker) return TierType.issueOrBlocker;
  if (m.isMaterialRelated) return TierType.materialRequest;
  return TierType.progressUpdate;
}

ElectricianTask mockWorkerTaskToElectricianTask(MockWorkerTask m) {
  return ElectricianTask(
    assignment: TaskAssignmentModel(
      id: 'as_${m.id}',
      extractedItemId: m.id,
      assignedToUserId: m.assignedTo,
      assignedByUserId: 'asg_demo',
      companyId: 'co_demo',
      projectId: 'proj_demo',
      siteId: m.jobsite,
      status: _mockAssignmentStatus(m.status),
      dueDate: DateTime.now(),
    ),
    item: ExtractedItemModel(
      id: m.id,
      memoId: 'memo_${m.id}',
      projectId: 'proj_demo',
      siteId: m.jobsite,
      createdBy: m.assignedTo,
      sourceText: m.title,
      normalizedSummary: m.title,
      trade: _mockTradeKey(m.trade),
      tier: _mockTier(m),
      urgency: _mockUrgency(m.priority),
      unitOrArea: m.floor,
      needsGcAttention: false,
      needsTradeManagerAttention: false,
      downstreamTrades: const [],
      recommendedCompanyType: 'other',
      actionRequired: m.isBlocker,
      suggestedNextStep: '',
      recipientUserIds: const [],
      recipientCompanyIds: const [],
      status: _mockAssignmentStatus(m.status),
    ),
    assignedByLabel: 'Site lead',
  );
}

List<ElectricianTask> mockElectricianTasksForCurrentTradeWorker({required bool isPlumber}) {
  final raw = isPlumber ? mockTasksForPlumber() : mockTasksForElectrician();
  return raw.map(mockWorkerTaskToElectricianTask).toList();
}

// ── Warnings ─────────────────────────────────────────────────────────────────

class MockWarning {
  final String id;
  final String category;
  final String title;
  final String description;
  final String severity;
  final String reportedBy;
  final String jobsite;
  final String floor;
  final String status;
  final String reportedAt;

  const MockWarning({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.reportedBy,
    required this.jobsite,
    required this.floor,
    required this.status,
    required this.reportedAt,
  });
}

const List<MockWarning> mockWarnings = [
  MockWarning(
    id: 'wrn_001',
    category: 'Safety',
    title: 'Unsecured edge opening — floor 9 north stairwell',
    description: 'Temporary barrier was removed and not replaced. Area is unsecured.',
    severity: 'Critical',
    reportedBy: 'Dana Okafor',
    jobsite: 'site_001',
    floor: 'Floor 9',
    status: 'Active',
    reportedAt: '30 mins ago',
  ),
  MockWarning(
    id: 'wrn_002',
    category: 'Inspection',
    title: 'Electrical rough-in inspection due — floors 6 and 7',
    description: 'City inspector scheduled for tomorrow at 9:00 AM. All rough-in must be complete.',
    severity: 'High',
    reportedBy: 'Sandra Kim',
    jobsite: 'site_001',
    floor: 'Floors 6-7',
    status: 'Active',
    reportedAt: '2 hrs ago',
  ),
  MockWarning(
    id: 'wrn_003',
    category: 'Material Shortage',
    title: 'Low stock — 20mm conduit',
    description: 'Current on-site stock is less than one day of usage. Reorder pending approval.',
    severity: 'Medium',
    reportedBy: 'Jordan Lee',
    jobsite: 'site_001',
    floor: 'Site-Wide',
    status: 'Active',
    reportedAt: '3 hrs ago',
  ),
  MockWarning(
    id: 'wrn_004',
    category: 'Leak Alert',
    title: 'Minor leak detected — basement supply line junction',
    description: 'Small drip observed at the basement riser junction near column B4.',
    severity: 'Medium',
    reportedBy: 'Priya Nair',
    jobsite: 'site_001',
    floor: 'Basement',
    status: 'Active',
    reportedAt: '4 hrs ago',
  ),
  MockWarning(
    id: 'wrn_005',
    category: 'Schedule',
    title: 'Concrete pour delayed — floor 10 column grid C',
    description: 'Structural engineer has not signed off. Pour rescheduled pending approval.',
    severity: 'High',
    reportedBy: 'Dana Okafor',
    jobsite: 'site_001',
    floor: 'Floor 10',
    status: 'Active',
    reportedAt: '1 hr ago',
  ),
];

WarningSeverity _parseSeverity(String s) {
  switch (s.toLowerCase()) {
    case 'critical':
      return WarningSeverity.critical;
    case 'high':
      return WarningSeverity.high;
    case 'medium':
      return WarningSeverity.medium;
    default:
      return WarningSeverity.low;
  }
}

WarningCategory _parseWarningCategory(String s) {
  switch (s) {
    case 'Safety':
      return WarningCategory.safety;
    case 'Inspection':
      return WarningCategory.inspection;
    case 'Material Shortage':
      return WarningCategory.materialShortage;
    case 'Schedule':
      return WarningCategory.schedule;
    case 'Leak Alert':
      return WarningCategory.leakAlert;
    default:
      return WarningCategory.safety;
  }
}

SiteWarning mockWarningToSiteWarning(MockWarning w) {
  return SiteWarning(
    id: w.id,
    siteId: w.jobsite,
    category: _parseWarningCategory(w.category),
    severity: _parseSeverity(w.severity),
    title: w.title,
    description:
        '${w.description}\n\n${w.floor} · Reported by ${w.reportedBy} · ${w.reportedAt}',
    createdAt: DateTime.now(),
  );
}

List<SiteWarning> mockSiteWarningsForJobsite(String siteId) =>
    mockWarnings.where((w) => w.jobsite == siteId).map(mockWarningToSiteWarning).toList();

List<SiteWarning> mockSiteWarningsByCategory(WarningCategory cat, String siteId) =>
    mockWarnings
        .where((w) => w.jobsite == siteId && _parseWarningCategory(w.category) == cat)
        .map(mockWarningToSiteWarning)
        .toList();

// ── Field notes ─────────────────────────────────────────────────────────────

class MockFieldNote {
  final String id;
  final String author;
  final String trade;
  final String jobsite;
  final String floor;
  final String type;
  final String text;
  final String status;
  final String submittedAt;

  const MockFieldNote({
    required this.id,
    required this.author,
    required this.trade,
    required this.jobsite,
    required this.floor,
    required this.type,
    required this.text,
    required this.status,
    required this.submittedAt,
  });
}

const List<MockFieldNote> mockFieldNotes = [
  MockFieldNote(
    id: 'fn_001',
    author: 'Jordan Lee',
    trade: 'Electrician',
    jobsite: 'site_001',
    floor: 'Floor 7',
    type: 'Progress',
    text:
        'Conduit run from panel B to junction box 12 is 80 percent complete. Expecting to finish before end of shift.',
    status: 'Processed',
    submittedAt: '45 mins ago',
  ),
  MockFieldNote(
    id: 'fn_002',
    author: 'Priya Nair',
    trade: 'Plumber',
    jobsite: 'site_001',
    floor: 'Basement',
    type: 'Blocker',
    text:
        'Cannot proceed with riser pipe replacement. Threading tool was not delivered with equipment this morning.',
    status: 'Processed',
    submittedAt: '1 hr ago',
  ),
  MockFieldNote(
    id: 'fn_003',
    author: 'Marcus Webb',
    trade: 'Electrician',
    jobsite: 'site_001',
    floor: 'Floor 9',
    type: 'Materials',
    text:
        'Cable trays have not arrived on floor 9. Wiring termination for HVAC units 3 and 4 is on hold until delivery.',
    status: 'Pending',
    submittedAt: '2 hrs ago',
  ),
  MockFieldNote(
    id: 'fn_004',
    author: 'Dana Okafor',
    trade: 'GC',
    jobsite: 'site_001',
    floor: 'Floor 10',
    type: 'Safety',
    text:
        'Structural sign-off for floor 10 has not been received. All trades are to stay off floor 10 until further notice.',
    status: 'Processed',
    submittedAt: '1 hr ago',
  ),
  MockFieldNote(
    id: 'fn_005',
    author: 'Carlos Reyes',
    trade: 'Plumber',
    jobsite: 'site_002',
    floor: 'Floor 6',
    type: 'Progress',
    text: 'Supply line rough-in for floors 6 and 7 is complete. Ready for pressure test inspection tomorrow.',
    status: 'Processed',
    submittedAt: '3 hrs ago',
  ),
];

RecentFieldNoteStatus _parseFieldNoteStatus(String s) {
  switch (s) {
    case 'Processed':
      return RecentFieldNoteStatus.processed;
    case 'Pending':
      return RecentFieldNoteStatus.pending;
    default:
      return RecentFieldNoteStatus.failed;
  }
}

String _preview(String text) {
  final one = text.trim().replaceAll('\n', ' ');
  if (one.length <= 60) return one;
  return '${one.substring(0, 57)}…';
}

List<RecentFieldNote> mockRecentFieldNotesForAuthor(String authorName, {int limit = 3}) {
  final list = mockFieldNotes.where((f) => f.author == authorName).toList().reversed.take(limit).toList();
  var i = 0;
  return list
      .map((f) => RecentFieldNote(
            id: f.id,
            preview: _preview(f.text),
            typeLabel: f.type,
            createdAt: DateTime.now().subtract(Duration(minutes: 30 + i++ * 20)),
            status: _parseFieldNoteStatus(f.status),
          ))
      .toList();
}

List<RecentFieldNote> mockRecentFieldNotesForSite(String siteId, {int limit = 3}) {
  final list = mockFieldNotes.where((f) => f.jobsite == siteId).toList().reversed.take(limit).toList();
  var i = 0;
  return list
      .map((f) => RecentFieldNote(
            id: f.id,
            preview: _preview(f.text),
            typeLabel: f.type,
            createdAt: DateTime.now().subtract(Duration(minutes: 25 + i++ * 18)),
            status: _parseFieldNoteStatus(f.status),
          ))
      .toList();
}

List<MockFieldNote> mockFieldNotesForJobsite(String siteId) =>
    mockFieldNotes.where((f) => f.jobsite == siteId).toList();

/// Newest first (mock list order is chronological).
List<MockFieldNote> mockFieldNotesFeedForSite(String siteId) =>
    mockFieldNotes.where((f) => f.jobsite == siteId).toList().reversed.toList();

List<MockFieldNote> mockFieldNotesAllRecent({int limit = 5}) =>
    List<MockFieldNote>.from(mockFieldNotes).reversed.take(limit).toList();

// ── Approvals ────────────────────────────────────────────────────────────────

class MockApproval {
  final String id;
  final String type;
  final String? linkedId;
  final String title;
  final String requestedBy;
  final String trade;
  final String jobsite;
  final String estimatedCost;
  final String status;
  final String submittedAt;

  const MockApproval({
    required this.id,
    required this.type,
    this.linkedId,
    required this.title,
    required this.requestedBy,
    required this.trade,
    required this.jobsite,
    required this.estimatedCost,
    required this.status,
    required this.submittedAt,
  });
}

const List<MockApproval> mockApprovals = [
  MockApproval(
    id: 'apr_001',
    type: 'Material Request',
    linkedId: 'mat_001',
    title: '20mm PVC conduit — 50 lengths',
    requestedBy: 'Jordan Lee',
    trade: 'Electrician',
    jobsite: 'site_001',
    estimatedCost: r'$340',
    status: 'Pending',
    submittedAt: '3 hrs ago',
  ),
  MockApproval(
    id: 'apr_002',
    type: 'Material Request',
    linkedId: 'mat_002',
    title: '3/4 inch copper elbow fittings — qty 30',
    requestedBy: 'Priya Nair',
    trade: 'Plumber',
    jobsite: 'site_001',
    estimatedCost: r'$210',
    status: 'Pending',
    submittedAt: '5 hrs ago',
  ),
  MockApproval(
    id: 'apr_003',
    type: 'Material Request',
    linkedId: 'mat_004',
    title: 'Pressure relief valves — qty 4',
    requestedBy: 'Priya Nair',
    trade: 'Plumber',
    jobsite: 'site_001',
    estimatedCost: r'$520',
    status: 'Pending',
    submittedAt: '1 hr ago',
  ),
  MockApproval(
    id: 'apr_004',
    type: 'Work Order',
    linkedId: null,
    title: 'Emergency repair — basement riser leak',
    requestedBy: 'Priya Nair',
    trade: 'Plumber',
    jobsite: 'site_001',
    estimatedCost: r'$1,200',
    status: 'Pending',
    submittedAt: '4 hrs ago',
  ),
];

// ── Dashboard stats ───────────────────────────────────────────────────────────

class TradeWorkerStats {
  final int highPriority;
  final int blockers;
  final int dueToday;
  final int materialPending;
  final int leakAlerts;

  const TradeWorkerStats({
    required this.highPriority,
    required this.blockers,
    required this.dueToday,
    required this.materialPending,
    this.leakAlerts = 0,
  });
}

const TradeWorkerStats mockStatsElectrician = TradeWorkerStats(
  highPriority: 2,
  blockers: 1,
  dueToday: 2,
  materialPending: 1,
);

const TradeWorkerStats mockStatsPlumber = TradeWorkerStats(
  highPriority: 1,
  blockers: 1,
  dueToday: 2,
  materialPending: 2,
  leakAlerts: 1,
);

class GcDashboardStats {
  final int totalActiveTasks;
  final int openBlockers;
  final int pendingMaterials;
  final int workersOnSite;
  final int inspectionsDue;
  final int safetyWarnings;

  const GcDashboardStats({
    required this.totalActiveTasks,
    required this.openBlockers,
    required this.pendingMaterials,
    required this.workersOnSite,
    required this.inspectionsDue,
    required this.safetyWarnings,
  });
}

const GcDashboardStats mockStatsGc = GcDashboardStats(
  totalActiveTasks: 8,
  openBlockers: 3,
  pendingMaterials: 3,
  workersOnSite: 14,
  inspectionsDue: 1,
  safetyWarnings: 1,
);

class ManagerDashboardStats {
  final int totalJobsites;
  final int openBlockers;
  final int pendingApprovals;
  final int workersActive;
  final int safetyAlerts;

  const ManagerDashboardStats({
    required this.totalJobsites,
    required this.openBlockers,
    required this.pendingApprovals,
    required this.workersActive,
    required this.safetyAlerts,
  });
}

const ManagerDashboardStats mockStatsManager = ManagerDashboardStats(
  totalJobsites: 3,
  openBlockers: 3,
  pendingApprovals: 4,
  workersActive: 14,
  safetyAlerts: 1,
);

/// GC trades row: derived counts for site_001
class MockTradeSummary {
  final String trade;
  final int taskCount;
  final int blockerCount;
  final int workerCount;

  const MockTradeSummary({
    required this.trade,
    required this.taskCount,
    required this.blockerCount,
    this.workerCount = 4,
  });
}

const List<MockTradeSummary> mockGcTradeSummaries = [
  MockTradeSummary(trade: 'Electrical', taskCount: 3, blockerCount: 1, workerCount: 4),
  MockTradeSummary(trade: 'Plumbing', taskCount: 3, blockerCount: 1, workerCount: 3),
];
