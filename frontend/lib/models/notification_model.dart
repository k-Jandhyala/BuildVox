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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      extractedItemId: json['extracted_item_id'] as String?,
      taskAssignmentId: json['task_assignment_id'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: _parse(json['created_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
