import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory TaskAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskAssignmentModel(
      id: doc.id,
      extractedItemId: data['extractedItemId'] as String? ?? '',
      assignedToUserId: data['assignedToUserId'] as String? ?? '',
      assignedByUserId: data['assignedByUserId'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      status: ItemStatus.fromString(data['status'] as String?),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
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
