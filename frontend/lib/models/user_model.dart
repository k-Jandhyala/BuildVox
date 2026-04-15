import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { worker, gc, manager, admin }

enum TradeType {
  electrical,
  plumbing,
  framing,
  drywall,
  paint,
  general,
  inspection,
  other;

  String get displayName {
    switch (this) {
      case TradeType.electrical:
        return 'Electrical';
      case TradeType.plumbing:
        return 'Plumbing';
      case TradeType.framing:
        return 'Framing';
      case TradeType.drywall:
        return 'Drywall';
      case TradeType.paint:
        return 'Paint';
      case TradeType.general:
        return 'General';
      case TradeType.inspection:
        return 'Inspection';
      case TradeType.other:
        return 'Other';
    }
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final TradeType? trade;
  final String? companyId;
  final List<String> assignedProjectIds;
  final List<String> assignedSiteIds;
  final List<String> fcmTokens;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.trade,
    this.companyId,
    required this.assignedProjectIds,
    required this.assignedSiteIds,
    required this.fcmTokens,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (data['role'] as String? ?? 'worker'),
        orElse: () => UserRole.worker,
      ),
      trade: data['trade'] != null
          ? TradeType.values.firstWhere(
              (t) => t.name == data['trade'],
              orElse: () => TradeType.other,
            )
          : null,
      companyId: data['companyId'] as String?,
      assignedProjectIds:
          List<String>.from(data['assignedProjectIds'] as List? ?? []),
      assignedSiteIds:
          List<String>.from(data['assignedSiteIds'] as List? ?? []),
      fcmTokens: List<String>.from(data['fcmTokens'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get roleLabel {
    switch (role) {
      case UserRole.worker:
        return 'Worker';
      case UserRole.gc:
        return 'General Contractor';
      case UserRole.manager:
        return 'Trade Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
