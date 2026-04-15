import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String name;
  final String tradeType;
  final List<String> managerUserIds;
  final List<String> activeProjectIds;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.tradeType,
    required this.managerUserIds,
    required this.activeProjectIds,
  });

  factory CompanyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      tradeType: data['tradeType'] as String? ?? 'other',
      managerUserIds:
          List<String>.from(data['managerUserIds'] as List? ?? []),
      activeProjectIds:
          List<String>.from(data['activeProjectIds'] as List? ?? []),
    );
  }
}
