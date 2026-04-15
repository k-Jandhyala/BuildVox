import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String name;
  final List<String> gcUserIds;
  final List<String> companyIds;
  final List<String> jobSiteIds;
  final List<String> tradeSequence;
  final DateTime? createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.gcUserIds,
    required this.companyIds,
    required this.jobSiteIds,
    required this.tradeSequence,
    this.createdAt,
  });

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      gcUserIds: List<String>.from(data['gcUserIds'] as List? ?? []),
      companyIds: List<String>.from(data['companyIds'] as List? ?? []),
      jobSiteIds: List<String>.from(data['jobSiteIds'] as List? ?? []),
      tradeSequence: List<String>.from(data['tradeSequence'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
