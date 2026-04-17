import 'package:flutter/material.dart';

import 'extracted_item_model.dart';
import 'job_site_model.dart';
import 'task_assignment_model.dart';

enum ElectricianPriority { critical, high, medium, low }

enum ElectricianCategory {
  taskUpdate,
  workOrder,
  blocker,
  materialRequest,
  scheduleIssue,
  siteIssue,
  generalReport,
}

enum QueueStatus { queued, syncing, failed, completed }

enum QueueSubmissionType { audioUpload, finalSubmission }

enum WarningSeverity { critical, high, medium, low }

enum WarningCategory {
  safety,
  inspection,
  materialShortage,
  schedule,
  access,
  weather,
}

class ElectricianTask {
  final TaskAssignmentModel assignment;
  final ExtractedItemModel item;
  final String assignedByLabel;

  const ElectricianTask({
    required this.assignment,
    required this.item,
    required this.assignedByLabel,
  });

  ElectricianPriority get priority {
    switch (item.urgency) {
      case UrgencyLevel.critical:
        return ElectricianPriority.critical;
      case UrgencyLevel.high:
        return ElectricianPriority.high;
      case UrgencyLevel.medium:
        return ElectricianPriority.medium;
      case UrgencyLevel.low:
        return ElectricianPriority.low;
    }
  }
}

class SiteWarning {
  final String id;
  final String siteId;
  final WarningCategory category;
  final WarningSeverity severity;
  final String title;
  final String description;
  final DateTime createdAt;
  final bool dismissible;

  const SiteWarning({
    required this.id,
    required this.siteId,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.createdAt,
    this.dismissible = false,
  });
}

class VoiceMemoDraft {
  final String localAudioPath;
  final String siteId;
  final String projectId;
  final List<String> attachedPhotoPaths;
  final DateTime createdAt;

  const VoiceMemoDraft({
    required this.localAudioPath,
    required this.siteId,
    required this.projectId,
    required this.attachedPhotoPaths,
    required this.createdAt,
  });
}

class AiExtractedItem {
  final String id;
  final String transcriptSegment;
  final String summary;
  final ElectricianCategory category;
  final ElectricianPriority priority;
  final String location;
  final String relatedTrade;
  final DateTime? dueDate;
  final String notes;
  final bool isBlocker;
  final bool isMaterialRequest;
  final List<String> attachedPhotos;
  final String? routePreview;
  final bool expanded;

  const AiExtractedItem({
    required this.id,
    required this.transcriptSegment,
    required this.summary,
    required this.category,
    required this.priority,
    required this.location,
    required this.relatedTrade,
    this.dueDate,
    required this.notes,
    required this.isBlocker,
    required this.isMaterialRequest,
    required this.attachedPhotos,
    this.routePreview,
    this.expanded = true,
  });

  AiExtractedItem copyWith({
    String? summary,
    ElectricianCategory? category,
    ElectricianPriority? priority,
    String? location,
    String? relatedTrade,
    DateTime? dueDate,
    String? notes,
    bool? isBlocker,
    bool? isMaterialRequest,
    List<String>? attachedPhotos,
    String? routePreview,
    bool? expanded,
  }) {
    return AiExtractedItem(
      id: id,
      transcriptSegment: transcriptSegment,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      location: location ?? this.location,
      relatedTrade: relatedTrade ?? this.relatedTrade,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      isBlocker: isBlocker ?? this.isBlocker,
      isMaterialRequest: isMaterialRequest ?? this.isMaterialRequest,
      attachedPhotos: attachedPhotos ?? this.attachedPhotos,
      routePreview: routePreview ?? this.routePreview,
      expanded: expanded ?? this.expanded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transcriptSegment': transcriptSegment,
      'summary': summary,
      'category': category.name,
      'priority': priority.name,
      'location': location,
      'relatedTrade': relatedTrade,
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'isBlocker': isBlocker,
      'isMaterialRequest': isMaterialRequest,
      'attachedPhotos': attachedPhotos,
      'routePreview': routePreview,
      'expanded': expanded,
    };
  }

  factory AiExtractedItem.fromJson(Map<String, dynamic> json) {
    return AiExtractedItem(
      id: json['id'] as String? ?? '',
      transcriptSegment: json['transcriptSegment'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      category: ElectricianCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ElectricianCategory.generalReport,
      ),
      priority: ElectricianPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => ElectricianPriority.medium,
      ),
      location: json['location'] as String? ?? '',
      relatedTrade: json['relatedTrade'] as String? ?? 'electrical',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      notes: json['notes'] as String? ?? '',
      isBlocker: json['isBlocker'] as bool? ?? false,
      isMaterialRequest: json['isMaterialRequest'] as bool? ?? false,
      attachedPhotos: List<String>.from(json['attachedPhotos'] as List? ?? []),
      routePreview: json['routePreview'] as String?,
      expanded: json['expanded'] as bool? ?? true,
    );
  }
}

class MaterialRequestDraft {
  final String itemName;
  final int quantity;
  final String supplier;
  final String notes;
  final List<String> photos;

  const MaterialRequestDraft({
    required this.itemName,
    required this.quantity,
    required this.supplier,
    required this.notes,
    required this.photos,
  });
}

class BlockerDraft {
  final String blockedWork;
  final String location;
  final WarningSeverity severity;
  final List<String> photos;

  const BlockerDraft({
    required this.blockedWork,
    required this.location,
    required this.severity,
    required this.photos,
  });
}

class EscalationDraft {
  final String reasonCode;
  final String details;

  const EscalationDraft({required this.reasonCode, required this.details});
}

class JobsiteSummary {
  final JobSiteModel site;
  final int highPriorityCount;
  final int blockerCount;
  final int dueTodayCount;
  final int materialPendingCount;

  const JobsiteSummary({
    required this.site,
    required this.highPriorityCount,
    required this.blockerCount,
    required this.dueTodayCount,
    required this.materialPendingCount,
  });
}

class QueuedSubmission {
  final String id;
  final QueueSubmissionType type;
  final QueueStatus status;
  final DateTime createdAt;
  final DateTime? lastTriedAt;
  final int attempts;
  final Map<String, dynamic> payload;
  final String? error;

  const QueuedSubmission({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.lastTriedAt,
    required this.attempts,
    required this.payload,
    this.error,
  });

  QueuedSubmission copyWith({
    QueueStatus? status,
    DateTime? lastTriedAt,
    int? attempts,
    String? error,
    Map<String, dynamic>? payload,
  }) {
    return QueuedSubmission(
      id: id,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      lastTriedAt: lastTriedAt ?? this.lastTriedAt,
      attempts: attempts ?? this.attempts,
      payload: payload ?? this.payload,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'lastTriedAt': lastTriedAt?.toIso8601String(),
      'attempts': attempts,
      'payload': payload,
      'error': error,
    };
  }

  factory QueuedSubmission.fromJson(Map<String, dynamic> json) {
    return QueuedSubmission(
      id: json['id'] as String? ?? '',
      type: QueueSubmissionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => QueueSubmissionType.finalSubmission,
      ),
      status: QueueStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QueueStatus.queued,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastTriedAt: json['lastTriedAt'] == null
          ? null
          : DateTime.tryParse(json['lastTriedAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
      error: json['error'] as String?,
    );
  }
}

Color warningSeverityColor(WarningSeverity s) {
  switch (s) {
    case WarningSeverity.critical:
      return const Color(0xFFDC2626);
    case WarningSeverity.high:
      return const Color(0xFFF97316);
    case WarningSeverity.medium:
      return const Color(0xFFEAB308);
    case WarningSeverity.low:
      return const Color(0xFF22C55E);
  }
}
