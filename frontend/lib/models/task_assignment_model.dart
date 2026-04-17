import 'extracted_item_model.dart';

class TaskAssignmentModel {
  final String id;
  final String extractedItemId;
  final String assignedToUserId;
  final String assignedByUserId;
  final String companyId;
  final String projectId;
  final String siteId;
  final ItemStatus status;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskAssignmentModel({
    required this.id,
    required this.extractedItemId,
    required this.assignedToUserId,
    required this.assignedByUserId,
    required this.companyId,
    required this.projectId,
    required this.siteId,
    required this.status,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TaskAssignmentModel(
      id: json['id'] as String? ?? '',
      extractedItemId: json['extracted_item_id'] as String? ?? '',
      assignedToUserId: json['assigned_to_user_id'] as String? ?? '',
      assignedByUserId: json['assigned_by_user_id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      siteId: json['site_id'] as String? ?? '',
      status: ItemStatus.fromString(json['status'] as String?),
      dueDate: _parse(json['due_date']),
      createdAt: _parse(json['created_at']),
      updatedAt: _parse(json['updated_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  TaskAssignmentModel copyWith({ItemStatus? status}) {
    return TaskAssignmentModel(
      id: id,
      extractedItemId: extractedItemId,
      assignedToUserId: assignedToUserId,
      assignedByUserId: assignedByUserId,
      companyId: companyId,
      projectId: projectId,
      siteId: siteId,
      status: status ?? this.status,
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
