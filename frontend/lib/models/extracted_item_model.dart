import 'package:flutter/material.dart';
import '../theme.dart';

enum TierType {
  issueOrBlocker,
  materialRequest,
  progressUpdate,
  scheduleChange;

  String get label {
    switch (this) {
      case TierType.issueOrBlocker:
        return 'Blocker';
      case TierType.materialRequest:
        return 'Material Request';
      case TierType.progressUpdate:
        return 'Progress Update';
      case TierType.scheduleChange:
        return 'Schedule Change';
    }
  }

  Color get color {
    switch (this) {
      case TierType.issueOrBlocker:
        return BVColors.blocker;
      case TierType.materialRequest:
        return BVColors.materialRequest;
      case TierType.progressUpdate:
        return BVColors.progressUpdate;
      case TierType.scheduleChange:
        return BVColors.scheduleChange;
    }
  }

  IconData get icon {
    switch (this) {
      case TierType.issueOrBlocker:
        return Icons.block_rounded;
      case TierType.materialRequest:
        return Icons.inventory_2_rounded;
      case TierType.progressUpdate:
        return Icons.check_circle_rounded;
      case TierType.scheduleChange:
        return Icons.schedule_rounded;
    }
  }

  static TierType fromString(String? value) {
    switch (value) {
      case 'issue_or_blocker':
        return TierType.issueOrBlocker;
      case 'material_request':
        return TierType.materialRequest;
      case 'progress_update':
        return TierType.progressUpdate;
      case 'schedule_change':
        return TierType.scheduleChange;
      default:
        return TierType.progressUpdate;
    }
  }
}

enum UrgencyLevel {
  low,
  medium,
  high,
  critical;

  String get label => name[0].toUpperCase() + name.substring(1);

  Color get color {
    switch (this) {
      case UrgencyLevel.critical:
        return BVColors.critical;
      case UrgencyLevel.high:
        return BVColors.high;
      case UrgencyLevel.medium:
        return BVColors.medium;
      case UrgencyLevel.low:
        return BVColors.low;
    }
  }

  static UrgencyLevel fromString(String? value) {
    return UrgencyLevel.values.firstWhere(
      (u) => u.name == value,
      orElse: () => UrgencyLevel.medium,
    );
  }
}

enum ItemStatus {
  pending,
  acknowledged,
  inProgress,
  done,
  cancelled;

  String get label {
    switch (this) {
      case ItemStatus.pending:
        return 'Pending';
      case ItemStatus.acknowledged:
        return 'Acknowledged';
      case ItemStatus.inProgress:
        return 'In Progress';
      case ItemStatus.done:
        return 'Done';
      case ItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case ItemStatus.pending:
        return BVColors.pending;
      case ItemStatus.acknowledged:
        return BVColors.acknowledged;
      case ItemStatus.inProgress:
        return BVColors.inProgress;
      case ItemStatus.done:
        return BVColors.done;
      case ItemStatus.cancelled:
        return BVColors.textSecondary;
    }
  }

  static ItemStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return ItemStatus.pending;
      case 'acknowledged':
        return ItemStatus.acknowledged;
      case 'in_progress':
        return ItemStatus.inProgress;
      case 'done':
        return ItemStatus.done;
      case 'cancelled':
        return ItemStatus.cancelled;
      default:
        return ItemStatus.pending;
    }
  }
}

class ExtractedItemModel {
  final String id;
  final String memoId;
  final String projectId;
  final String siteId;
  final String createdBy;
  final String sourceText;
  final String normalizedSummary;
  final String trade;
  final TierType tier;
  final UrgencyLevel urgency;
  final String? unitOrArea;
  final bool needsGcAttention;
  final bool needsTradeManagerAttention;
  final List<String> downstreamTrades;
  final String recommendedCompanyType;
  final bool actionRequired;
  final String suggestedNextStep;
  final List<String> recipientUserIds;
  final List<String> recipientCompanyIds;
  final ItemStatus status;
  final DateTime? createdAt;

  const ExtractedItemModel({
    required this.id,
    required this.memoId,
    required this.projectId,
    required this.siteId,
    required this.createdBy,
    required this.sourceText,
    required this.normalizedSummary,
    required this.trade,
    required this.tier,
    required this.urgency,
    this.unitOrArea,
    required this.needsGcAttention,
    required this.needsTradeManagerAttention,
    required this.downstreamTrades,
    required this.recommendedCompanyType,
    required this.actionRequired,
    required this.suggestedNextStep,
    required this.recipientUserIds,
    required this.recipientCompanyIds,
    required this.status,
    this.createdAt,
  });

  factory ExtractedItemModel.fromJson(Map<String, dynamic> json) {
    return ExtractedItemModel(
      id: json['id'] as String? ?? '',
      memoId: json['memo_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      siteId: json['site_id'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      sourceText: json['source_text'] as String? ?? '',
      normalizedSummary: json['normalized_summary'] as String? ?? '',
      trade: json['trade'] as String? ?? 'other',
      tier: TierType.fromString(json['tier'] as String?),
      urgency: UrgencyLevel.fromString(json['urgency'] as String?),
      unitOrArea: json['unit_or_area'] as String?,
      needsGcAttention: json['needs_gc_attention'] as bool? ?? false,
      needsTradeManagerAttention:
          json['needs_trade_manager_attention'] as bool? ?? false,
      downstreamTrades:
          List<String>.from(json['downstream_trades'] as List? ?? []),
      recommendedCompanyType:
          json['recommended_company_type'] as String? ?? 'other',
      actionRequired: json['action_required'] as bool? ?? false,
      suggestedNextStep: json['suggested_next_step'] as String? ?? '',
      recipientUserIds:
          List<String>.from(json['recipient_user_ids'] as List? ?? []),
      recipientCompanyIds:
          List<String>.from(json['recipient_company_ids'] as List? ?? []),
      status: ItemStatus.fromString(json['status'] as String?),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
