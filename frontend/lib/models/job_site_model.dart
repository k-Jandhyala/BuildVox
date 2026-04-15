import 'package:cloud_firestore/cloud_firestore.dart';

class JobSiteModel {
  final String id;
  final String projectId;
  final String name;
  final String address;
  final List<String> activeTrades;
  final DateTime? createdAt;

  const JobSiteModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.address,
    required this.activeTrades,
    this.createdAt,
  });

  factory JobSiteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobSiteModel(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      activeTrades: List<String>.from(data['activeTrades'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
