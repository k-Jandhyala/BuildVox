import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type;
  final String userId;
  final String? extractedItemId;
  final String? taskAssignmentId;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.userId,
    this.extractedItemId,
    this.taskAssignmentId,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: data['type'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      extractedItemId: data['extractedItemId'] as String?,
      taskAssignmentId: data['taskAssignmentId'] as String?,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
